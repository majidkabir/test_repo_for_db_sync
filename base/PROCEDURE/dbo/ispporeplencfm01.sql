SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPOReplenCfm01                                        */
/* Creation Date: 13-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5218 - [CN] UA Relocation Phase II - Exceed Generate    */
/*          and Confirm Replenishment(B2C)                              */ 
/*                                                                      */ 
/* Called By: ispPostGenEOrderReplenWrapper                             */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-09-09  Wan01    1.1   Performance Tune                          */
/************************************************************************/
CREATE PROC [dbo].[ispPOReplenCfm01]
           @c_ReplenishmentGroup NVARCHAR(10) 
         , @c_ReplenishmentKey   NVARCHAR(10) 
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_UCC_RowRef         BIGINT    

         , @n_Cnt                INT            = 0   --(Wan01) 
         , @c_Storerkey          NVARCHAR(15)   = ''  --(Wan01)  
         , @n_ReplConfirmed      INT   = 0            --(Wan01)

         , @cur_UCC              CURSOR

   --(Wan01) - START
   DECLARE @t_ORDERS TABLE
      (  Orderkey    NVARCHAR(10) NOT NULL PRIMARY KEY
      ,  TaskBatchNo NVARCHAR(10) NOT NULL DEFAULT('') )
   --(Wan01) - END

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   --(Wan01) - START
   SELECT  @c_Storerkey = R.Storerkey
         , @n_Cnt = 1
         , @n_ReplConfirmed = ISNULL(SUM(CASE WHEN R.Confirmed = 'Y' THEN 1 ELSE 0 END),0)
   FROM REPLENISHMENT R (NOLOCK) 
   WHERE R.ReplenishmentGroup = @c_ReplenishmentGroup
   --AND   R.Confirmed = 'N'
   GROUP BY R.Storerkey
   
   IF @n_Cnt = 0
   BEGIN 
      GOTO QUIT_SP 
   END

   --IF NOT EXISTS (SELECT 1
   --               FROM PACKTASK PT WITH (NOLOCK) 
   --               WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
   --               )
   --BEGIN
   --   GOTO QUIT_SP
   --END

   SET @n_Cnt = 0
   IF @n_ReplConfirmed = 1  -- Assume UOM = '2' UCC.Status had been updated to '6' when process the 1st replenishmentkey
   BEGIN
      INSERT INTO @t_ORDERS (Orderkey, TaskBatchNo)
      SELECT DISTINCT PT.Orderkey
            ,  PT.TaskBatchNo
      FROM PACKTASK PT WITH (NOLOCK)
      WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup

      IF NOT EXISTS (SELECT 1 FROM @t_ORDERS)
      BEGIN
         GOTO QUIT_SP
      END
   
      SELECT TOP 1 @n_Cnt = 1 
      FROM  @t_ORDERS PT
      JOIN  PICKDETAIL PD WITH (NOLOCK) ON  PD.Orderkey  = PT.Orderkey
                                        AND PD.PickSlipNo= PT.TaskBatchNo
      JOIN  UCC           WITH (NOLOCK) ON  UCC.UCCNo = PD.DropID
      WHERE UCC.Storerkey = @c_Storerkey
      AND   UCC.[Status] < '6'
      AND   PD.DropID <> ''
      AND   PD.UOM    = '2'
      AND   PD.Status < '5'
      AND   PD.ShipFlag NOT IN ('P','Y')
   END 
   --(Wan01) - END
   BEGIN TRAN
   --(Wan01) - START
   IF @n_Cnt = 1 
   BEGIN
      SET @cur_UCC = CURSOR FAST_FORWARD READ_ONLY FOR
      --SELECT UCC.UCC_RowRef  
      --FROM   UCC WITH (NOLOCK)
      --WHERE  UCC.Status < '6'
      --AND    EXISTS( SELECT 1
      --               FROM PICKDETAIL PD WITH (NOLOCK)
      --               JOIN   PACKTASK   PT WITH (NOLOCK) ON (PD.PickSlipNo = PT.TaskBatchNo)
      --                                                  AND(PD.Orderkey   = PT.Orderkey)
      --               WHERE  PT.ReplenishmentGroup = @c_ReplenishmentGroup
      --               AND    PD.UOM = '2'
      --               AND    PD.Status < '5'
      --               AND    PD.ShipFlag NOT IN ('P','Y') 
      --               AND    PD.DropID = UCC.UCCNo
      --             )
      SELECT UCC.UCC_RowRef  
         FROM  @t_ORDERS PT
         JOIN  PICKDETAIL PD WITH (NOLOCK) ON  PD.Orderkey  = PT.Orderkey
                                           AND PD.PickSlipNo= PT.TaskBatchNo
         JOIN  UCC           WITH (NOLOCK) ON  UCC.UCCNo = PD.DropID
         WHERE UCC.Storerkey = @c_Storerkey
         AND   UCC.[Status] < '6'
         AND   PD.DropID <> ''
         AND   PD.UOM    = '2'
         AND   PD.Status < '5'
         AND   PD.ShipFlag NOT IN ('P','Y')
         GROUP BY UCC.UCC_RowRef
      UNION
      SELECT UCC.UCC_RowRef
      FROM   UCC WITH (NOLOCK)
      JOIN   REPLENISHMENT RP WITH (NOLOCK) ON (UCC.UserDefined10 = RP.ReplenishmentKey)
      WHERE  RP.ReplenishmentKey   = @c_ReplenishmentKey
      AND    RP.ReplenishmentGroup = @c_ReplenishmentGroup
         --AND    UCC.Status < '6'  
         AND    UCC.Status = '5'                                           --(Wan01) -- PostGenRepl update UCC status to '5'
         AND    UCC.Storerkey = @c_Storerkey                               --(Wan01)
         AND    UCC.UserDefined10 <> '' AND UCC.UserDefined10 IS NOT NULL  --(Wan01)
         ORDER BY UCC_RowRef
   END
   ELSE
   BEGIN
      SET @n_Cnt = 0
      SELECT TOP 1 @n_Cnt = 1 
      FROM   UCC WITH (NOLOCK)
      WHERE  UCC.Status = '5'                                           
      AND    UCC.Storerkey = @c_Storerkey                               
      AND    UCC.UserDefined10 <> '' AND UCC.UserDefined10 IS NOT NULL 

      IF @n_Cnt = 0
      BEGIN
         GOTO QUIT_SP
      END

      SET @cur_UCC = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT UCC.UCC_RowRef
      FROM   UCC WITH (NOLOCK)
      JOIN   REPLENISHMENT RP WITH (NOLOCK) ON (UCC.UserDefined10 = RP.ReplenishmentKey)
      WHERE  RP.ReplenishmentKey   = @c_ReplenishmentKey
      AND    RP.ReplenishmentGroup = @c_ReplenishmentGroup
      --AND    UCC.Status < '6'  
      AND    UCC.Status = '5'                                           --(Wan01) -- PostGenRepl update UCC status to '5'
      AND    UCC.Storerkey = @c_Storerkey                               --(Wan01)
      AND    UCC.UserDefined10 <> '' AND UCC.UserDefined10 IS NOT NULL  --(Wan01)
      ORDER BY UCC_RowRef
   END
   --(Wan05) - END


   OPEN @cur_UCC
   
   FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE UCC WITH (ROWLOCK)
      SET Status = '6'
         ,EditWho  = SUSER_SNAME()
         ,EditDate = GETDATE()
      WHERE UCC_RowRef = @n_UCC_RowRef

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 62310
         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Update UCC Table Fail. (ispPOReplenCfm01)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef 
   END
   CLOSE @cur_UCC
   DEALLOCATE @cur_UCC 
    
QUIT_SP:

   IF CURSOR_STATUS( 'VARIABLE', '@cur_UCC') in (0 , 1)  
   BEGIN
      CLOSE @cur_UCC
      DEALLOCATE @cur_UCC
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOReplenCfm01'
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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   RETURN
END -- procedure

GO