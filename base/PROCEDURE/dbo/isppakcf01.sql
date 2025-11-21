SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF01                                            */
/* Creation Date: 06-FEB-2014                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#301554: VFCDC - Update UCC when Pack confirm in Exceed.    */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF01]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 

         , @c_UCCNo           NVARCHAR(20)


   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   SET @c_UCCNo = ''

   DECLARE CUR_FULLCTN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PCK.DropID
   FROM PACKHEADER PH  WITH (NOLOCK)
   JOIN PACKDETAIL PCK WITH (NOLOCK) ON (PH.PickSlipNo = PCK.Pickslipno)
   JOIN PICKDETAIL PIK WITH (NOLOCK) ON (PH.PickSlipNo = PIK.PickSlipNo)
                                     AND(PH.Orderkey   = PIK.Orderkey)
                                     AND(PCK.DropID    = PIK.DropID)
   WHERE PH.Pickslipno = @c_PickSlipNo
   AND   (RTRIM(PCK.DropID) <> '' AND PCK.DropId IS NOT NULL)
   AND   PIK.UOM = '2'

   OPEN CUR_FULLCTN  
  
   FETCH NEXT FROM CUR_FULLCTN INTO @c_UCCNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      UPDATE UCC WITH (ROWLOCK)
      SET Status   = '5'         -- Full Carton Pick
         ,EditWho  = SUser_Name()  
         ,EditDate = GETDATE()
      WHERE UCCNo = @c_UCCNo
      AND   Status = '1'

      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61801-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table UCC. (ispPAKCF01)'   

         GOTO QUIT_SP 
      END 

      FETCH NEXT FROM CUR_FULLCTN INTO @c_UCCNo
   END
   CLOSE CUR_FULLCTN
   DEALLOCATE CUR_FULLCTN

   QUIT_SP:


   IF CURSOR_STATUS('LOCAL' , 'CUR_FULLCTN') in (0 , 1)
   BEGIN
      CLOSE CUR_FULLCTN
      DEALLOCATE CUR_FULLCTN
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO