SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_PTSK                                         */
/* Creation Date: 2021-07-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-15  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/* 2022-12-02  Wan03    1.1   Fixed Blocking                            */
/************************************************************************/

CREATE PROC [dbo].[ispRLWAV43_PTSK]
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
           @n_StartTCnt             INT   = @@TRANCOUNT
         , @n_Continue              INT   = 1
         
         , @c_Orderkey              NVARCHAR(10) = ''
         , @c_TaskBatchNo           NVARCHAR(10) = ''    
            
         , @c_PickZone              NVARCHAR(10) = '' 
         
         , @c_PickdetailKey         NVARCHAR(10) = ''             --(Wan01)
         
         , @CUR_UPD                 CURSOR                        --(Wan01)         
         , @CUR_PTSK                CURSOR                        --(Wan01)  
   
   DECLARE @t_SingleOrder           TABLE
         ( Orderkey                 NVARCHAR(10)   NOT NULL DEFAULT('')    PRIMARY KEY
          ) 
         
   SET @b_Success  = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  

   INSERT INTO @t_SingleOrder ( Orderkey )
   SELECT o.OrderKey
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   AND o.ECOM_SINGLE_Flag = 'S'
   GROUP BY o.OrderKey
   
   IF @@ROWCOUNT = 0
   BEGIN
      GOTO QUIT_SP
   END
   
   EXECUTE nspg_getkey    
     @KeyName     = 'ORDBATCHNO'    
   , @fieldlength = 9    
   , @keystring   = @c_TaskBatchNo     OUTPUT    
   , @b_Success   = @b_Success         OUTPUT    
   , @n_Err       = @n_Err             OUTPUT    
   , @c_ErrMsg    = @c_ErrMsg          OUTPUT    
      
   IF @b_Success= 0 
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END  
       
   SET @c_TaskBatchNo = 'B' + @c_TaskBatchNo  
             
   SET @c_PickZone = ''
   SELECT @c_PickZone = MIN(l.PickZone)
   FROM @t_SingleOrder AS tso
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = tso.Orderkey
   JOIN dbo.SKUxLOC AS sl WITH (NOLOCK) ON  sl.Storerkey = p.Storerkey AND sl.Sku = p.Sku
                                    AND sl.LocationType = 'PICK'
   JOIN LOC AS l WITH (NOLOCK) ON l.Loc = sl.Loc
   GROUP BY l.Facility
   HAVING COUNT(DISTINCT l.PickZone) = 1
   
   IF @c_PickZone <> ''
   BEGIN
      IF EXISTS (
                  SELECT 1
                  FROM @t_SingleOrder AS tso
                  JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = tso.Orderkey
                  JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = p.Loc
                  WHERE p.UOM = '2'
                  AND l.PickZone <> @c_PickZone
      )
      BEGIN
         SET @c_PickZone = '' 
      END
   END
     
   INSERT INTO PACKTASK ( TaskBatchNo, Orderkey, DevicePosition, LogicalName, OrderMode )
   SELECT
         @c_TaskBatchNo
      ,  tso.Orderkey
      ,  ''
      ,  ''     
      ,  'S-9'
   FROM @t_SingleOrder AS tso
   
   IF @@ERROR <> 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update Pickdetail. (ispRLWAV43_PTSK)'
      GOTO QUIT_SP
   END
   --(Wan01) - START
   --;WITH o ( Pickdetailkey ) AS
   --( 
   SET @CUR_UPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT pd.PickDetailKey
      FROM PACKTASK as pt WITH (NOLOCK)
      JOIN PICKDETAIL as pd WITH (NOLOCK) ON pt.Orderkey = pd.Orderkey
      WHERE pt.TaskBatchNo = @c_TaskBatchNo
   --)
   OPEN @CUR_UPD
   FETCH NEXT FROM @CUR_UPD INTO @c_PickDetailKey
     
   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      UPDATE p WITH (ROWLOCK)
         SET PickSlipNo = @c_TaskBatchNo
            , Notes = @c_Wavekey + '-' + @c_PickZone + '-' + RIGHT(@c_TaskBatchNo,3) + CASE WHEN @c_PickZone = '' THEN '-4' ELSE '-1' END
            , EditWho  = SUSER_SNAME()
            , EditDate = GETDATE()
            , Trafficcop = NULL
      FROM PICKDETAIL as p
      --JOIN o ON o.PickDetailKey = p.PickDetailKey
      WHERE p.PickdetailKey = @c_Pickdetailkey

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update Pickdetail. (ispRLWAV43_PTSK)'
         GOTO QUIT_SP
      END
      FETCH NEXT FROM @CUR_UPD INTO @c_PickDetailKey
   END
   CLOSE @CUR_UPD
   DEALLOCATE @CUR_UPD
   --(Wan01) - END
      
QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_PTSK'
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