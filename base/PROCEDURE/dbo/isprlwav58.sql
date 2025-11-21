SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispRLWAV58                                              */
/* Creation Date: 19-Apr-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22210 - AESOP Release Wave (Main)                       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 19-Apr-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispRLWAV58]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         
         , @c_Facility        NVARCHAR(5)  = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_DocType         NVARCHAR(10) = ''  
         , @c_Pickdetailkey   NVARCHAR(10) = ''  
         
   SELECT TOP 1
         @c_Facility  = o.Facility
       , @c_Storerkey = o.Storerkey
       , @c_DocType   = o.Doctype
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN ORDERS AS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey      
   WHERE w.WaveKey = @c_Wavekey
   ORDER BY w.WaveDetailKey

   --B2B
   IF @c_DocType = 'N'
   BEGIN
      -- B2B Cartonization
      EXEC [dbo].[ispRLWAV58_PACK]
         @c_Wavekey  = @c_Wavekey 
      ,  @b_Success  = @b_Success   OUTPUT 
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      -- B2B CPK task        
      EXEC [dbo].[ispRLWAV58_CPK]
         @c_Wavekey  = @c_Wavekey 
      ,  @b_Success  = @b_Success   OUTPUT 
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
   END
   ELSE   --B2C
   BEGIN
      -- B2C Generate PK
      EXEC [dbo].[ispRLWAV58_PK]
         @c_Wavekey  = @c_Wavekey 
      ,  @b_Success  = @b_Success   OUTPUT 
      ,  @n_Err      = @n_Err       OUTPUT
      ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
   END

   --Update GIFTCARD SKU to Picked
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PICKDETAIL.PickDetailKey
      FROM PICKDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
      JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey
      JOIN CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = 'GIFTCRDSKU' 
                            AND PICKDETAIL.Storerkey = CODELKUP.Storerkey
                            AND PICKDETAIL.Sku = CODELKUP.Code
      WHERE WAVEDETAIL.WaveKey = @c_Wavekey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Pickdetailkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE dbo.PICKDETAIL
         SET [Status] = '5'
         WHERE PickDetailKey = @c_Pickdetailkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 69015
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + ': Failed to update PICKDETAIL for PickdetailKey: ' + @c_Pickdetailkey 
                               + '. (ispRLWAV58_PK)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_ErrMsg) + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Pickdetailkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   UPDATE WAVE WITH (ROWLOCK)  
   SET TMReleaseFlag = 'Y'              
      ,Trafficcop = NULL  
      ,EditWho = SUSER_SNAME()  
      ,EditDate= GETDATE()  
   WHERE Wavekey = @c_Wavekey   
     
   SET @n_err = @@ERROR  

   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 69020    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update WAVE Table Failed. (ispRLWAV58)'   
      GOTO QUIT_SP  
   END   
   
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV58'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END   

GO