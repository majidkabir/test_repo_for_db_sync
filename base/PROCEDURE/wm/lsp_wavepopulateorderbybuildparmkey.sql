SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: lsp_WavePopulateOrderByBuildParmKey                 */
/* Creation Date: 02-Feb-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: LFWM-4602 - SCE| PROD| SG| Wave Control - Populate Orders - */
/*                      Top Up Orders With Same Parameter               */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* GitHub Version: 1.0                                                  */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 02-Feb-2024 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [WM].[lsp_WavePopulateOrderByBuildParmKey]
      @c_WaveKey           NVARCHAR(10)
   ,  @c_BuildParmKey      NVARCHAR(10)
   ,  @c_Facility          NVARCHAR(5)
   ,  @c_StorerKey         NVARCHAR(15)
   ,  @b_Success           INT = 1           OUTPUT
   ,  @n_err               INT = 0           OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)= '' OUTPUT
   ,  @c_UserName          NVARCHAR(128)= ''
   ,  @b_debug             INT          = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_StartTCnt         INT = @@TRANCOUNT
         ,  @n_Continue          INT = 1
         ,  @n_PickslipCnt       INT = 0
         ,  @c_SQLBuildWave      NVARCHAR(MAX)
         ,  @n_BatchNo           BIGINT = 0
         ,  @n_SessionNo         BIGINT = 0
         ,  @c_ParmGroup         NVARCHAR(30) = ''
         ,  @c_BuildDateField    NVARCHAR(50) = ''
         ,  @dt_Date_Fr          DATETIME = NULL
         ,  @dt_Date_To          DATETIME = NULL

   SET @b_Success = 1
   SET @n_Err     = 0

   SET @n_Err = 0

   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser]
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END

   BEGIN TRY
      --Validation
      IF (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         --Check if the BuildParamKey is valid
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.BUILDPARMGROUPCFG BPGC WITH (NOLOCK)
                         JOIN dbo.BUILDPARM BP WITH (NOLOCK) ON BP.ParmGroup = BPGC.ParmGroup
                         WHERE BPGC.Storerkey = @c_Storerkey
                         AND (BPGC.Facility = @c_Facility OR BPGC.Facility = '')
                         AND BPGC.[Type] = 'BuildWaveParm'
                         AND BP.BuildParmKey = @c_BuildParmKey
                         AND BP.Active = '1' )
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562051
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': BuildParmKey #' + @c_BuildParmKey + ' is not valid. (lsp_WavePopulateOrderByBuildParmKey)'
            GOTO EXIT_SP
         END

         SET @c_ParmGroup = ''
         SET @c_BuildDateField = ''

         --Check if @c_BuildDateField has value
         SELECT @c_ParmGroup = ISNULL(RTRIM(BP.ParmGroup),'')
         FROM BUILDPARM BP WITH (NOLOCK)
         WHERE BP.BuildParmKey = @c_BuildParmKey

         SELECT @c_BuildDateField = ISNULL(CFG.BuildDateField,'')
         FROM BUILDPARMGROUPCFG CFG WITH (NOLOCK)
         WHERE ParmGroup = @c_ParmGroup

         IF @c_BuildDateField <> ''
         BEGIN
            SELECT @dt_Date_Fr = IIF(ISDATE(BWL.UDF03) = 1, BWL.UDF03, NULL)
                 , @dt_Date_To = IIF(ISDATE(BWL.UDF04) = 1, BWL.UDF04, NULL)
            FROM dbo.BUILDWAVEDETAILLOG BWDL (NOLOCK)
            JOIN dbo.BUILDWAVELOG BWL (NOLOCK) ON BWL.BatchNo = BWDL.BatchNo
            WHERE BWDL.Wavekey = @c_WaveKey
         END

         --Check if Pickslipno has been generated
         --Discrete
         SET @n_PickslipCnt = 0
         SELECT @n_PickslipCnt = COUNT(1)
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKHEADER PH (NOLOCK) ON PH.OrderKey = WD.OrderKey
         WHERE WD.WaveKey = @c_WaveKey

         IF ISNULL(@n_PickslipCnt, 0) = 0
         BEGIN
            --Conso
            SET @n_PickslipCnt = 0
            SELECT @n_PickslipCnt = COUNT(1)
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON OH.OrderKey = LPD.OrderKey
            JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            WHERE WD.WaveKey = @c_WaveKey
         END

         IF ISNULL(@n_PickslipCnt, 0) > 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 562052
            SET @c_errmsg = 'NSQL'+ CONVERT(Char(6),@n_err)
                          + ': Pickslipno has been generated. Not allow to proceed. (lsp_WavePopulateOrderByBuildParmKey)'
            GOTO EXIT_SP
         END
      END

      --Call BuildWave to top up orders
      EXECUTE [WM].[lsp_Build_Wave] @c_BuildParmKey    = @c_BuildParmKey
                                  , @c_Facility        = @c_Facility
                                  , @c_StorerKey       = @c_Storerkey
                                  , @c_BuildWaveType   = N'TopUpWave'
                                  , @c_SQLBuildWave    = @c_SQLBuildWave OUTPUT
                                  , @n_BatchNo         = @n_BatchNo      OUTPUT
                                  , @n_SessionNo       = @n_SessionNo    OUTPUT
                                  , @b_Success         = @b_Success      OUTPUT
                                  , @n_err             = @n_err          OUTPUT
                                  , @c_ErrMsg          = @c_ErrMsg       OUTPUT
                                  , @c_UserName        = @c_UserName
                                  , @b_debug           = @b_debug
                                  , @dt_Date_Fr        = @dt_Date_Fr
                                  , @dt_Date_To        = @dt_Date_To
                                  , @c_WaveKey         = @c_WaveKey

      IF @b_Debug IN (1,2)
      BEGIN
         PRINT @c_SQLBuildWave
      END

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH

EXIT_SP:
   IF (XACT_STATE()) = -1
   BEGIN
      ROLLBACK TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WavePopulateOrderByBuildParmKey'
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
   REVERT
END

GO