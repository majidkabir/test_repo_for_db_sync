SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_PostWaveBuildLoad01                                     */
/* Creation Date: 2023-09-27                                            */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: LFWM-4490 - CN UAT Add new type to wave build load          */
/*        :                                                             */
/* Called By: WM.lsp_Wave_BuildLoad.                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2023-09-27   Wan       1.0 Initial Creation & DevOps Combine Script  */
/************************************************************************/
CREATE   PROC isp_PostWaveBuildLoad01 
   @c_Facility           NVARCHAR(5)
,  @c_Storerkey          NVARCHAR(15)
,  @c_Wavekey            NVARCHAR(10)  
,  @n_BatchNo            INT                       
,  @c_ParmCode           NVARCHAR(10)
,  @b_Success            INT           = 1   OUTPUT     
,  @n_Err                INT           = 0   OUTPUT                    
,  @c_ErrMsg             NVARCHAR(255) = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1
         , @b_Debug           BIT   = 0
         , @n_Cnt             INT   = 0
         
         , @c_Loadkey         NVARCHAR(10) = ''
         , @c_OrderKey        NVARCHAR(10) = ''
         , @c_Load_Userdef1   NVARCHAR(50) = ''
         
         , @cur_Ord           CURSOR
         , @cur_Load          CURSOR
                     
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @b_Success  = 1

   BEGIN TRAN
   SET @cur_Load = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT bldl.Loadkey
   FROM dbo.BuildLoadLog AS bll (NOLOCK) 
   JOIN dbo.BuildLoadDetailLog AS bldl (NOLOCK) ON bll.BatchNo = bldl.BatchNo
   WHERE bll.BatchNo = @n_BatchNo
   AND bll.Wavekey = @c_Wavekey
   AND bll.BuildParmCode = @c_ParmCode
   ORDER BY bldl.RowRef 
   
   OPEN @cur_Load
   
   FETCH @cur_Load INTO @c_Loadkey
   
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      SET @cur_Ord = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT lpd.Orderkey
      FROM dbo.LoadPlanDetail AS lpd  (NOLOCK) 
      WHERE lpd.LoadKey = @c_Loadkey
      ORDER BY lpd.LoadLineNumber 
   
      OPEN @cur_Ord
   
      FETCH @cur_Ord INTO @c_Orderkey
   
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         UPDATE dbo.ORDERS WITH (ROWLOCK)
         SET SectionKey = 'Y'
            ,TrafficCop = NULL
            ,EditWho = SUSER_SNAME()
            ,EditDate = GETDATE()
         WHERE LoadKey = @c_Loadkey
      
         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 60010       
            SET @c_ErrMsg   = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)   
                            + ': Update Order Fail. (isp_PostWaveBuildLoad01)'            
         END   
               
         FETCH @cur_Ord INTO @c_Orderkey
      END
      CLOSE @cur_Ord
      DEALLOCATE @cur_Ord

      IF @n_Continue = 1
      BEGIN
         SELECT @c_Load_Userdef1 = ISNULL(o.BuyerPO,'')
         FROM dbo.ORDERS AS o (NOLOCK)
         WHERE o.Orderkey = @c_OrderKey
         
         SET @n_Cnt = @n_Cnt + 1
      
         UPDATE dbo.LoadPlan WITH (ROWLOCK)
         SET Load_Userdef1 = @c_Load_Userdef1
            ,Userdefine02 = CONVERT(NVARCHAR(10), @n_Cnt)
            ,TrafficCop = NULL
            ,EditWho = SUSER_SNAME()
            ,EditDate = GETDATE()
         WHERE LoadKey = @c_Loadkey
      
         IF @@ERROR <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 60020       
            SET @c_ErrMsg   = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)   
                            + ': Update Loadplan Fail. (isp_PostWaveBuildLoad01)'       
         END
      END
      FETCH @cur_Load INTO @c_Loadkey
   END
   CLOSE @cur_Load
   DEALLOCATE @cur_Load
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PostWaveBuildLoad01'
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
END -- procedure

GO