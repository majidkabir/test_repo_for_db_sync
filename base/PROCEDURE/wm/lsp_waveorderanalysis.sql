SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_WaveOrderAnalysis                               */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-1789 - SPs for Wave Release Screen -                   */
/*          ( Summary Tab - HomeScreen )                                */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 2.3                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 27-Oct-2021 Chai01   1.2   LFWM-3070 - UAT|JP|Wave|AddParameterDescriptionOnWaveReleaseScreen*/
/* 09-Dec-2021 Wan02    1.3   LFWM-3212 - SCE UAT SG All Order Parameter*/
/*                            Disappeared with Operator '='             */
/* 09-Dec-2021 Wan02    1.3   DevOps Combine Script                     */
/* 05-Jan-2022 Wan03    1.4   LFWM-3279 - SCE UAT SG Order Parameter -  */
/*                            Type 'SORT' - Do not have Sku_Total_Qty as*/
/*                            in Exceed                                 */
/* 22-FEB-2022 Wan04    1.5   LFWM-3290 - PROD CN Wave Release  Can not */
/*                            display all parameter correctly           */
/* 13-JUL-2022 LZG      1.6   JSM-81405 - Fixed custom SQL HAVING (ZG01)*/
/* 2022-08-10  Wan05    1.7   LFWM-3470 - [CN]NIKE_PHC_Wave Release_Add */
/*                            orderdate filter                          */
/* 2022-10-17  Wan06    1.8   Reverse JSM-81405 Fixed Code              */
/* 2022-10-17  Wan07    1.9   Fixed issue result from JSM-81405 solution*/
/*                            Refixed JSM-81405                         */
/* 2023-10-16  SPChin   2.0   UWP-7487 - Bug Fixed                      */
/* 2023-12-05  Wan08    2.1   LFWM-4625 - CLONE - PROD-CNWAVE Release   */
/*                            group search slow and build wave slow     */
/* 2023-01-18  Wan09    2.2   Revert As #TMP_order creation is needed   */
/* 2023-01-19  Wan10    2.3   Revert As #TMP_SKUTOTQTY creation is needed*/
/************************************************************************/
CREATE   PROC [WM].[lsp_WaveOrderAnalysis]
      @c_Facility          NVARCHAR(5)
   ,  @c_StorerKey         NVARCHAR(15)
   ,  @c_BuildParmGroup    NVARCHAR(30)
   ,  @c_BuildParmKey      NVARCHAR(10) = ''
   ,  @n_SessionNo         BIGINT = 0
   ,  @b_Success           INT = 1             OUTPUT
   ,  @n_err               INT = 0             OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)       OUTPUT
   ,  @c_UserName          NVARCHAR(128)= ''
   ,  @d_debug             INT   = 0         --2020-07-10
   ,  @c_SortPreference    NVARCHAR(100)= ''             --(Wan04)   -- Sort column + Sort type, If multiple Columns Sorting, seperate by ','
   ,  @dt_Date_Fr          DATETIME       = NULL         --(Wan05)
   ,  @dt_Date_To          DATETIME       = NULL         --(Wan05)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfAllocated   INT = 0
         , @n_NoOfPicked      INT = 0
         , @n_TotalBuild      INT = 0
         , @n_BuildOrders     INT = 0
         , @n_WavedOrders     INT = 0
         , @n_RemainOrders    INT = 0
         , @n_TotalOrders     INT = 0

         , @n_AllocPctg       DECIMAL(10,2) = 0.00
         , @n_WavedPctg       DECIMAL(10,2) = 0.00

         --, @c_BuildParmKey    NVARCHAR(10)   = ''
         , @c_AnalysisType    NVARCHAR(10)   = 'SUMMARY'
         , @c_GenByBuildValue NVARCHAR(1)    = 'N'

         , @n_FromPos         INT            = 0
         , @n_ToPos           INT            = 0
         , @n_HavingPos       INT            = 0
         , @n_GroupByPos      INT            = 0

         , @n_MaxOpenQty      INT            = 0   --2020-07-10
         , @n_MaxOpenQty01    INT            = 0   --2020-07-10
         , @n_MaxOpenQty02    INT            = 0   --2020-07-10
         , @n_MaxOpenQty03    INT            = 0   --2020-07-10
         , @n_MaxOpenQty04    INT            = 0   --2020-07-10
         , @n_MaxOpenQty05    INT            = 0   --2020-07-10

         , @c_SQL             NVARCHAR(4000) = ''
         , @c_SQLParms        NVARCHAR(250)  = ''
         , @c_SQLBuildWave    NVARCHAR(4000) = ''
         , @c_SQLHaving       NVARCHAR(1000) = ''

         , @CUR_PARMKEY       CURSOR
         , @c_BuildParmDesc   NVARCHAR(60)   = '' -- (Chai01)

   --(Wan05) - START    // Change to Temp Table FROM Variable table
   IF OBJECT_ID('tempdb..#t_WaveOrderAnalysis','u') IS NULL
   BEGIN
      CREATE TABLE #t_WaveOrderAnalysis
            (  BuildParmKey      NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  TotalBuild        INT            NOT NULL DEFAULT(0)
            ,  BuildOrders       INT            NOT NULL DEFAULT(0)
            ,  WavedOrders       INT            NOT NULL DEFAULT(0)
            ,  Allocated         INT            NOT NULL DEFAULT(0)
            ,  Picked            INT            NOT NULL DEFAULT(0)
            ,  RemainOrders      INT            NOT NULL DEFAULT(0)
            ,  SummWaved         INT            NOT NULL DEFAULT(0)
            ,  SummWavedPctg     DECIMAL(10,2)  NOT NULL DEFAULT(0)
            ,  SummAllocated     INT            NOT NULL DEFAULT(0)
            ,  SummAllocPctg     DECIMAL(10,2)  NOT NULL DEFAULT(0)
            ,  SummTotalOrders   INT            NOT NULL DEFAULT(0)
            ,  BuildParmDesc     NVARCHAR(60)   NOT NULL DEFAULT('') -- (Chai01)
            )
   END
   --(Wan05) - END

   SET @n_Err = 0

   IF SUSER_SNAME() <> @c_UserName     --(Wan01) - START
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
   END                                 --(Wan01) - END

   BEGIN TRY -- SWT01 - Begin Outer Begin Try
             --
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL        --(Wan09)
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (
         OrderKey NVARCHAR(10)   NULL
      )
   END
   --(Wan03) - START
   ELSE
   BEGIN
      TRUNCATE TABLE #TMP_ORDERS;
   END

   IF OBJECT_ID('tempdb..#TMP_SKUTOTQTY','u') IS NULL     --(Wan10)
   BEGIN
      CREATE TABLE #TMP_SKUTOTQTY
      (
         RowID          INT            NOT NULL DEFAULT(0)
      ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Qty            INT            NOT NULL DEFAULT(0)

      )
   END
   ELSE
   BEGIN
      TRUNCATE TABLE #TMP_SKUTOTQTY;
   END
   --(Wan03) - END

   SET @c_BuildParmKey = ISNULL(RTRIM(@c_BuildParmKey),'')

   IF @c_BuildParmKey <> ''
   BEGIN
      SET @c_AnalysisType = 'BUILDKEY'
   END

   SET @CUR_PARMKEY = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT BP.BuildParmKey
   FROM   BUILDPARMGROUPCFG CFG WITH (NOLOCK)
   JOIN   BUILDPARM BP WITH (NOLOCK) ON (CFG.ParmGroup = BP.ParmGroup)
   WHERE  CFG.ParmGroup = @c_BuildParmGroup
   AND    CFG.Storerkey = @c_Storerkey
   AND   (CFG.Facility  = @c_Facility OR CFG.Facility = '')
   AND   (BP.BuildParmKey = @c_BuildParmKey OR @c_BuildParmKey = '')
   AND    CFG.[Type] = 'BuildWaveParm'
   AND    BP.Active = '1'
   ORDER BY BP.BuildParmKey

   OPEN @CUR_PARMKEY

   FETCH NEXT FROM @CUR_PARMKEY INTO @c_BuildParmKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_TotalOrders = 0

      --2020-07-10 - START
      SELECT @n_MaxOpenQty01 = CASE WHEN BP.Restriction01 = '2_MaxQtyPerBuild' THEN BP.RestrictionValue01  ELSE 0 END
          ,  @n_MaxOpenQty02 = CASE WHEN BP.Restriction02 = '2_MaxQtyPerBuild' THEN BP.RestrictionValue02  ELSE 0 END
          ,  @n_MaxOpenQty03 = CASE WHEN BP.Restriction03 = '2_MaxQtyPerBuild' THEN BP.RestrictionValue03  ELSE 0 END
          ,  @n_MaxOpenQty04 = CASE WHEN BP.Restriction04 = '2_MaxQtyPerBuild' THEN BP.RestrictionValue04  ELSE 0 END
          ,  @n_MaxOpenQty05 = CASE WHEN BP.Restriction05 = '2_MaxQtyPerBuild' THEN BP.RestrictionValue05  ELSE 0 END
          ,  @c_BuildParmDesc = BP.Description  -- (Chai01)
      FROM BUILDPARM BP WITH (NOLOCK)
      WHERE BP.BuildParmKey = @c_BuildParmKey

      SET @n_MaxOpenQty = @n_MaxOpenQty01

      IF @n_MaxOpenQty = 0
         SET @n_MaxOpenQty = @n_MaxOpenQty02
      IF @n_MaxOpenQty = 0
         SET @n_MaxOpenQty = @n_MaxOpenQty03
      IF @n_MaxOpenQty = 0
         SET @n_MaxOpenQty = @n_MaxOpenQty04
      IF @n_MaxOpenQty = 0
         SET @n_MaxOpenQty = @n_MaxOpenQty05
      --2020-07-10 - END

      GetBuildOrders:
      EXEC [WM].[lsp_Build_Wave]
            @c_BuildParmKey   = @c_BuildParmKey
         ,  @c_Facility       = @c_Facility
         ,  @c_StorerKey      = @c_StorerKey
         ,  @c_BuildWaveType  = 'ANALYSIS'
         ,  @c_GenByBuildValue= @c_GenByBuildValue
         ,  @c_SQLBuildWave   = @c_SQLBuildWave OUTPUT
         ,  @n_BatchNo        = 0
         ,  @b_Success        = @b_Success   OUTPUT
         ,  @n_err            = @n_err       OUTPUT
         ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT
         ,  @c_UserName       = @c_UserName
         ,  @dt_Date_Fr       = @dt_Date_Fr              --(Wan05)
         ,  @dt_Date_To       = @dt_Date_To              --(Wan05)

      IF @b_Success = 1
      BEGIN
         SET @n_BuildOrders = 0
         SET @n_FromPos   = CHARINDEX('FROM ', @c_SQLBuildWave , 1)
         --SET @n_HavingPos = CHARINDEX('HAVING', @c_SQLBuildWave, 1)      --(Wan07)
         --SET @n_GroupByPos= CHARINDEX('GROUP BY', @c_SQLBuildWave, 1)    --(Wan07)

         SET @n_ToPos = LEN(@c_SQLBuildWave) - @n_FromPos + 1              --(Wan07)
         /* (Wan07 - START
         IF @c_SQLHaving = 0   -- ZG01
         --IF @n_HavingPos = 0     -- ZG01                                 --Wan06
         BEGIN
            SET @n_ToPos = @n_GroupByPos - @n_FromPos
            IF @n_GroupByPos = 0
            BEGIN
               SET @n_ToPos = LEN(@c_SQLBuildWave) - @n_FromPos + 1
            END
            SET @c_SQL  = N'SELECT @n_BuildOrders = COUNT(DISTINCT ORDERS.Orderkey) '
                        + SUBSTRING(@c_SQLBuildWave, @n_FromPos, @n_ToPos)
         END
         ELSE
         BEGIN
            SET @c_SQL  = N'SELECT @n_BuildOrders = COUNT(1) FROM ( SELECT ORDERS.Orderkey'
                        + ' ' + CHAR(13) + SUBSTRING(@c_SQLBuildWave, @n_FromPos, @n_GroupByPos - @n_FromPos)
                        + ' ' + CHAR(13) + 'GROUP BY ORDERS.Orderkey'
                        + ' ' + CHAR(13) + SUBSTRING(@c_SQLBuildWave, @n_HavingPos, LEN(@c_SQLBuildWave) - @n_HavingPos + 1)
                        + ' ) t'
         END
         (Wan07) - END */

         SET @c_SQL  = N'SELECT @n_BuildOrders = COUNT(1) FROM ( SELECT ORDERS.Orderkey'              --(Wan07)
                     + ' ' + CHAR(13) + SUBSTRING(@c_SQLBuildWave, @n_FromPos, @n_ToPos)
                     + ' ) t'

         SET @c_SQLParms = N'@c_Facility     NVARCHAR(5)'
                         + ',@c_Storerkey    NVARCHAR(15)'  --UWP-7487
                         + ',@n_MaxOpenQty   INT'           --2020-07-10
                         + ',@n_BuildOrders  INT   OUTPUT'


         EXEC SP_EXECUTESQL
               @c_SQL
            ,  @c_SQLParms
            ,  @c_Facility
            ,  @c_Storerkey
            ,  @n_MaxOpenQty                                --2020-07-10
            ,  @n_BuildOrders  OUTPUT
      END

      SET @n_WavedOrders = 0
      SET @n_NoOfAllocated = 0
      SET @n_NoOfPicked= 0
      SET @n_RemainOrders= 0

      IF @c_AnalysisType = 'SUMMARY'
      BEGIN
         SELECT @n_WavedOrders   = COUNT(DISTINCT OH.Orderkey)
               ,@n_NoOfAllocated = ISNULL(SUM(CASE WHEN OH.[Status] = '2' THEN 1 ELSE 0 END),0)
               ,@n_NoOfPicked    = ISNULL(SUM(CASE WHEN OH.[Status] = '5' THEN 1 ELSE 0 END),0)
         FROM ORDERS OH WITH (NOLOCK)                                               --(Wan08) - START
         JOIN WAVE WH WITH(NOLOCK) ON WH.WaveKey = OH.UserDefine09
         JOIN BUILDWAVELOG BW WITH (NOLOCK) ON BW.BatchNo = WH.BatchNo
         --JOIN BUILDWAVEDETAILLOG BWD WITH (NOLOCK) ON (BW.BatchNo = BWD.BatchNo)
         --JOIN WAVEDETAIL WD WITH (NOLOCK) ON (WH.Wavekey = WD.Wavekey)
         WHERE OH.Facility = @c_Facility
         AND OH.Storerkey = @c_Storerkey
         AND OH.UserDefine09 IS NOT NULL AND OH.UserDefine09 <> ''
         AND OH.[Status] < '9'            --Fixed 2020-04-10 LFWM-2038              --(Wan08) - END
         AND BW.BuildParmGroup = @c_BuildParmGroup
         AND BW.BuildParmKey   = @c_BuildParmKey
      END
      ELSE
      BEGIN
         --SELECT @n_TotalOrders = COUNT(1)
         --FROM ORDERS OH WITH (NOLOCK)
         --WHERE OH.Facility = @c_Facility
         --AND OH.Storerkey = @c_Storerkey
         --AND OH.[Status] < '9'
         IF @c_GenByBuildValue = 'N' AND @n_BuildOrders > 0
         BEGIN
            SET @n_TotalOrders = @n_BuildOrders --@n_TotalOrders - @n_WavedOrders - @n_BuildOrders
            SET @c_GenByBuildValue = 'Y'
            GOTO GetBuildOrders
         END

         IF @n_SessionNo <> 0
         BEGIN
            SELECT @n_WavedOrders = COUNT(WD.Orderkey)
            FROM BUILDWAVELOG BW WITH (NOLOCK)
            JOIN BUILDWAVEDETAILLOG BWD WITH (NOLOCK) ON (BW.BatchNo = BWD.BatchNo)
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON (BWD.Wavekey = WD.Wavekey)
            WHERE BW.SessionNo  = @n_SessionNo
            AND BW.BuildParmKey = @c_BuildParmKey
         END

         SET @n_RemainOrders = @n_TotalOrders - @n_BuildOrders
      END

      SET @n_TotalBuild = @n_BuildOrders + @n_WavedOrders

      INSERT INTO #t_WaveOrderAnalysis                            --(Wan04)
         (  BuildParmKey
         ,  TotalBuild
         ,  BuildOrders
         ,  WavedOrders
         ,  Allocated
         ,  Picked
         ,  RemainOrders
         ,  BuildParmDesc  -- (Chai01)
         )
      VALUES
         (  @c_BuildParmKey
         ,  @n_TotalBuild
         ,  @n_BuildOrders
         ,  @n_WavedOrders
         ,  @n_NoOfAllocated
         ,  @n_NoOfPicked
         ,  @n_RemainOrders
         ,  @c_BuildParmDesc -- (Chai01)
         )

      --SET @n_TotalOrders = @n_TotalOrders + @n_BuildOrders

      FETCH NEXT FROM @CUR_PARMKEY INTO @c_BuildParmKey
   END
   CLOSE @CUR_PARMKEY
   DEALLOCATE @CUR_PARMKEY

   SET @n_NoOfAllocated = 0
   SET @n_WavedOrders   = 0
   SET @n_TotalOrders   = 0

   IF @c_AnalysisType = 'SUMMARY'
   BEGIN
      SELECT @n_NoOfAllocated = ISNULL(SUM(CASE WHEN OH.[Status] = '2' THEN 1 ELSE 0 END),0)
            ,@n_WavedOrders   = ISNULL(SUM(CASE WHEN OH.Userdefine09 IS NOT NULL
                                                AND  OH.Userdefine09 <> '' THEN 1 ELSE 0 END),0)   --(Wan08)
            ,@n_TotalOrders   = COUNT(1)
      FROM ORDERS OH WITH (NOLOCK)
      --LEFT JOIN WAVEDETAIL WD WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)                       --(Wan08)
      WHERE OH.Storerkey= @c_Storerkey
      AND   OH.Facility = @c_Facility
      AND   OH.[Status] < '9'

      IF @n_TotalOrders > 0
      BEGIN
         SET @n_AllocPctg = CONVERT(DECIMAL(10,2), @n_NoOfAllocated * 1.00 / @n_TotalOrders * 100.00)
         SET @n_WavedPctg = CONVERT(DECIMAL(10,2), @n_WavedOrders * 1.00 / @n_TotalOrders * 100.00)
      END
   END

   --(Wan04) - START
   UPDATE #t_WaveOrderAnalysis
   SET SummWaved      = @n_WavedOrders
      ,SummWavedPctg  = @n_WavedPctg
      ,SummAllocated  = @n_NoOfAllocated
      ,SummAllocPctg  = @n_AllocPctg
      ,SummTotalOrders= @n_TotalOrders


   SET @c_SortPreference = ISNULL(@c_SortPreference,'')
   IF @c_SortPreference = ''
   BEGIN
      SET @c_SortPreference = N' ORDER BY BuildParmKey ASC'
   END
   ELSE
   BEGIN
      SET @c_SortPreference = N' ORDER BY ' +  @c_SortPreference
   END

   SET @c_SQL = N'SELECT   BuildParmKey'
              + ',  TotalBuild'
              + ',  BuildOrders'
              + ',  WavedOrders'
              + ',  Allocated'
              + ',  Picked'
              + ',  RemainOrders'
              + ',  SummWaved'
              + ',  SummWavedPctg'
              + ',  SummAllocated'
              + ',  SummAllocPctg'
              + ',  SummTotalOrders'
              + ',  BuildParmDesc' -- (Chai01)
              + ' FROM #t_WaveOrderAnalysis'
              + @c_SortPreference

   EXEC (@c_SQL)
   --(Wan04) - END

   END TRY

   BEGIN CATCH
      SET @b_Success = 0               --Wan02
      SET @c_ErrMsg = 'Wave Order Analysis Failed. (lsp_WaveOrderAnalysis) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch

   EXIT_SP:
   REVERT
END

GO