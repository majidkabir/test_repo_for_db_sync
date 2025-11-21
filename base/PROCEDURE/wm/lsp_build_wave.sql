SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: lsp_Build_Wave                                      */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WM - Wave Creation                                          */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 3.1                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 04-Jan-2021 SWT02    1.1   Do not execute login if user already      */
/*                            changed                                   */
/* 2021-01-15  Wan01    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-03-23  Wan02    1.3   LFWM-2663 - UAT CN Customer Order Parameter*/
/*                            Build Parameter Add sql statement         */
/* 2021-04-08  Wan02    1.3   Exclude ORders.Userdefine08='Y'=> discrete */
/*                            order checking. it is standard initially  */
/*                            Refer to LFWM-2619 Shong comment          */
/* 2021-08-03  Wan03    1.4   LFWM-2948 - UATJPWaveMissing Order Parm   */
/*                            after setup the Group condition           */
/* 2021-09-06  Wan04    1.5   LFWM-2953 - UAT - ID  Include missing     */
/*                            'NOT LIKE' operator in Order Parameter    */
/* 2022-01-04  Wan05    1.6   LFWM-3279 - SCE UAT SG Order Parameter -  */
/*                            Type 'SORT' - Do not have Sku_Total_Qty as*/
/*                            in Exceed                                 */
/* 2022-01-04  Wan05    1.6   Devops Combine Script                     */
/* 2022-01-24  WinSern  1.7   INC1722704 @c_SQLWhere 2000 to 4000 (ws01)*/
/* 2022-02-16  Wan06    1.8   LFWM-3346 - CN NIKECN UAT Wave Release to */
/*                            limit Qty per wave                        */
/* 2022-05-16  LZG      1.9   Added missing ISNUMERIC to cond level (ZG01)*/
/* 2022-05-24  Wan07    2.0   LFWM-3534 - Issue during 2022-05-12 SVT   */
/* 2022-05-31  Wan08    2.1   LFWM-3543 - SCE Order Parameter Enhancement*/
/* 2022-08-05  Wan09    2.2   LFWM-3672 - [CN] LOREAL_New Tab for order */
/*                            analysis                                  */
/* 2022-09-20  Wan11    2.3   LFWM-3763 - SCE  LOREAL PROD  Cannot build*/
/*                            wave. Fix Truncated value                 */
/* 2022-08-10  Wan10    2.4   LFWM-3470 - [CN]NIKE_PHC_Wave Release_Add */
/*                            orderdate filter                          */
/* 2022-11-04  Wan12    2.5   Fixed incorrent duration & TotalWaveCnt   */
/*                            due to rebuild using same batchno         */
/* 2023-03-20  Wan13    2.6   LFWM-4085 - UAT -CN  Build Wave error     */
/*                            parameters not tally                      */
/* 2023-05-17  Wan14    2.7   LFWM-4244 - PROD-CN SCE Wave BuildGenerate*/
/*                            Load                                      */
/* 2023-05-26  Wan15    2.7   LFWM-4297 - PROD - CN WaveParm_Sort by LOC*/
/* 2023-05-31  Wan16    2.8   LFWM-4288 - TW UAT SCE Build Wave Parameter*/
/* 2023-06-26  CF01     2.9   Reduce increment to only by one           */
/* 2023-10-12  Wan17    2.9   LFWM-4529 - PROD-CNWAVE Release group     */
/*                            search slow and build wave slow           */
/* 2023-12-05  Wan18    3.0   LFWM-4625 - CLONE - PROD-CNWAVE Release   */
/*                            group search slow and build wave slow     */
/* 2024-02-02  WLChooi  3.1   LFWM-4602 - SCE| PROD| SG| Wave Control - */
/*                            Populate Orders - Top Up Orders With Same */
/*                            Parameter (WL01)                          */
/* 2024-03-22  Wan19    3.2   LFWM-4875 - MY-SCE-Order cannot Build Wave*/
/* 2024-04-17  WLChooi  3.3   LFWM-4863 - Initialize @c_Wavekey to blank*/
/*                            for non TopUpWave (WL02)                  */
/* 2024-05-21  Wan20    3.4   Fixed missing @n_MaxOpenQty Parameter     */
/************************************************************************/
CREATE   PROC [WM].[lsp_Build_Wave]
      @c_BuildParmKey      NVARCHAR(10)
   ,  @c_Facility          NVARCHAR(5)
   ,  @c_StorerKey         NVARCHAR(15)
   ,  @c_BuildWaveType     NVARCHAR(10)   = ''    --DEFAULT BLANK = BuildWave, Analysis, PreWave, TopUpWave & etc
   ,  @c_GenByBuildValue   NVARCHAR(1)    = 'Y'   --DEFAULT Y = Use BuildValue, Otherwise use Value
   ,  @c_SQLBuildWave      NVARCHAR(MAX)  = '' OUTPUT          --(Wan13)
   ,  @n_BatchNo           BIGINT         = 0  OUTPUT
   ,  @n_SessionNo         BIGINT         = 0  OUTPUT
   ,  @b_Success           INT            = 1  OUTPUT
   ,  @n_err               INT            = 0  OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT
   ,  @c_UserName          NVARCHAR(128)  = ''
   ,  @b_debug             INT            = 0
   ,  @dt_Date_Fr          DATETIME       = NULL               --(Wan10)
   ,  @dt_Date_To          DATETIME       = NULL               --(Wan10)
   ,  @c_Wavekey           NVARCHAR(10)   = ''   --WL01
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT

   DECLARE @n_CondLevel                INT            = 0
         , @n_PreCondLevel             INT            = 0
         , @n_CurrCondLevel            INT            = 0

         , @n_BuildWaveDetailLog_From  BIGINT         = 0                           --(Wan14)
         , @n_BuildWaveDetailLog_To    BIGINT         = 0                           --(Wan14)

         , @b_DeleteTmpOrders          BIT            = 0

         , @d_StartTime_Load           DATETIME       = NULL                        --(Wan14)
         , @d_StartBatchTime           DATETIME       = GETDATE()
         , @d_StartTime                DATETIME       = GETDATE()
         , @d_EndTime                  DATETIME
         , @d_StartTime_Debug          DATETIME       = GETDATE()
         , @d_EndTime_Debug            DATETIME
         , @d_EditDate                 DATETIME

         , @n_cnt                      INT            = 0
         , @n_BuildGroupCnt            INT            = 0

         , @n_MaxSKUInWave             INT            = 0                           --(Wan16)
         , @n_NoOfSKUInOrder           INT            = 0
         , @n_MaxWaveOrders            INT            = 0
         , @n_MaxOpenQty               INT            = 0
         , @n_MaxWave                  INT            = 0

         , @c_Restriction              NVARCHAR(30) = ''
         , @c_Restriction01            NVARCHAR(30) = ''
         , @c_Restriction02            NVARCHAR(30) = ''
         , @c_Restriction03            NVARCHAR(30) = ''
         , @c_Restriction04            NVARCHAR(30) = ''
         , @c_Restriction05            NVARCHAR(30) = ''
         , @c_RestrictionValue         NVARCHAR(10) = ''
         , @c_RestrictionValue01       NVARCHAR(10) = ''
         , @c_RestrictionValue02       NVARCHAR(10) = ''
         , @c_RestrictionValue03       NVARCHAR(10) = ''
         , @c_RestrictionValue04       NVARCHAR(10) = ''
         , @c_RestrictionValue05       NVARCHAR(10) = ''
         , @c_RestrictionBuildValue    NVARCHAR(10) = ''
         , @c_RestrictionBuildValue01  NVARCHAR(10) = ''
         , @c_RestrictionBuildValue02  NVARCHAR(10) = ''
         , @c_RestrictionBuildValue03  NVARCHAR(10) = ''
         , @c_RestrictionBuildValue04  NVARCHAR(10) = ''
         , @c_RestrictionBuildValue05  NVARCHAR(10) = ''

         , @b_JoinPickDetail           BIT            = 0
         , @b_JoinLoc                  BIT            = 0

         , @c_ParmGroup                NVARCHAR(30)   = ''
         , @c_ParmGroupType            NVARCHAR(30)   = ''
         , @c_BuildDateField           NVARCHAR(50)   = ''              --(Wan10)

         , @c_ParmBuildType            NVARCHAR(10)   = ''
         , @c_FieldName                NVARCHAR(100)  = ''
         , @c_OrAnd                    NVARCHAR(10)   = ''
         , @c_Operator                 NVARCHAR(60)   = ''
         , @c_Value                    NVARCHAR(4000) = ''

         , @c_TableName                NVARCHAR(30)   = ''
         , @c_ColName                  NVARCHAR(100)  = ''
         , @c_ColType                  NVARCHAR(128)  = ''

         , @b_GroupFlag                BIT            = 0
         , @c_SortBy                   NVARCHAR(2000) = ''
         , @c_SortSeq                  NVARCHAR(10)   = ''
         , @c_GroupBySortField         NVARCHAR(2000) = ''

         , @b_DeleteSkuTotQty          BIT            = 0               --(Wan05)
         , @c_SortBySkuTotalQty        NVARCHAR(2000) = ''              --(Wan05)
         , @c_SQLInsSkuTotQty          NVARCHAR(MAX)  = ''              --(Wan05)
         , @b_JoinTmpSku               BIT            = 0               --(Wan18)

         , @c_Field01                  NVARCHAR(60)   = ''
         , @c_Field02                  NVARCHAR(60)   = ''
         , @c_Field03                  NVARCHAR(60)   = ''
         , @c_Field04                  NVARCHAR(60)   = ''
         , @c_Field05                  NVARCHAR(60)   = ''
         , @c_Field06                  NVARCHAR(60)   = ''
         , @c_Field07                  NVARCHAR(60)   = ''
         , @c_Field08                  NVARCHAR(60)   = ''
         , @c_Field09                  NVARCHAR(60)   = ''
         , @c_Field10                  NVARCHAR(60)   = ''
         , @c_SQLField                 NVARCHAR(2000) = ''
         , @c_SQLFieldGroupBy          NVARCHAR(2000) = ''
         , @c_SQLBuildByGroup          NVARCHAR(4000) = ''
         , @c_SQLBuildByGroupWhere     NVARCHAR(4000) = ''
         , @c_SQLCondPreWave           NVARCHAR(2000) = ''              --(Wan09)
         , @c_SQLCondDate              NVARCHAR(500)  = ''              --(Wan10)

         , @b_ParmFound                BIT            = 0
         , @b_ParmTypeSP               INT            = 0
         , @n_idx                      INT            = 0
         , @c_SPName                   NVARCHAR(50)   = ''
         , @c_SPParms                  NVARCHAR(1000) = ''              --(Wan13)

         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         , @c_SQLWhere                 NVARCHAR(4000) = ''    --ws01
         , @c_SQLCond                  NVARCHAR(4000) = ''
         , @c_SQLGroupBy               NVARCHAR(2000) = ''
         , @c_SQLHaving                NVARCHAR(500)  = ''

         , @c_BatchNo                  NVARCHAR(10)   = ''
         , @n_Num                      INT            = 0
         , @n_OrderCnt                 INT            = 0
         , @n_WaveCnt                  INT            = 0
         , @n_MaxOrders                INT            = 0
         , @n_OpenQty                  INT            = 0
         , @n_TotalOrders              INT            = 0
         , @n_TotalOpenQty             INT            = 0
         , @n_TotalOrderCnt            INT            = 0
         , @n_ToBeSkuInWave            INT            = 0                           --(Wan16)
         , @n_Weight                   FLOAT          = 0.00
         , @n_Cube                     FLOAT          = 0.00
         , @n_TotalWeight              FLOAT          = 0.00
         , @n_TotalCube                FLOAT          = 0.00

         , @c_BuildWaveKey             NVARCHAR(10)   = ''
         --, @c_WaveKey                  NVARCHAR(10)   = ''   --WL01
         , @c_TopUpWave                NVARCHAR(10)   = IIF(ISNULL(@c_WaveKey, '') = '', 'N', 'Y')   --WL01
         , @c_WaveDetailkey            NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = ''
         , @c_OrderStatus              NVARCHAR(10)   = ''                          --(Wan17)
         , @c_WaveStatus               NVARCHAR(10)   = ''                          --(Wan17)
         , @c_PickdetailKey            NVARCHAR(10)   = ''                          --(Wan17)

         , @c_OWITF                    NVARCHAR(1)    = '0'
         , @n_FetchOrderStatus         INT            = 0

   DECLARE @CUR_BUILD_SORT             CURSOR
         , @CUR_BUILD_COND             CURSOR
         , @CUR_BUILD_SP               CURSOR
         , @CUR_BUILDWAVE              CURSOR
         , @CUR_PD                     CURSOR                                       --(Wan17)

   SET @b_Success = 1
   SET @n_Err     = 0

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

      -- SWT02
      IF SUSER_SNAME() <> @c_UserName
      BEGIN
         EXECUTE AS LOGIN = @c_UserName
      END
   END                                 --(Wan01) - END

   BEGIN TRY -- SWT01 - Begin Outer Begin Try
      --(Wan09) - START
      IF @c_BuildWaveType IN ('','TopUpWave')   --WL01      -- NOT IN ('ANALYSIS', 'PREWAVE')
      BEGIN
         EXEC [WM].[lsp_Build_Wave_VLDN]
            @c_BuildParmKey = @c_BuildParmKey
         ,  @b_Success      = @b_Success  OUTPUT
         ,  @n_err          = @n_err      OUTPUT
         ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
         ,  @b_debug        = @b_debug

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END
      --(Wan09) - END

      CREATE TABLE #tOrderData
      (
         RNum              INT PRIMARY KEY
      ,  OrderKey          NVARCHAR(10)   DEFAULT ('')
      ,  ExternOrderKey    NVARCHAR(30)   NULL DEFAULT ('')
      ,  ConsigneeKey      NVARCHAR(15)   NULL DEFAULT ('')
      ,  C_Company         NVARCHAR(45)   NULL DEFAULT ('')
      ,  OpenQty           INT            NULL DEFAULT (0)
      ,  [TYPE]            NVARCHAR(10)   NULL DEFAULT ('')
      ,  [Priority]        NVARCHAR(10)   NULL DEFAULT ('9')
      ,  [Door]            NVARCHAR(10)   NULL DEFAULT ('99')
      ,  [Route]           NVARCHAR(10)   NULL DEFAULT ('99')
      ,  [Stop]            NVARCHAR(10)   NULL DEFAULT ('')
      ,  OrderDate         DATETIME       NULL
      ,  DeliveryDate      DATETIME       NULL
      ,  DeliveryPlace     NVARCHAR(30)   NULL DEFAULT ('')
      ,  [Status]          NVARCHAR(10)   NULL DEFAULT (0)
      ,  [Weight]          FLOAT          NULL DEFAULT (0.00)
      ,  [Cube]            FLOAT          NULL DEFAULT (0.00)
      ,  NoOfOrdLines      INT            NULL DEFAULT (0)
      ,  AddWho            NVARCHAR(128)  DEFAULT ('')
      )

      IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
      BEGIN
         CREATE TABLE #TMP_ORDERS
         (
            OrderKey       NVARCHAR(10)   NULL
         )
         SET @b_DeleteTmpOrders = 1
      END
      --(Wan05) - START
      ELSE
      BEGIN
         TRUNCATE TABLE #TMP_ORDERS;
      END

      IF OBJECT_ID('tempdb..#TMP_SKUTOTQTY','u') IS NULL
      BEGIN
         CREATE TABLE #TMP_SKUTOTQTY
         (
            RowID          INT            NOT NULL DEFAULT(0)
         ,  Storerkey      NVARCHAR(15)   NOT NULL DEFAULT('')
         ,  Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Qty            INT            NOT NULL DEFAULT(0)

         )
         SET @b_DeleteSkuTotQty = 1
      END
      ELSE
      BEGIN
         TRUNCATE TABLE #TMP_SKUTOTQTY;
      END
      --(Wan05) - END

      IF @b_debug = 2
      BEGIN
         SET @d_StartTime_Debug = GETDATE()
         PRINT 'SP-lsp_Build_Wave DEBUG-START...'
         PRINT '--1.Do Generate SQL Statement--'
      END

      SET @n_err = 0
      SET @c_ErrMsg = ''
      SET @b_Success = 1

      SET @c_ParmGroup = ''
      SELECT @c_ParmGroup = ISNULL(RTRIM(BP.ParmGroup),'')
      FROM BUILDPARM BP WITH (NOLOCK)
      WHERE BP.BuildParmKey = @c_BuildParmKey

      SELECT @c_ParmGroupType = CFG.[Type]
            ,@c_BuildDateField = ISNULL(CFG.BuildDateField,'')                                     --(Wan10)
      FROM BUILDPARMGROUPCFG CFG WITH (NOLOCK)
      WHERE ParmGroup = @c_ParmGroup

      IF @c_BuildDateField <> '' AND @dt_Date_Fr IS NOT NULL AND @dt_Date_To IS NOT NULL           --(Wan10) - START
      BEGIN
         SET @c_SQLCondDate = ' AND ' + @c_BuildDateField
                            + ' BETWEEN ''' + CONVERT( CHAR(23), @dt_Date_Fr, 121)
                            + ' '' AND ''' + CONVERT( CHAR(23), @dt_Date_To, 121) + ''''
      END                                                                                          --(Wan10) - END
      ------------------------------------------------------
      -- Get Build Wave Restriction:
      ------------------------------------------------------
      SET @n_NoOfSKUInOrder = 0
      SET @c_Operator  = ''
      SET @n_MaxWaveOrders = 0
      SET @n_MaxOpenQty= 0

      SELECT @c_Restriction01          = BP.Restriction01
            ,@c_Restriction02          = BP.Restriction02
            ,@c_Restriction03          = BP.Restriction03
            ,@c_Restriction04          = BP.Restriction04
            ,@c_Restriction05          = BP.Restriction05
            ,@c_RestrictionValue01     = BP.RestrictionValue01
            ,@c_RestrictionValue02     = BP.RestrictionValue02
            ,@c_RestrictionValue03     = BP.RestrictionValue03
            ,@c_RestrictionValue04     = BP.RestrictionValue04
            ,@c_RestrictionValue05     = BP.RestrictionValue05
            ,@c_RestrictionBuildValue01= BP.RestrictionBuildValue01
            ,@c_RestrictionBuildValue02= BP.RestrictionBuildValue02
            ,@c_RestrictionBuildValue03= BP.RestrictionBuildValue03
            ,@c_RestrictionBuildValue04= BP.RestrictionBuildValue04
            ,@c_RestrictionBuildValue05= BP.RestrictionBuildValue05
      FROM BUILDPARM BP WITH (NOLOCK)
      WHERE BP.BuildParmKey = @c_BuildParmKey

      SET @n_idx = 1
      WHILE @n_idx <= 5
      BEGIN
         SET @c_Restriction = CASE WHEN @n_idx = 1 THEN @c_Restriction01
                                   WHEN @n_idx = 2 THEN @c_Restriction02
                                   WHEN @n_idx = 3 THEN @c_Restriction03
                                   WHEN @n_idx = 4 THEN @c_Restriction04
                                   WHEN @n_idx = 5 THEN @c_Restriction05
                                   END
         SET @c_RestrictionValue = CASE WHEN @n_idx = 1 THEN @c_RestrictionValue01
                                        WHEN @n_idx = 2 THEN @c_RestrictionValue02
                                        WHEN @n_idx = 3 THEN @c_RestrictionValue03
                                        WHEN @n_idx = 4 THEN @c_RestrictionValue04
                                        WHEN @n_idx = 5 THEN @c_RestrictionValue05
                                        END
         SET @c_RestrictionBuildValue = CASE WHEN @n_idx = 1 THEN @c_RestrictionBuildValue01
                                             WHEN @n_idx = 2 THEN @c_RestrictionBuildValue02
                                             WHEN @n_idx = 3 THEN @c_RestrictionBuildValue03
                                             WHEN @n_idx = 4 THEN @c_RestrictionBuildValue04
                                             WHEN @n_idx = 5 THEN @c_RestrictionBuildValue05
                                             END

         IF @c_Restriction = '1_MaxOrderPerBuild'
         BEGIN
            SET @n_MaxWaveOrders = @c_RestrictionValue
            IF @c_BuildWaveType = ''
            BEGIN
               SET @n_MaxWaveOrders = @c_RestrictionBuildValue
            END
         END

         IF @c_Restriction = '2_MaxQtyPerBuild'
         BEGIN
            SET @n_MaxOpenQty = @c_RestrictionValue
            IF @c_BuildWaveType = ''
            BEGIN
               SET @n_MaxOpenQty = @c_RestrictionBuildValue
            END
         END

         IF @c_Restriction = '3_MaxBuild'
         BEGIN
            SET @n_MaxWave = @c_RestrictionValue
            IF @c_BuildWaveType = ''
            BEGIN
               SET @n_MaxWave = @c_RestrictionBuildValue
            END
         END

         IF @c_Restriction Like '%_NoOfSkuInOrder'
         BEGIN
            SET @c_Operator = ''
            SELECT @c_Operator = CL.Short
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = 'BLDPRMREST'
            AND   CL.Code = @c_Restriction

            SET @n_NoOfSKUInOrder = @c_RestrictionValue
            IF @c_BuildWaveType = ''
            BEGIN
               SET @n_NoOfSKUInOrder = @c_RestrictionBuildValue
            END

            IF ISNULL(@c_Operator,'') = ''
            BEGIN
               SET @c_Operator = '='
            END

            IF @c_SQLHaving = ''
            BEGIN
               SET @c_SQLHaving = ' HAVING '
            END
            ELSE
            BEGIN
               SET @c_SQLHaving = @c_SQLHaving + ' AND '
            END

            SET @c_SQLHaving= @c_SQLHaving + 'COUNT(DISTINCT ORDERDETAIL.SKU) '
                            + RTRIM(@c_Operator)
                            + ' '
                            + CAST(@n_NoOfSKUInOrder AS NVARCHAR)
         END
         --SET @n_idx = @n_idx + 1                                                     --(CF01)

         IF @c_Restriction Like '9_MaxSkuPerWave'                                   --(Wan16) - START
         BEGIN
            SET @n_MaxSkuInWave = @c_RestrictionValue
            IF @c_BuildWaveType = ''
            BEGIN
               SET @n_MaxSkuInWave = @c_RestrictionBuildValue
            END

            IF @c_SQLHaving = ''
            BEGIN
               SET @c_SQLHaving = ' HAVING '
            END
            ELSE
            BEGIN
               SET @c_SQLHaving = @c_SQLHaving + ' AND '
            END

            SET @c_SQLHaving= @c_SQLHaving + 'COUNT(DISTINCT ORDERDETAIL.SKU)'
                            + ' <= '
                            + CAST(@n_MaxSkuInWave AS NVARCHAR)
         END                                                                        --(Wan16) - END
         SET @n_idx = @n_idx + 1
      END
      --------------------------------------------------
      -- Get Build Wave By Sorting & Grouping Condition
      --------------------------------------------------
      SET @b_JoinPickDetail = 0
      SET @b_JoinLoc = 0
      SET @n_BuildGroupCnt = 0
      SET @c_GroupBySortField = ''
      SET @c_SQLBuildByGroupWhere = ''
      SET @CUR_BUILD_SORT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 10
            BPD.FieldName
         ,  BPD.Operator
         ,  BPD.[Type]
      FROM  BUILDPARMDETAIL BPD WITH (NOLOCK)
      WHERE BPD.BuildParmKey = @c_BuildParmKey
      AND   BPD.[Type]  IN ('SORT','GROUP')
      ORDER BY BPD.BuildParmLineNo

      OPEN @CUR_BUILD_SORT

      FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                          ,@c_Operator
                                          ,@c_ParmBuildType
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Get Column Type
         --(Wan05) - START
         SET @c_TableName = ''
         IF CHARINDEX('.', @c_FieldName, 1) = 0
         BEGIN
            IF @c_FieldName = 'SKU_TOTAL_OPENQTY'
            BEGIN
               SET @c_SortBySkuTotalQty = CASE WHEN @c_Operator = 'DESC' THEN 'MAX(TMP2.Qty) DESC, MAX(TMP2.RowID) DESC'
                                               WHEN @c_Operator = 'ASC'  THEN 'MIN(TMP2.Qty), MIN(TMP2.RowID)'
                                               ELSE ''
                                          END

               SET @c_SQLInsSkuTotQty = N'INSERT INTO #TMP_SKUTOTQTY ( RowID, Storerkey, Sku, Qty )'
                                     + CHAR(13) + 'SELECT RowID = ROW_NUMBER() OVER (ORDER BY SUM(o.OpenQty), o.StorerKey, o.Sku)'
                                     + CHAR(13) + ',o.Storerkey, o.Sku, Qty=SUM(o.OpenQty)'
                                     + CHAR(13) + 'FROM #tOrderData t'
                                     + CHAR(13) + 'JOIN dbo.ORDERDETAIL o WITH (NOLOCK) ON o.Orderkey = t.Orderkey'
                                     + CHAR(13) + 'GROUP BY o.Storerkey, o.Sku'
            END

            GOTO NEXT_SORT
         END
         --(Wan05) - END

         SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)
         SET @c_ColName   = SUBSTRING(@c_FieldName,
                              CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))

         SET @c_ColType = ''
         SELECT @c_ColType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColName

         IF ISNULL(RTRIM(@c_ColType), '') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err     = 555501
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Invalid Sort/Group Column Name: ' + @c_FieldName
                           + ' (lsp_Build_Wave)'
                           + '|' + @c_FieldName
            GOTO EXIT_SP
         END

         IF @c_ParmBuildType = 'SORT'
         BEGIN
            IF @c_Operator = 'DESC'
               SET @c_SortSeq = 'DESC'
            ELSE
               SET @c_SortSeq = ''

            IF @c_TableName IN ( 'ORDERDETAIL', 'PICKDETAIL' )                      --(Wan15)
               SET @c_FieldName = 'MIN('+RTRIM(@c_FieldName) + ')'
            ELSE
            BEGIN
               IF ISNULL(@c_GroupBySortField,'') = ''
                  SET @c_GroupBySortField = CHAR(13) + @c_FieldName
               ELSE
                  SET @c_GroupBySortField = @c_GroupBySortField + CHAR(13) + ', ' +  RTRIM(@c_FieldName)
            END

            IF ISNULL(@c_SortBy,'') = ''
               SET @c_SortBy = CHAR(13) + @c_FieldName + ' ' + RTRIM(@c_SortSeq)
            ELSE
               SET @c_SortBy = @c_SortBy + CHAR(13) + ', ' +  RTRIM(@c_FieldName) + ' ' + RTRIM(@c_SortSeq)
         END

         IF @c_ParmBuildType = 'GROUP' AND @c_BuildWaveType NOT IN ( 'ANALYSIS' )         --Wan03
         BEGIN
            SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1                      --Fixed counter increase for 'GROUP' only
            IF ISNULL(RTRIM(@c_TableName), '') NOT IN('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err    = 555516
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                             + ': Grouping Only Allow Refer To Orders/Orderinfo/Sku/Pickdetail/Loc Table''s Fields. Invalid Table: ' + RTRIM(@c_FieldName)
                             + '. (lsp_Build_Wave)'
                             + '|' + RTRIM(@c_FieldName)
               GOTO EXIT_SP
            END

            IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
            BEGIN
               SET @n_Continue = 3
               SET @n_Err    = 555517
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                             + ': Numeric/Text Column Type Is Not Allowed For Wave Grouping: ' + RTRIM(@c_FieldName)
                             + '. (lsp_Build_Wave)'
                             + '|' + RTRIM(@c_FieldName)
               GOTO EXIT_SP
            END

            IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar') -- SWT02
            BEGIN
               SET @c_SQLField = @c_SQLField + CHAR(13) + ',' + RTRIM(@c_FieldName)
               SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                                    + CHAR(13) + ' AND ' + RTRIM(@c_FieldName) + '='
                                    + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'
                                           WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'
                                           WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'
                                           WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'
                                           WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'
                                           WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'
                                           WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'
                                           WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'
                                           WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'
                                           WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END
               SET @b_GroupFlag = 1
            END

            IF @c_ColType IN ('datetime')
            BEGIN
               SET @c_SQLField = @c_SQLField + CHAR(13) +  ', CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)'
               SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                                    + CHAR(13) + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)='
                                    + CASE WHEN @n_BuildGroupCnt = 1  THEN '@c_Field01'
                                           WHEN @n_BuildGroupCnt = 2  THEN '@c_Field02'
                                           WHEN @n_BuildGroupCnt = 3  THEN '@c_Field03'
                                           WHEN @n_BuildGroupCnt = 4  THEN '@c_Field04'
                                           WHEN @n_BuildGroupCnt = 5  THEN '@c_Field05'
                                           WHEN @n_BuildGroupCnt = 6  THEN '@c_Field06'
                                           WHEN @n_BuildGroupCnt = 7  THEN '@c_Field07'
                                           WHEN @n_BuildGroupCnt = 8  THEN '@c_Field08'
                                           WHEN @n_BuildGroupCnt = 9  THEN '@c_Field09'
                                           WHEN @n_BuildGroupCnt = 10 THEN '@c_Field10' END
               SET @b_GroupFlag = 1
            END
         END

         IF @c_TableName = 'LOC'
         BEGIN
            SET @b_JoinPickDetail = 1
            SET @b_JoinLoc = 1
         END

         IF @c_TableName = 'PICKDETAIL'
         BEGIN
            SET @b_JoinPickDetail = 1
         END

         NEXT_SORT:                             --(Wan05)
         FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                             ,@c_Operator
                                             ,@c_ParmBuildType
      END
      CLOSE @CUR_BUILD_SORT
      DEALLOCATE @CUR_BUILD_SORT

      IF ISNULL(@c_SortBy,'') = ''
      BEGIN
         SET @c_SortBy = 'ORDERS.[OrderKey]'
      END

      ------------------------------------------------------
      -- Get Build Wave Condition: General
      ------------------------------------------------------
      SET @CUR_BUILD_COND = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT BPD.ConditionLevel
            ,BPD.FieldName
            ,BPD.OrAnd
            ,BPD.Operator
            ,BuildValue = CASE WHEN @c_GenByBuildValue = 'Y' AND @c_ParmGroupType = 'BuildWaveParm' --AND BPD.BuildValue <> ''
                               THEN RTRIM(BPD.BuildValue)
                               ELSE BPD.[Value]
                               END
      FROM  BUILDPARMDETAIL BPD WITH (NOLOCK)
      WHERE BPD.BuildParmKey = @c_BuildParmKey
      AND   BPD.[Type]       = 'CONDITION'
      ORDER BY BPD.BuildParmLineNo

      OPEN @CUR_BUILD_COND

      FETCH NEXT FROM @CUR_BUILD_COND INTO @n_CondLevel
                                          ,@c_FieldName
                                          ,@c_OrAnd
                                          ,@c_Operator
                                          ,@c_Value
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNUMERIC(@n_CondLevel) = 1     -- ZG01
         BEGIN
            IF @n_PreCondLevel=0
            BEGIN
               SET @n_PreCondLevel = @n_CondLevel
            END
            SET @n_CurrCondLevel =  @n_CondLevel
         END

         -- Get Column Type
         SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)
         SET @c_ColName   = SUBSTRING(@c_FieldName,
                            CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))

         SET @c_ColType = ''
         SELECT @c_ColType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColName

         IF ISNULL(RTRIM(@c_ColType), '') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err     = 555502
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Invalid Condition Column Name: ' + @c_FieldName
                           + ' (lsp_Build_Wave)'
                           + '|' + @c_FieldName
            GOTO EXIT_SP
         END

         IF @c_ColType = 'datetime' AND
            ISDATE(@c_Value) <> 1
         BEGIN
            -- SHONG01
            IF @c_Value IN ('today','now', 'startofmonth', 'endofmonth', 'startofyear', 'endofyear')
               OR LEFT(@c_Value,6) IN ('today+', 'today-')
            BEGIN
               SET @c_Value =
                     CASE
                        WHEN @c_Value = 'today'
                        THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                        WHEN LEFT(@c_Value,6) IN ('today+', 'today-') AND ISNUMERIC(SUBSTRING(@c_Value,7,10)) = 1
                        THEN LEFT(CONVERT(VARCHAR(30), DATEADD(DAY, CONVERT(INT,SUBSTRING(@c_Value,6,10)),GETDATE()), 120), 10)
                        WHEN @c_Value = 'now'
                        THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                        WHEN @c_Value = 'startofmonth'
                        THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-'
                        + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) + ('-01')
                        WHEN @c_Value = 'endofmonth'
                        THEN CONVERT(VARCHAR(30), DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)), 120)
                        WHEN @c_Value = 'startofyear'
                        THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-01-01'
                        WHEN @c_Value = 'endofyear'
                        THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-12-31 23:59:59'
                        ELSE LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                        END
            END
            ELSE
            BEGIN
               SET @n_Continue = 3
               SET @n_Err     = 555518
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': Invalid Date Format: ' + @c_Value
                              + ' (lsp_Build_Wave)'
                               + '|' + @c_Value
               GOTO EXIT_SP
            END
         END

         IF @n_PreCondLevel < @n_CurrCondLevel
         BEGIN
            SET @c_SQLCond = @c_SQLCond + ' ' + CHAR(13) + ' ' + @c_OrAnd + N' ('
            SET @n_PreCondLevel = @n_CurrCondLevel
         END
         ELSE IF @n_PreCondLevel > @n_CurrCondLevel
         BEGIN
            SET @c_SQLCond = @c_SQLCond + N') '  + CHAR(13) + ' ' + @c_OrAnd
            SET @n_PreCondLevel = @n_CurrCondLevel
         END
         ELSE
         BEGIN
            SET @c_SQLCond = @c_SQLCond + ' ' + CHAR(13) + ' ' + @c_OrAnd
         END

         --(Wan02 - START
         IF @c_Operator = 'IN SQL'
         BEGIN
            SET @c_Operator = 'IN'
         END
         --(Wan02 - END
         --(Wan08) - START
         IF @c_Operator = 'NOT IN SQL'
         BEGIN
            SET @c_Operator = 'NOT IN'
         END
         --(Wan02) - END

         IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar')
            SET @c_SQLCond = @c_SQLCond + ' ' + @c_FieldName + ' ' + @c_Operator +
                  CASE WHEN @c_Operator IN ( 'IN', 'NOT IN') THEN               --2020-04-24 - fixed
                     CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '(' THEN '(' ELSE '' END +
                     RTRIM(LTRIM(@c_Value)) +
                     CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> ')' THEN ') ' ELSE '' END
                  ELSE ' N' +
                     CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN '''' ELSE '' END +
                     RTRIM(LTRIM(@c_Value)) +
                     CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN ''' ' ELSE '' END
                  END
         ELSE IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
            SET @c_SQLCond = @c_SQLCond + ' ' + @c_FieldName + ' ' + @c_Operator  +
                  CASE
                  WHEN @c_Operator IN ( 'IN', 'NOT IN')  THEN                  --2020-04-24 - fixed
                     CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '(' THEN '(' ELSE '' END +
                     RTRIM(LTRIM(@c_Value)) +
                     CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> ')' THEN ') ' ELSE '' END
                  WHEN @c_Operator IN ( 'LIKE', 'NOT LIKE' ) THEN             --(Wan04)
                     ' N' +
                     CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN '''' ELSE '' END +
                     RTRIM(LTRIM(@c_Value)) +
                     CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN ''' ' ELSE '' END
                  ELSE
                     RTRIM(@c_Value)
                  END
         ELSE IF @c_ColType IN ('datetime')
            SET @c_SQLCond = @c_SQLCond + ' ' + @c_FieldName + ' ' + @c_Operator + ' '''+ @c_Value + ''' '

         IF @c_TableName = 'LOC'
         BEGIN
            SET @b_JoinPickDetail = 1
            SET @b_JoinLoc = 1
         END

         IF @c_TableName = 'PICKDETAIL'
         BEGIN
            SET @b_JoinPickDetail = 1
         END

         FETCH NEXT FROM @CUR_BUILD_COND INTO @n_CondLevel
                                             ,@c_FieldName
                                             ,@c_OrAnd
                                             ,@c_Operator
                                             ,@c_Value
      END
      CLOSE @CUR_BUILD_COND
      DEALLOCATE @CUR_BUILD_COND

      WHILE @n_PreCondLevel > 1
      BEGIN
         SET @c_SQLCond = @c_SQLCond + N') '
         SET @n_PreCondLevel = @n_PreCondLevel - 1
      END

      ------------------------------------------------------
      -- Get Build Wave Custom SP
      ------------------------------------------------------
      SET @b_ParmTypeSP = 0
      SET @c_SQL = ''
      SET @CUR_BUILD_SP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT BPD.[Value]
      FROM   BUILDPARMDETAIL BPD WITH (NOLOCK)
      WHERE  BPD.BuildParmKey = @c_BuildParmKey
      AND    BPD.[Type] =  'STOREDPROC'
      ORDER BY BPD.BuildParmLineNo

      OPEN @CUR_BUILD_SP

      FETCH NEXT FROM @CUR_BUILD_SP INTO @c_SQL

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_SQL <> ''
         BEGIN
            SET @c_SPName = @c_SQL
            SET @n_idx = CHARINDEX(' ',@c_SQL, 1)
            IF @n_idx > 0
            BEGIN
               SET @c_SPName = SUBSTRING(@c_SQL,1, @n_idx - 1)
            END

            --SET @b_ParmFound = 0                                                                             --(Wan12) - START
            --SELECT @b_ParmFound = 1
            --FROM [INFORMATION_SCHEMA].[PARAMETERS]
            --WHERE SPECIFIC_NAME = @c_SPName
            --AND PARAMETER_NAME = '@c_BuildWaveType'
            SET @c_SPParms = ''
            SELECT @c_SPParms = STRING_AGG(CONVERT(NVARCHAR(MAX),p.PARAMETER_NAME + '='
                                          + CASE WHEN p.PARAMETER_NAME='@c_ParmCodeCond' THEN '@c_SQLCond'
                                                 WHEN p.PARAMETER_NAME='@c_ParmCode' THEN '@c_BuildParmKey'
                                                 WHEN p.PARAMETER_NAME='@dt_StartDate' THEN '@dt_Date_Fr'
                                                 WHEN p.PARAMETER_NAME='@dt_EndDate' THEN '@dt_Date_To'
                                                 WHEN p.PARAMETER_NAME='@n_NoOfOrderToRelease' THEN '@n_MaxWaveOrders'
                                                 ELSE p.PARAMETER_NAME END)
                                           , ',' )
            WITHIN GROUP (ORDER BY p.ORDINAL_POSITION ASC)
            FROM [INFORMATION_SCHEMA].[PARAMETERS] AS p
            WHERE p.SPECIFIC_NAME = @c_SPName
            AND p.PARAMETER_NAME NOT IN ('@c_Parm01', '@c_Parm02','@c_Parm03','@c_Parm04','@c_Parm05')         --(Wan13) - END

            SET @c_SQL  = RTRIM(@c_SQL)
                        + CASE WHEN CHARINDEX('@',@c_SQL, 1) > 0  THEN ',' ELSE '' END
                        + @c_SPParms                                                                           --(Wan13)
                        --+ ' @c_Facility = @c_Facility'                                                       --(Wan13)
                        --+ ',@c_Storerkey= @c_StorerKey'                                                      --(Wan13)
                        --+ ',@c_BuildParmKey = @c_BuildParmKey'                                               --(Wan13)
                        --+ ',@c_ParmCodeCond = @c_SQLCond'                                                    --(Wan13)
                        --+ CASE WHEN @b_ParmFound = 0 THEN '' ELSE ', @c_BuildWaveType = @c_BuildWaveType' END--(Wan13)

            SET @c_SQLParms= N'@c_Facility      NVARCHAR(5)'
                           + ',@c_StorerKey     NVARCHAR(15)'
                           + ',@c_BuildParmKey  NVARCHAR(10)'
                           + ',@c_SQLCond       NVARCHAR(4000)'
                           + ',@c_BuildWaveType NVARCHAR(30)'
                           + ',@dt_Date_Fr      DATETIME'                                                      --(Wan13)
                           + ',@dt_Date_To      DATETIME'                                                      --(Wan13)
                           + ',@n_MaxWaveOrders INT'                                                           --(Wan13)

            EXEC sp_executesql @c_SQL
                              ,@c_SQLParms
                              ,@c_Facility
                              ,@c_StorerKey
                              ,@c_BuildParmKey
                              ,@c_SQLCond
                              ,@c_BuildWaveType
                              ,@dt_Date_Fr                                                                     --(Wan13)
                              ,@dt_Date_To                                                                     --(Wan13)
                              ,@n_MaxWaveOrders                                                                --(Wan13)

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err     = 555503
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': ERROR Executing Stored Procedure: ' + RTRIM(@c_SPName)
                              + ' (lsp_Build_Wave)'
                              + '|' + RTRIM(@c_SPName)
               GOTO EXIT_SP
            END
            SET @b_ParmTypeSP = 1

         END
         FETCH NEXT FROM @CUR_BUILD_SP INTO @c_SQL
      END
      CLOSE @CUR_BUILD_SP
      DEALLOCATE @CUR_BUILD_SP

      IF @b_ParmTypeSP = 1
      BEGIN
         SET @c_SQLCond = @c_SQLCond
                        + ' AND EXISTS (SELECT 1 FROM #TMP_ORDERS TMP WHERE TMP.Orderkey = ORDERS.Orderkey)'
      END

      ------------------------------------------------------
      -- Construct Build Wave SQL
      ------------------------------------------------------
      SET @c_OWITF = '0'
      --Wan02 - START - SCE able to populate any Orders.userdefine08 value to Wave even if storerconfig turn on
      --SELECT TOP 1 @c_OWITF = sValue
      --FROM  STORERCONFIG AS sc WITH(NOLOCK)
      --WHERE sc.StorerKey = @c_StorerKey
      --AND   sc.ConfigKey = 'OWITF'
      --AND   sc.SValue = '1'
      --Wan02 - END

      BUILD_WAVE_SQL:                                                               --(Wan05)
      SET @c_SQL = ''

      SET @c_SQL = N'INSERT INTO #tOrderData(RNUM,OrderKey,ExternOrderKey,Consigneekey,C_Company,OpenQty'
         + CHAR(13) + ',[Type],[Priority],[Door],[Route]'
         + CHAR(13) + ',OrderDate,DeliveryDate,DeliveryPlace,Status'
         + CHAR(13) + ',[Weight],[Cube],NoOfOrdLines,AddWho)'
         + CHAR(13) + ' SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@c_SortBy) + ') AS Number'
         + CHAR(13) + ',ORDERS.OrderKey,ORDERS.ExternOrderKey,ORDERS.Consigneekey,ORDERS.C_Company,ORDERS.OpenQty'
         + CHAR(13) + ',ORDERS.[Type],ORDERS.[Priority],ORDERS.[Door],ORDERS.[Route]'
         + CHAR(13) + ',ORDERS.OrderDate,ORDERS.DeliveryDate,ORDERS.DeliveryPlace,ORDERS.Status'
         + CHAR(13) + ',SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt), SUM(ORDERDETAIL.OpenQty * SKU.StdCube)'
         + CHAR(13) + ',COUNT(DISTINCT ORDERDETAIL.OrderLineNumber)'
         + CHAR(13) + ',''*'' + RTRIM(sUser_sName())'

      SET @c_SQLWhere = N' FROM ORDERS WITH (NOLOCK)'
         + CHAR(13) + 'LEFT OUTER JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey'
         + CHAR(13) + 'LEFT OUTER JOIN ORDERINFO (NOLOCK) ON ORDERS.OrderKey = ORDERINFO.OrderKey'
         + CHAR(13) + 'LEFT OUTER JOIN SKU (NOLOCK) ON ORDERS.StorerKey = SKU.StorerKey AND ORDERDETAIL.SKU = SKU.SKU'
         + CHAR(13) + 'LEFT OUTER JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = ORDERS.OrderKey'
         --(Wan05) - START
         + CASE WHEN @b_JoinTmpSku = 1                                              --(Wan18)
                THEN CHAR(13) + 'JOIN #TMP_SKUTOTQTY TMP2(NOLOCK) ON TMP2.Storerkey = ORDERDETAIL.Storerkey AND TMP2.SKU = SKU.SKU'
                ELSE ''
                END
         --(Wan05) - END
         + CASE WHEN @b_JoinPickDetail = 0 AND @b_JoinLoc = 0
                THEN ''
                ELSE
           CHAR(13) + 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.OrderKey=PICKDETAIL.Orderkey AND ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber'
                END
         + CASE WHEN @b_JoinLoc = 0
                THEN ''
                ELSE
           CHAR(13) + 'LEFT JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc=LOC.Loc AND LOC.Facility = @c_Facility'
                END
         + CHAR(13) + 'WHERE ORDERS.StorerKey = @c_StorerKey'
         + CHAR(13) + 'AND ORDERS.Facility = @c_Facility'
         + CHAR(13) + 'AND ORDERS.Status < ''9'''
         --+ CHAR(13) + 'AND ORDERS.[Type] NOT IN (''M'')'                                --(Wan19)
         + CHAR(13) + 'AND WD.WaveKey IS NULL'
         + CHAR(13) + 'AND (ORDERS.UserDefine09 = '''' OR ORDERS.UserDefine09 IS NULL)'
         + CHAR(13) + 'AND ORDERS.SOStatus <> ''PENDING'' '
         + CASE WHEN @n_MaxOpenQty = 0 THEN ''                                            --2020-07-10
                ELSE                                                                      --2020-07-10
           CHAR(13) + 'AND ORDERS.OpenQty <= @n_MaxOpenQty'                               --2020-07-10
                END                                                                       --2020-07-10

         + CHAR(13) + 'AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK)'
         + CHAR(13) +                 'WHERE CODELKUP.Code = ORDERS.SOStatus'
         + CHAR(13) +                 'AND CODELKUP.Listname = ''LBEXCSOSTS'''
         + CHAR(13) +                 'AND CODELKUP.Storerkey = ORDERS.Storerkey)'
         --+ CASE WHEN @c_OWITF = '0' THEN ''                                             --Wan02 - SCE able to populate any Orders.userdefine08 value to Wave even if storerconfig turn on
         --       ELSE
         --  CHAR(13) + 'AND (ORDERS.UserDefine08 = ''Y'' '
         --+ CHAR(13) + 'AND NOT EXISTS(SELECT 1 FROM TRANSMITLOG (NOLOCK) WHERE ORDERS.OrderKey = TRANSMITLOG.Key1'
         --+ CHAR(13) +                'AND TableName IN (''OWORDALLOC'', ''OWDPREPICK''))) '
         --       END
         + RTRIM(@c_SQLCond)

      --SET @c_SQLWhere = @c_SQLWhere + @c_SQLBuildByGroupWhere         --(Wan03) Do not add @c_SQLBuildByGroupWhere to @c_SQLWhere

      SET @c_SQLGroupBy = CHAR(13) + N'GROUP BY'
                        + CHAR(13) +  'ORDERS.OrderKey'
                        + CHAR(13) + ',ORDERS.ExternOrderKey'
                        + CHAR(13) + ',ORDERS.ConsigneeKey'
                        + CHAR(13) + ',ORDERS.C_Company'
                        + CHAR(13) + ',ORDERS.OpenQty'
                        + CHAR(13) + ',ORDERS.[Type]'
                        + CHAR(13) + ',ORDERS.Priority'
                        + CHAR(13) + ',ORDERS.Door'
                        + CHAR(13) + ',ORDERS.[Route]'
                        + CHAR(13) + ',ORDERS.OrderDate'
                        + CHAR(13) + ',ORDERS.DeliveryDate'
                        + CHAR(13) + ',ORDERS.DeliveryPlace'
                        + CHAR(13) + ',ORDERS.[Status]'


      IF @c_GroupBySortField <> ''
      BEGIN
         SET @c_SQLGroupBy= @c_SQLGroupBy+ ', ' + @c_GroupBySortField
      END

      IF @c_BuildWaveType = ''            --(Wan09) - START
      BEGIN
         SET @c_SQLCondPreWave = ''
         EXEC [WM].[lsp_BuildPreWaveCond]
            @c_BuildParmKey   = @c_BuildParmKey
         ,  @c_SQLCondPreWave = @c_SQLCondPreWave OUTPUT
         ,  @b_Success        = @b_Success        OUTPUT
         ,  @n_err            = @n_err            OUTPUT
         ,  @c_ErrMsg         = @c_ErrMsg         OUTPUT
         ,  @b_debug          = @b_debug

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END

         IF @c_SQLCondPreWave <> ''
         BEGIN
            SET @c_SQLWhere = @c_SQLWhere + @c_SQLCondPreWave
         END
      END                                 --(Wan09) - END

      SET @c_SQLWhere = @c_SQLWhere + @c_SQLCondDate                                               --(Wan10)

      SET @c_SQL = @c_SQL + @c_SQLWhere + @c_SQLBuildByGroupWhere +  @c_SQLGroupBy + @c_SQLHaving           --(Wan03)

      --(Wan05) - START
      IF @c_SQLInsSkuTotQty <> '' AND @c_SortBySkuTotalQty <> ''
      BEGIN
         SET @c_SQLParms= N' @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @n_MaxOpenQty INT'

         EXEC SP_EXECUTESQL @c_SQL
                           ,@c_SQLParms
                           ,@c_StorerKey
                           ,@c_Facility
                           ,@n_MaxOpenQty

         EXEC (@c_SQLInsSkuTotQty)

         TRUNCATE TABLE #tOrderData;
         SET @c_SortBy = @c_SortBySkuTotalQty + CASE WHEN @c_SortBy = '' THEN '' ELSE ', ' END + @c_SortBy
         SET @c_SQLInsSkuTotQty = ''
         SET @b_JoinTmpSku = 1                                                      --(Wan18)
         GOTO BUILD_WAVE_SQL
      END
      --(Wan05) - END

      SET @c_SQLBuildWave = @c_SQL     --2020-07-10  -- To Debug

      IF @c_BuildWaveType = 'ANALYSIS'
      BEGIN
         GOTO EXIT_SP
      END

      --(Wan09) - START
      IF @c_BuildWaveType = 'PREWAVE'
      BEGIN
         SET @c_SQLBuildWave = @c_SQLWhere

         GOTO EXIT_SP
      END
      --(Wan09) - END

      IF @c_SQLBuildByGroupWhere <> ''
      BEGIN
         SET @c_SQLFieldGroupBy = @c_SQLField

         WHILE @n_BuildGroupCnt < 10
         BEGIN
            SET @c_SQLField = @c_SQLField
                            + CHAR(13) + ','''''

            SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1
         END

         IF CURSOR_STATUS('global', 'CUR_WAVEGRP') IN (0 , 1)                       --(Wan20) - START
         BEGIN
            CLOSE CUR_WAVEGRP
            DEALLOCATE CUR_WAVEGRP
         END                                                                        --(Wan20) - END

         SET @c_SQLBuildByGroup  = N'DECLARE CUR_WAVEGRP CURSOR FAST_FORWARD READ_ONLY FOR '
                                 + CHAR(13) + ' SELECT @c_Storerkey '
                                 + @c_SQLField
                                 + @c_SQLWhere
                                 + CHAR(13) + ' GROUP BY ORDERS.Storerkey ' + @c_SQLFieldGroupBy
                                 + CHAR(13) + ' ORDER BY ORDERS.Storerkey ' + @c_SQLFieldGroupBy

         EXEC SP_EXECUTESQL @c_SQLBuildByGroup
               , N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_BuildParmKey NVARCHAR(10)
                  ,@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60), @c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60), @c_Field05 NVARCHAR(60)
                  ,@c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60),@c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)
                  ,@n_MaxOpenQty INT' --(Wan20) --(Wan03)
               , @c_StorerKey
               , @c_Facility
               , @c_BuildParmKey       --(Wan11)
               , @c_Field01            --(Wan03)
               , @c_Field02            --(Wan03)
               , @c_Field03            --(Wan03)
               , @c_Field04            --(Wan03)
               , @c_Field05            --(Wan03)
               , @c_Field06            --(Wan03)
               , @c_Field07            --(Wan03)
               , @c_Field08            --(Wan03)
               , @c_Field09            --(Wan03)
               , @c_Field10            --(Wan03)
               ,@n_MaxOpenQty          --(Wan20)

         OPEN CUR_WAVEGRP
         FETCH NEXT FROM CUR_WAVEGRP INTO @c_Storerkey
                                       ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05
                                       ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
         WHILE @@FETCH_STATUS = 0 AND @n_Continue = 1                               --(Wan17)
         BEGIN
            GOTO START_BUILDWAVE
            RETURN_BUILDWAVE:
            --WL01 S
            IF @c_TopUpWave = 'Y'
            BEGIN
               GOTO END_BUILDWAVE   --Top up Wave will not create new Wave
            END
            --WL01 E

            FETCH NEXT FROM CUR_WAVEGRP INTO @c_Storerkey
                                          ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05
                                          ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
         END
         CLOSE CUR_WAVEGRP
         DEALLOCATE CUR_WAVEGRP

         GOTO END_BUILDWAVE
      END

   START_BUILDWAVE:
      SET @c_WaveKey = IIF(ISNULL(@c_WaveKey, '') = '', '', @c_WaveKey)                          --2020-07-10   --WL01

      TRUNCATE TABLE #tOrderData

      IF @b_debug = 2
      BEGIN
         SET @d_EndTime_Debug = GETDATE()
         PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'
         PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
         PRINT '--2.Do Execute SQL Statement--'
         SET @d_StartTime_Debug = GETDATE()
      END

      SET @c_SQLParms= N'@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60), @c_Field03 NVARCHAR(60), @c_Field04 NVARCHAR(60)'
                     +', @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60)'
                     +', @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5)'
                     +', @c_BuildParmKey NVARCHAR(10)'   --(Wan11)
                     +', @n_MaxOpenQty INT'         --2020-07-10

      BEGIN TRY
      EXEC SP_EXECUTESQL @c_SQL
                        ,@c_SQLParms
                        ,@c_Field01
                        ,@c_Field02
                        ,@c_Field03
                        ,@c_Field04
                        ,@c_Field05
                        ,@c_Field06
                        ,@c_Field07
                        ,@c_Field08
                        ,@c_Field09
                        ,@c_Field10
                        ,@c_StorerKey
                        ,@c_Facility
                        ,@c_BuildParmKey           --(Wan11)
                        ,@n_MaxOpenQty             --2020-07-10

      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
      END CATCH

      IF @b_debug = 2
      BEGIN
         SET @d_EndTime_Debug = GETDATE()
         PRINT '--Finish Execute SQL Statement--(Check Temp DataStore In [Select View])'
         PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
         SELECT * FROM #tOrderData
         PRINT '--3.Do Initial Value Set Up--'
         SET @d_StartTime_Debug = GETDATE()
      END

      SELECT TOP 1 @n_Num = RNUM FROM #tOrderData ORDER BY RNUM DESC

      IF @n_Num = 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 555504
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': No Orders Found. (lsp_Build_Wave)'
         GOTO EXIT_SP
      END

      IF EXISTS(SELECT TOP 1 1 FROM WAVEDETAIL WD WITH (NOLOCK)
                JOIN #tOrderData T ON WD.OrderKey = T.OrderKey)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 555505
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': Found Same Order in Different WAVEDETAIL. (lsp_Build_Wave)'
         GOTO EXIT_SP
      END

      SET @n_MaxOrders =  @n_MaxWaveOrders
      --WL01 S
      IF @c_TopUpWave = 'Y' AND @c_Wavekey <> '' AND @n_MaxOrders > 0
      BEGIN
         SELECT @n_MaxOrders = @n_MaxOrders - COUNT(DISTINCT WD.OrderKey)
         FROM WAVEDETAIL WD (NOLOCK)
         WHERE WD.WaveKey = @c_Wavekey
      END
      --WL01 E
      IF @n_MaxWaveOrders = 0
      BEGIN
         SELECT @n_MaxOrders = COUNT(DISTINCT OrderKey)
         FROM   #tOrderData
      END

      IF @b_debug = 2
      BEGIN
         SET @d_EndTime_Debug = GETDATE()
         PRINT '--Finish Initial Value Setup--'
         PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
         PRINT '@c_BatchNo = ' + @c_BatchNo + ' ,@n_MaxOrders = ' + CAST(@n_MaxOrders AS NVARCHAR(20))
             + ' ,@n_MaxOpenQty = ' +  CAST(@n_MaxOpenQty AS NVARCHAR(20))
         PRINT '--4.Do Buil Wave--'
         SET @d_StartTime_Debug = GETDATE()
      END

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN;

      IF @n_MaxWave > 0 AND @n_WaveCnt >= @n_MaxWave  --- Need to check If Wave build By Muiltple Grouping; @n_WaveCnt get from previous wave group
      BEGIN
         GOTO END_BUILDWAVE
      END

      --WL01 S
      IF @n_MaxOrders <= 0 AND @c_TopUpWave = 'Y' AND @c_Wavekey <> ''
      BEGIN
         GOTO END_BUILDWAVE
      END
      --WL01 E

      IF @n_BatchNo = 0
      BEGIN
         BEGIN TRY
            INSERT INTO BUILDWAVELOG
               (  SessionNo
               ,  Facility
               ,  Storerkey
               ,  BuildParmGroup
               ,  BuildParmKey
               ,  BuildParmString
               ,  UDF01
               ,  AddWho
               ,  AddDate
               ,  UDF02   --WL01
               ,  UDF03   --WL01
               ,  UDF04   --WL01
               )
            VALUES
               (  @n_SessionNo
               ,  @c_Facility
               ,  @c_StorerKey
               ,  @c_ParmGroup
               ,  @c_BuildParmKey
               ,  @c_SQL
               ,  @@SPID
               ,  @c_UserName
               ,  @d_StartBatchTime
               ,  @c_Wavekey   --WL01
               ,  IIF(@dt_Date_Fr IS NOT NULL, CONVERT( CHAR(23), @dt_Date_Fr, 121), '')   --WL01
               ,  IIF(@dt_Date_To IS NOT NULL, CONVERT( CHAR(23), @dt_Date_To, 121), '')   --WL01
               )
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 555506
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Insert Into BUILDWAVELOG Failed. (lsp_Build_Wave) '
                           + '( ' + @c_ErrMsg + ') '

            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END
            GOTO EXIT_SP
         END CATCH

         SET @n_BatchNo = @@IDENTITY

         SET @c_BatchNo = ''
         SET @c_BatchNo  = CONVERT(VARCHAR(30), @n_BatchNo)

         IF @n_BatchNo = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err     = 555507
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Batch # is blank. (lsp_Build_Wave)'
            GOTO EXIT_SP
         END

         IF @n_SessionNo = 0
         BEGIN
            BEGIN TRY
               UPDATE BUILDWAVELOG
               SET SessionNo = @n_BatchNo
               WHERE BatchNo = @n_BatchNo
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg  = ERROR_MESSAGE()
               SET @n_Err     = 555519
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': UPDATE BUILDWAVELOG Failed. (lsp_Build_Wave) '
                              + '( ' + @c_ErrMsg + ') '

               IF (XACT_STATE()) = -1
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END
               GOTO EXIT_SP
            END CATCH

            SET @n_SessionNo = @n_BatchNo
         END
      END

      SET @n_OrderCnt     = 0
      SET @n_TotalOrderCnt= 0
      SET @n_TotalOpenQty = 0
      SET @c_WaveKey      = IIF(@c_TopUpWave = 'N', '', @c_WaveKey)   --WL01   --WL02

      SET @CUR_BUILDWAVE = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RNUM, OpenQty, OrderKey, [Weight], [Cube], [Status]                    --(Wan17)
      FROM #tOrderData
      ORDER BY RNUM

      OPEN @CUR_BUILDWAVE
      FETCH NEXT FROM @CUR_BUILDWAVE INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube
                                          ,@c_OrderStatus                           --(Wan17)
      SET @n_FetchOrderStatus = @@FETCH_STATUS
      WHILE @n_FetchOrderStatus <> -1
      BEGIN
         SET @n_Weight = ISNULL(@n_Weight,0.00)             --Wan07  Fix Insert TotalWeigh as NULL to BuildWaveDetailLog
         SET @n_Cube   = ISNULL(@n_Cube,0.00)               --Wan07  Fix Insert TotalWeigh as NULL to BuildWaveDetailLog
         IF @@TRANCOUNT = 0
            BEGIN TRAN;

         --2020-07-10 - START
         --IF @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0
         --BEGIN
         --   IF @n_TotalOpenQty = 0 AND @c_WaveKey = ''
         --   BEGIN
         --      SET @n_Continue = 3
         --      SET @n_Err     = 555508
         --      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
         --                     + ': No Order to Generate. (lsp_Build_Wave)'
         --      GOTO EXIT_SP
         --   END
         --   BREAK
         --END
         --2020-07-10 - END

         IF @c_WaveKey = ''
         BEGIN
            IF @n_MaxWave > 0 AND @n_WaveCnt >= @n_MaxWave
            BEGIN
               SET @n_Continue = 2                                                  --(Wan17)
               GOTO INSERT_DETLOG         --END_BUILDWAVE                           --(Wan17)
            END

            SET @d_StartTime = GETDATE()
            IF @d_StartTime_Load IS NULL SET @d_StartTime_Load = @d_StartTime       --(Wan17)
            SET @b_success = 1
            BEGIN TRY
               EXECUTE nspg_GetKey
                     'WaveKey'
                     , 10
                     , @c_WaveKey  OUTPUT
                     , @b_success  OUTPUT
                     , @n_err      OUTPUT
                     , @c_ErrMsg   OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_Err     = 555509
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': Error Executing nspg_GetKey - Wavekey. (lsp_Build_Wave)'
            END CATCH

            IF @b_success <> 1 OR @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO INSERT_DETLOG         --END_BUILDWAVE                           --(Wan17)
            END

            BEGIN TRY
               INSERT INTO WAVE (WaveKey, BatchNo)
               VALUES (@c_WaveKey, @n_BatchNo)
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg  = ERROR_MESSAGE()
               SET @n_Err     = 555510
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': Insert Into WAVE Failed. (lsp_Build_Wave) '
                              + '( ' + @c_ErrMsg + ') '

               IF (XACT_STATE()) = -1
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END
               GOTO INSERT_DETLOG         --END_BUILDWAVE                           --(Wan17)
            END CATCH

            SET @n_OrderCnt      = 0
            SET @n_TotalOpenQty  = 0
            SET @n_TotalWeight   = 0.00
            SET @n_TotalCube     = 0.00
            SET @n_WaveCnt       = @n_WaveCnt + 1
            SET @c_BuildWaveKey  = @c_Wavekey
            SET @c_WaveStatus    = '0'                                              --(Wan17)
         END
         ELSE IF @c_TopUpWave = 'Y' AND @c_Wavekey <> ''   --WL01 S
         BEGIN
            SET @c_BuildWaveKey  = @c_Wavekey
            SET @n_WaveCnt = 1
            SET @d_StartTime = GETDATE()
            IF @d_StartTime_Load IS NULL SET @d_StartTime_Load = @d_StartTime
         END
         --WL01 E

         IF @c_OrderStatus <= '5'                                                   --(Wan17)
         BEGIN
            IF @c_OrderStatus IN (3,4) SET @c_OrderStatus = '2'

            SET @c_WaveStatus = CASE WHEN @c_WaveStatus = '1' THEN '1'
                                     WHEN @c_WaveStatus = '5' AND @c_OrderStatus < '2' THEN '1'
                                     WHEN @c_WaveStatus = '2' AND @c_OrderStatus < '2' THEN '1'
                                     WHEN @c_WaveStatus = '2' AND @c_OrderStatus > '2' THEN '2'
                                     ELSE @c_OrderStatus
                                     END                                            --(Wan17)
         END

         IF @c_WaveKey = ''
         BEGIN
            SET @n_Continue = 2                                                     --(Wan17)
            GOTO INSERT_DETLOG         --END_BUILDWAVE                              --(Wan17)
         END

         IF @n_MaxSkuInWave > 0                                                     --(Wan16) - START
         BEGIN
            SELECT @n_ToBeSkuInWave = COUNT(w.Sku)
            FROM (
                     SELECT o.Sku
                     FROM dbo.WAVEDETAIL AS w (NOLOCK)
                     JOIN dbo.ORDERDETAIL AS o (NOLOCK) ON o.OrderKey = w.OrderKey
                     WHERE w.WaveKey = @c_WaveKey
                     UNION
                     SELECT o.Sku
                     FROM dbo.ORDERDETAIL AS o (NOLOCK)
                     WHERE o.OrderKey = @c_Orderkey
                  ) w

            IF @n_ToBeSkuInWave > @n_MaxSkuInWave
            BEGIN
               SET @c_WaveKey = ''
               SET @n_FetchOrderStatus = -1
               GOTO INSERT_DETLOG
            END
         END                                                                        --(Wan16) - END

         --(Wan06) - START
         IF @n_TotalOpenQty + @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0
         BEGIN
            SET @c_WaveKey = ''
            SET @n_FetchOrderStatus = -1
            GOTO INSERT_DETLOG
         END
         --(Wan06) - END

         BEGIN TRAN
         SET @d_EditDate = GETDATE()

         SET @b_success = 1

         BEGIN TRY
            EXECUTE nspg_GetKey
                  'WavedetailKey'
                  , 10
                  , @c_WavedetailKey   OUTPUT
                  , @b_success         OUTPUT
                  , @n_err             OUTPUT
                  , @c_ErrMsg          OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Err     = 555511
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Error Executing nspg_GetKey - WavedetailKey. (lsp_Build_Wave)'
         END CATCH

         IF @b_success <> 1 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO INSERT_DETLOG         --END_BUILDWAVE                              --(Wan17)
         END

         BEGIN TRY
            INSERT INTO WAVEDETAIL
                  (WavedetailKey, WaveKey, Orderkey, AddWho, Trafficcop)            --(Wan17)
            SELECT  @c_WavedetailKey
                  , @c_WaveKey
                  , T.OrderKey
                  , T.AddWho
                  , ''                                                              --(Wan18)
            FROM #tOrderData T
            WHERE T.RNUM = @n_Num
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 555512
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Insert Into WAVEDETAIL Failed. (lsp_Build_Wave) '
                           + '( ' + @c_ErrMsg + ') '

            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END
            GOTO INSERT_DETLOG         --END_BUILDWAVE                              --(Wan17)
         END CATCH

         IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey= @c_Orderkey AND UserDefine09 IN('',NULL))
         BEGIN
            BEGIN TRY
               UPDATE ORDERS  WITH (ROWLOCK)
               SET UserDefine09 = @c_WaveKey
                  ,ArchiveCop = NULL                                                   --(Wan17)
                  ,EditWho    = @c_UserName
                  ,EditDate   = @d_EditDate
               WHERE Orderkey = @c_Orderkey

               IF @c_OrderStatus > '0'
               BEGIN
                  SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                --(Wan17)
                  SELECT PickDetailKey FROM dbo.PICKDETAIL AS p (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND Wavekey <> @c_WaveKey

                  OPEN @CUR_PD

                  FETCH NEXT FROM @CUR_PD INTO @c_Pickdetailkey

                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
                        SET WaveKey  = @c_WaveKey
                           ,EditWho  = @c_UserName
                           ,EditDate = GETDATE()
                           ,ArchiveCop = NULL
                     WHERE PickDetailKey = @c_Pickdetailkey
                     FETCH NEXT FROM @CUR_PD INTO @c_Pickdetailkey
                  END
                  CLOSE @CUR_PD
                  DEALLOCATE @CUR_PD
               END                                                                  --(Wan17)
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg  = ERROR_MESSAGE()
               SET @n_Err     = 555513
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': UPDATE Orders/Pickdetail Failed. (lsp_Build_Wave) '
                              + '( ' + @c_ErrMsg + ') '

               IF (XACT_STATE()) = -1
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END

               GOTO INSERT_DETLOG         --END_BUILDWAVE                           --(Wan17)
            END CATCH
         END

         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         SET @n_TotalWeight  = @n_TotalWeight + @n_Weight
         SET @n_TotalCube    = @n_TotalCube + @n_Cube

         SET @n_OrderCnt     = @n_OrderCnt + 1
         --SET @n_TotalOrderCnt= @n_TotalOrderCnt + 1                            --(Wan06) Variable not use for any purposes
         SET @n_TotalOpenQty = @n_TotalOpenQty + @n_OpenQty

         IF (@n_OrderCnt + 1 > @n_MaxOrders) OR                                  --(Wan06)
            (@n_TotalOpenQty >= @n_MaxOpenQty AND @n_MaxOpenQty > 0)
         BEGIN
            SET @c_WaveKey = ''
         END

         IF @b_debug = 1
         BEGIN
            SELECT @@TRANCOUNT AS [TranCounts]
            SELECT @c_WaveKey 'wavekey', @n_OpenQty '@n_OpenQty',     @n_TotalOpenQty '@n_TotalOpenQty'
         END

         IF @c_WaveKey = ''
         BEGIN
            INSERT_DETLOG:
            --WHILE @@TRANCOUNT > 0
            --   COMMIT TRAN;
            IF @n_Continue IN (1,2)                                                 --(Wan17)
            BEGIN
               UPDATE dbo.WAVE WITH (ROWLOCK)
               SET [Status] = @c_WaveStatus
                  ,EditWho  = @c_UserName
                  ,EditDate = GETDATE()
                  ,ArchiveCop = NULL
               WHERE WaveKey= @c_BuildWaveKey
            END

            IF @n_Continue = 3 AND @@TRANCOUNT > 0 ROLLBACK TRAN                    --(Wan17)

            SET @d_EndTime = GetDate()

            BEGIN TRY
               INSERT INTO BUILDWAVEDETAILLOG
                  (  WaveKey
                  ,  Storerkey
                  ,  BatchNo
                  ,  TotalOrderCnt
                  ,  TotalOrderQty
                  ,  TotalWeight
                  ,  TotalCube
                  ,  UDF01
                  ,  UDF02
                  ,  UDF03
                  ,  UDF04
                  ,  UDF05
                  ,  AddWho
                  ,  AddDate
                  ,  Duration
                  )
               VALUES
                  (
                     @c_BuildWaveKey
                  ,  @c_Storerkey
                  ,  @n_BatchNo
                  ,  @n_OrderCnt
                  ,  @n_TotalOpenQty
                  ,  @n_TotalWeight
                  ,  @n_TotalCube
                  ,  CAST(@@TRANCOUNT AS VARCHAR(10))
                  ,  ''
                  ,  ''
                  ,  ''
                  ,  ''
                  ,  @c_UserName
                  ,  @d_StartTime
                  ,  CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)
                  )

               SET @n_BuildWaveDetailLog_To = @@IDENTITY                            --(Wan14) - START
               IF @n_BuildWaveDetailLog_From = 0
               BEGIN
                  SET @n_BuildWaveDetailLog_From = @n_BuildWaveDetailLog_To
               END                                                                  --(Wan14) - END
            END TRY

            BEGIN CATCH
               SET @n_Continue = 3
               SET @c_ErrMsg  = ERROR_MESSAGE()
               SET @n_Err     = 555514
               SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                              + ': Insert Into BUILDWAVEDETAILLOG Failed. (lsp_Build_Wave) '
                              + '( ' + @c_ErrMsg + ') '

               IF (XACT_STATE()) = -1
               BEGIN
                  ROLLBACK TRAN

                  WHILE @@TRANCOUNT < @n_StartTCnt
                  BEGIN
                     BEGIN TRAN
                  END
               END

               GOTO END_BUILDWAVE                                                   --(Wan17)
            END CATCH

            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END

            IF @n_FetchOrderStatus = -1
            BEGIN
               BREAK
            END

            IF @n_MaxWave > 0 AND @n_WaveCnt >= @n_MaxWave
            BEGIN
               GOTO END_BUILDWAVE
            END

            IF @n_Continue IN (2,3)                                                 --(Wan17)
            BEGIN
               GOTO END_BUILDWAVE
            END
         END

         FETCH NEXT FROM @CUR_BUILDWAVE INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube
                                             ,@c_OrderStatus                        --(Wan17)

         SET @n_FetchOrderStatus = @@FETCH_STATUS

         IF @n_FetchOrderStatus = -1 AND @c_WaveKey <> ''
         BEGIN
            GOTO INSERT_DETLOG
         END
      END -- WHILE(@@FETCH_STATUS <> -1)
      CLOSE @CUR_BUILDWAVE
      DEALLOCATE @CUR_BUILDWAVE

      IF @c_SQLBuildByGroup <> ''
      BEGIN
         GOTO RETURN_BUILDWAVE
      END

    END_BUILDWAVE:
      --(Wan09) - START
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      IF @n_BatchNo > 0
      BEGIN
         IF @c_SQLCondPreWave <> '' AND @c_TopUpWave <> 'Y'   --WL01
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.BUILDPREWAVE AS b WITH (NOLOCK)
                        WHERE BuildParmKey = @c_BuildParmkey
                        AND [Status] = '1'
                      )
            BEGIN
               UPDATE dbo.BUILDPREWAVE
                  SET [Status] = '9'
               WHERE BuildParmKey = @c_BuildParmkey
               AND [Status] = '1'

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 555521
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Update BUILDPREWAVE fail.'
                                   + ' (lsp_Build_Wave)'
                  GOTO EXIT_SP
               END
            END
         END

         IF @n_Continue IN (1,2)                                                   --(Wan17) - START
         BEGIN
            SET @b_Success = 1
            EXEC WM.lsp_Build_Wave_Update
               @n_BatchNo = @n_BatchNo
            ,  @b_Success = @b_Success  OUTPUT
            ,  @n_err     = @n_err      OUTPUT
            ,  @c_ErrMsg  = @c_ErrMsg   OUTPUT
            ,  @b_debug   = @b_debug

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               GOTO EXIT_SP
            END
         END                                                                        --(Wan17) - END
      END
      --(Wan09) - END

      IF @b_debug = 2
      BEGIN
         SET @d_EndTime_Debug = GETDATE()
         PRINT '--Finish Build Wave--'
         PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
         PRINT '--5.Insert Trace Log--'
         SET @d_StartTime_Debug = GETDATE()
      END

      --SET @c_ErrMsg = ''
      IF @b_debug = 2
      BEGIN
         SET @d_EndTime_Debug = GETDATE()
         PRINT '--Finish Insert Trace Log--'
         PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue= 3
      SET @c_ErrMsg  = ERROR_MESSAGE()  --(Wan01)
      GOTO EXIT_SP
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch
             --
EXIT_SP:
   IF @b_DeleteTmpOrders = 1
   BEGIN
      DROP TABLE #TMP_ORDERS
   END

   --(Wan05) - START
   IF @b_DeleteSkuTotQty = 1
   BEGIN
      DROP TABLE #TMP_SKUTOTQTY
   END
   --(Wan05) - END

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
          COMMIT TRAN
      END
      SET @b_Success = 1
   END

   IF @n_BatchNo > 0
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      IF @n_Continue IN (1,2) AND                                             --(Wan17)
         @n_BuildWaveDetailLog_From > 0 AND @n_BuildWaveDetailLog_To > 0      --Wan14 - START
      BEGIN
         SET @b_Success = 1
         EXEC WM.lsp_Build_Wave_Post
            @n_BatchNo                 = @n_BatchNo
         ,  @n_BuildWaveDetailLog_From = @n_BuildWaveDetailLog_From
         ,  @n_BuildWaveDetailLog_To   = @n_BuildWaveDetailLog_To
         ,  @b_Success                 = @b_Success  OUTPUT
         ,  @n_err                     = @n_err      OUTPUT
         ,  @c_ErrMsg                  = @c_ErrMsg   OUTPUT
         ,  @b_debug                   = @b_debug
      END                                                                    --Wan14 - END

      IF EXISTS ( SELECT 1
                  FROM BUILDWAVELOG  WITH (NOLOCK)
                  WHERE BatchNo = @n_BatchNo
                )
      BEGIN
         SET @d_EndTime = GETDATE()
         IF @d_StartTime_Load IS NULL SET @d_StartTime_Load = @d_EndTime
         BEGIN TRY
            UPDATE BUILDWAVELOG
            SET --Duration = CONVERT(CHAR(12), @d_EndTime - @d_StartTime, 114)            --(Wan12)
                 Duration = CONVERT(CHAR(12),                                             --(Wan12)
                                   (CONVERT(DATETIME, Duration))                          --(Wan12)
                                 + (@d_EndTime - @d_StartTime_Load), 114)                 --(Wan12)
               , TotalWaveCnt = TotalWaveCnt + @n_WaveCnt                                 --(Wan12)
               , UDF01    = ''
               , [Status] = '9'
               , EditDate = @d_EndTime
               , EditWho  = @c_UserName
               , Trafficcop = NULL
            WHERE BatchNo = @n_BatchNo
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 555515
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': UPDATE BUILDWAVELOG Failed. (lsp_Build_Wave) '
                           + '( ' + @c_ErrMsg + ') '

            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END
         END CATCH
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   REVERT
   IF @b_debug = 2
   BEGIN
      PRINT 'SP-lsp_Build_Wave DEBUG-STOP...'
      PRINT '@b_Success = ' + CAST(@b_Success AS NVARCHAR(2))
      PRINT '@c_ErrMsg = ' + @c_ErrMsg
   END
-- End Procedure

GO