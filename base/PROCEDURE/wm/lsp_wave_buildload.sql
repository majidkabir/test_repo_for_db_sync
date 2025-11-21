SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_Wave_BuildLoad                                  */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: WM - Wave Creation                                          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.8                                                    */                                                                                  
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
/* 2021-02-24  Wan01    1.2   Fixed to call lsp_SetUser SP & Quip SP    */
/*                            if @c_UserName <> SUSER_SNAME()           */
/* 2021-03-23  Wan02    1.3   LWMS-2664 - [CN] Allocation_After_Generate*/
/*                            _Load                                     */
/* 2022-03-08  Wan03    1.4   WMS-19025 - THA-adidas-Create SP for      */
/*                            generate LoadPlan By Wave                 */
/*                            DevOps Combine Script                     */
/* 2023-04-17  Wan04    1.5   LFWM-3978-[CN] LULU_OrderParam_Sort by LOC*/
/* 2023-05-17  Wan05    1.7   LFWM-4244 - PROD-CN SCE Wave BuildGenerate*/
/*                            Load                                      */
/* 2023-05-22  Wan06    1.6   LFWM-4274 - CN UAT Generate Load Info into*/
/*                            BuildLoadLog Table                        */
/* 2023-06-23  Wan07    1.8   LFWM-4176 - CN UAT  Split wave into loads */
/*                            based on customized SP                    */
/* 2023-10-11  Wan08    1.9   LFWM-4490 - CN UAT Add new type to wave   */
/*                            build load                                */
/* 2023-10-12  Wan09    2.0   LFWM-4529 - PROD-CNWAVE Release group     */
/*                            search slow and build wave slow           */
/* 2023-07-19  NJOW01   2.1   WMS-25889 allow grouping/sort fields in   */
/*                            sku table for single sku order            */
/************************************************************************/
CREATE   PROC [WM].[lsp_Wave_BuildLoad]
      @c_Wavekey        NVARCHAR(10)
   ,  @c_Facility       NVARCHAR(5)
   ,  @c_StorerKey      NVARCHAR(15)
   ,  @b_Success        INT            = 1  OUTPUT
   ,  @n_err            INT            = 0  OUTPUT
   ,  @c_ErrMsg         NVARCHAR(255)  = '' OUTPUT
   ,  @c_UserName       NVARCHAR(128)  = ''
   ,  @b_debug          INT            = 0
   ,  @c_WaveBuildLoadParmkey NVARCHAR(10)   = ''                                         --Wan05
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 BIT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT


   DECLARE @d_StartBatchTime           DATETIME       = GETDATE()
         , @d_StartTime                DATETIME       = GETDATE()
         , @d_EndTime                  DATETIME
         , @d_StartTime_Debug          DATETIME       = GETDATE()
         , @d_EndTime_Debug            DATETIME
         , @d_EditDate                 DATETIME

         , @c_BuildKeyFacility         NVARCHAR(5)    = ''
         , @c_BuildKeyStorerkey        NVARCHAR(10)   = ''

         , @n_idx                      INT            = 0
         , @n_MaxLoadOrders            INT            = 0
         , @n_MaxOpenQty               INT            = 0
         , @n_MaxLoad                  INT            = 0

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

         , @c_BuildParmGroup           NVARCHAR(30)   = ''              --(Wan06)

         , @c_BuildParmKey             NVARCHAR(10)   = ''
         , @c_ParmBuildType            NVARCHAR(10)   = ''
         , @c_FieldName                NVARCHAR(100)  = ''

         , @c_Operator                 NVARCHAR(60)   = ''

         , @c_TableName                NVARCHAR(30)   = ''
         , @c_ColName                  NVARCHAR(100)  = ''
         , @c_ColType                  NVARCHAR(128)  = ''
         , @c_BuildTypeValue           NVARCHAR(4000) = ''              --(Wan03)
         , @b_ValidTable               INT            = 0               --(Wan03)
         , @b_ValidColumn              INT            = 0               --(Wan03)

         , @n_cnt                      INT            = 0
         , @n_BuildGroupCnt            INT            = 0

         , @b_GroupFlag                BIT            = 0
         , @b_JoinLoc                  BIT            = 0               --(Wan04)
         , @b_JoinPickdetail           BIT            = 0               --(Wan04)

         , @c_SortBy                   NVARCHAR(2000) = ''
         , @c_SortSeq                  NVARCHAR(10)   = ''
         , @c_GroupBySortField         NVARCHAR(2000) = ''

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

         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_SQLParms                 NVARCHAR(2000) = ''
         , @c_SQLWhere                 NVARCHAR(2000) = ''
         , @c_SQLGroupBy               NVARCHAR(2000) = ''

         , @n_Num                      INT            = 0

         , @n_BatchNo                  INT            = 0                           --(Wan06)

         , @n_OrderCnt                 INT            = 0
         , @n_LoadCnt                  INT            = 0
         , @n_MaxOrders                INT            = 0
         , @n_OpenQty                  INT            = 0
         , @n_TotalOrders              INT            = 0
         , @n_TotalOpenQty             INT            = 0
         , @n_TotalOrderCnt            INT            = 0

         , @n_Weight                   FLOAT          = 0.00
         , @n_Cube                     FLOAT          = 0.00
         , @n_TotalWeight              FLOAT          = 0.00
         , @n_TotalCube                FLOAT          = 0.00

         , @c_BuildLoadKey             NVARCHAR(10)   = ''
         , @c_Loadkey                  NVARCHAR(10)   = ''
         , @c_LoadLineNumber           NVARCHAR(10)   = ''                          --(Wan08)
         , @c_WaveDetailkey            NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = ''
         , @c_OrderLineNumber          NVARCHAR(5)    = ''                          --(Wan08)
         , @c_ExternOrderKey           NVARCHAR(30)   = ''
         , @c_ConsigneeKey             NVARCHAR(15)   = ''
         , @c_C_Company                NVARCHAR(45)   = ''
         , @c_Type                     NVARCHAR(10)   = ''
         , @c_Priority                 NVARCHAR(10)   = ''
         , @c_Door                     NVARCHAR(10)   = ''
         --, @c_Route                    NVARCHAR(10)   = ''
         , @d_OrderDate                DATETIME
         , @d_DeliveryDate             DATETIME
         , @c_DeliveryPlace            NVARCHAR(30)   = ''
         , @n_NoOfOrdLines             INT            = ''
         , @c_Status                   NVARCHAR(10)   = ''

         , @c_UserDefine08             NVARCHAR(10)   = ''
         , @c_Route                    NVARCHAR(10)   = ''
         , @c_SOStatus                 NVARCHAR(10)   = ''

         , @c_Rds                      NVARCHAR(10)   = ''                          --(Wan09)
         , @c_LoadStatus               NVARCHAR(10)   = '0'                         --(Wan09)

         , @n_RNumS                    INT            = 0                           --(Wan09)
         , @n_RNumE                    INT            = 0                           --(Wan09)
         , @n_CustCnt                  INT            = 0                           --(Wan09)
         , @n_LoadPalletCnt            INT            = 0                           --(Wan09)
         , @n_LoadCaseCnt              INT            = 0                           --(Wan09)
         , @n_PalletCnt                INT            = 0                           --(Wan09)
         , @n_CaseCnt                  INT            = 0                           --(Wan09)

         , @c_PICKTRF                  NVARCHAR(1)    = '0'
         , @c_NoMixRoute               NVARCHAR(1)    = '0'
         , @c_NoMixHoldSOStatus        NVARCHAR(1)    = '0'
         , @c_AutoUpdSuperOrderFlag    NVARCHAR(1)    = '0'
         , @c_AutoUpdLoadDfStorerStrg  NVARCHAR(1)    = '0'
         , @c_SuperOrderFlag           NVARCHAR(1)    = 'N'
         , @c_DefaultStrategykey       NVARCHAR(1)    = 'N'

   DECLARE @n_CondLevel                INT            = 1
         , @n_PreCondLevel             INT            = 0
         , @n_CurrCondLevel            INT            = 0
         , @c_OrAnd                    NVARCHAR(10)   = ''
         , @c_Value                    NVARCHAR(4000) = ''
         , @c_SQLCond                  NVARCHAR(MAX)  = ''
         , @c_SQLCond_SP               NVARCHAR(MAX)  = ''
         , @c_SQLJoinPick              NVARCHAR(500)  = ''
         , @c_SQLJoinLoc               NVARCHAR(500)  = ''
         , @c_SQLJoinTempOrd           NVARCHAR(500)  = ''

         , @b_ParmTypeSP               INT            = 0

         , @c_SPName                   NVARCHAR(50)   = ''
         , @c_SPParms                  NVARCHAR(1000) = ''

   DECLARE @CUR_BUILD_COND             CURSOR                                       --(Wan07)
         , @CUR_BUILD_SORT             CURSOR
         , @CUR_BUILD_SP               CURSOR
         , @CUR_BUILDLOAD              CURSOR
         , @CUR_OD                     CURSOR

   SET @b_Success = 1
   SET @n_Err     = 0

      -- SWT02  -- Wan01 Move up
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      SET @n_Err = 0
      EXEC [WM].[lsp_SetUser]
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      --(Wan01)
      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END

   IF @n_Err <> 0
   BEGIN
      GOTO EXIT_SP
   END
   BEGIN TRY -- SWT01 - Begin Outer Begin Try

   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL                              --(Wan07) - START
   BEGIN
      DROP TABLE #TMP_ORDERS
   END

   CREATE TABLE #TMP_ORDERS
   (
      OrderKey       NVARCHAR(10) NULL
   )                                                                                --(Wan07) - END

   CREATE TABLE #tWaveOrder
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
   ,  Rds               NVARCHAR(10)   NULL DEFAULT ('')
   ,  [Status]          NVARCHAR(10)   NULL DEFAULT (0)
   ,  [Weight]          FLOAT          NULL DEFAULT (0.00)
   ,  [Cube]            FLOAT          NULL DEFAULT (0.00)
   ,  NoOfOrdLines      INT            NULL DEFAULT (0)
   ,  AddWho            NVARCHAR(128)  DEFAULT ('')
   )

   IF @b_debug = 2
   BEGIN
      SET @d_StartTime_Debug = GETDATE()
      PRINT 'SP-lsp_Wave_BuildLoad DEBUG-START...'
      PRINT '--1.Do Generate SQL Statement--'
   END

   SET @n_err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1
   SET @c_WaveBuildLoadParmkey = ISNULL(@c_WaveBuildLoadParmkey,'')                 --(Wan05)

   SET @n_Cnt = 0
   SET @c_SQL = N'SELECT TOP 1 '                                                    --(Wan05) - START
              + '  @n_Cnt = 1'
              + ' ,@c_BuildKeyFacility = BPCFG.Facility'
              + ' ,@c_BuildKeyStorerkey= BPCFG.Storerkey'
              + ' ,@c_BuildParmKey = BP.BuildParmKey'
              + ' ,@c_BuildParmGroup = BP.ParmGroup'                                --(Wan06)
              + ' FROM BUILDPARM BP WITH (NOLOCK)'
              + ' JOIN BUILDPARMGROUPCFG BPCFG WITH (NOLOCK) ON BP.ParmGroup = BPCFG.ParmGroup'
              +                                           ' AND BPCFG.[Type] = ''WaveBuildLoad'''
              + ' WHERE BPCFG.Facility = @c_Facility'
              + ' AND   BPCFG.Storerkey= @c_Storerkey'
              + CASE WHEN @c_WaveBuildLoadParmkey = ''  THEN ''
                     ELSE ' AND BP.BuildParmKey = @c_WaveBuildLoadParmkey' END
              + ' ORDER BY BP.BuildParmKey'

   SET @c_SQLParms = N'@n_Cnt                   INT          OUTPUT '
                   + ',@c_BuildKeyFacility      NVARCHAR(5)  OUTPUT '
                   + ',@c_BuildKeyStorerkey     NVARCHAR(15) OUTPUT '
                   + ',@c_BuildParmKey          NVARCHAR(10) OUTPUT '
                   + ',@c_BuildParmGroup        NVARCHAR(30) OUTPUT '               --(Wan06)
                   + ',@c_Facility              NVARCHAR(5)  '
                   + ',@c_Storerkey             NVARCHAR(15) '
                   + ',@c_WaveBuildLoadParmkey  NVARCHAR(10) '

   EXEC sp_ExecuteSQL @c_SQL
                   ,  @c_SQLParms
                   ,  @n_Cnt                    OUTPUT
                   ,  @c_BuildKeyFacility       OUTPUT
                   ,  @c_BuildKeyStorerkey      OUTPUT
                   ,  @c_BuildParmKey           OUTPUT
                   ,  @c_BuildParmGroup         OUTPUT                              --(Wan06)
                   ,  @c_Facility
                   ,  @c_Storerkey
                   ,  @c_WaveBuildLoadParmkey                                       --(Wan05) - END

   IF @n_Cnt = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_Err     = 556001
      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                     + ': BuildParmKey for WaveBuildLoad not found. (lsp_Wave_BuildLoad)'
      GOTO EXIT_SP
   END

   IF @n_Cnt = 1 AND @c_BuildKeyStorerkey <> @c_Storerkey AND
      (@c_BuildKeyFacility <> '' AND (@c_BuildKeyFacility <> @c_Facility))
   BEGIN
      SET @n_Continue = 3
      SET @n_Err     = 556002
      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                     + ': Invalid LoadPlan Group. Its Storer/Facility unmatch with Wave''s storer/Facility'
                     + '. (lsp_Wave_BuildLoad)'
      GOTO EXIT_SP
   END

   ------------------------------------------------------
   -- Get Build Load Restriction:
   ------------------------------------------------------

   SET @c_Operator  = ''
   SET @n_MaxLoadOrders = 0
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

      IF @c_Restriction = '1_MaxOrderPerBuild'
      BEGIN
         SET @n_MaxLoadOrders = @c_RestrictionValue
      END

      IF @c_Restriction = '2_MaxQtyPerBuild'
      BEGIN
         SET @n_MaxOpenQty = @c_RestrictionValue
      END

      IF @c_Restriction = '3_MaxBuild'
      BEGIN
         SET @n_MaxLoad = @c_RestrictionValue
      END

      SET @n_idx = @n_idx + 1
   END

   ------------------------------------------------------
   -- Get Wave Gen Load Condition: General
   ------------------------------------------------------
   SET @CUR_BUILD_COND = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                    --(Wan07) - START
   SELECT BPD.ConditionLevel
         ,BPD.FieldName
         ,BPD.OrAnd
         ,BPD.Operator
         ,BuildValue = BPD.[Value]
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
      IF ISNUMERIC(@n_CondLevel) = 1
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
         SET @n_Err     = 556011
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': Invalid Condition Column Name: ' + @c_FieldName
                        + ' (lsp_Wave_BuildLoad)'
                        + '|' + @c_FieldName
         GOTO EXIT_SP
      END

      IF @c_ColType = 'datetime' AND
         ISDATE(@c_Value) <> 1
      BEGIN
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
            SET @n_Err     = 556012
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Invalid Date Format: ' + @c_Value
                           + ' (lsp_Wave_BuildLoad)'
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

      IF @c_Operator = 'IN SQL'
      BEGIN
         SET @c_Operator = 'IN'
      END

      IF @c_Operator = 'NOT IN SQL'
      BEGIN
         SET @c_Operator = 'NOT IN'
      END

      IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar')
         SET @c_SQLCond = @c_SQLCond + ' ' + @c_FieldName + ' ' + @c_Operator +
               CASE WHEN @c_Operator IN ( 'IN', 'NOT IN') THEN
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
               WHEN @c_Operator IN ( 'IN', 'NOT IN')  THEN
                  CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '(' THEN '(' ELSE '' END +
                  RTRIM(LTRIM(@c_Value)) +
                  CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> ')' THEN ') ' ELSE '' END
               WHEN @c_Operator IN ( 'LIKE', 'NOT LIKE' ) THEN
                  ' N' +
                  CASE WHEN LEFT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN '''' ELSE '' END +
                  RTRIM(LTRIM(@c_Value)) +
                  CASE WHEN RIGHT(RTRIM(LTRIM(@c_Value)),1) <> '''' THEN ''' ' ELSE '' END
               ELSE
                  RTRIM(@c_Value)
               END
      ELSE IF @c_ColType IN ('datetime')
         SET @c_SQLCond = @c_SQLCond + ' ' + @c_FieldName + ' ' + @c_Operator + ' '''+ @c_Value + ''' '

      IF @c_TableName = 'LOC' AND @c_SQLJoinLoc = ''
      BEGIN
         SET @c_SQLJoinPick = 'JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey'
                            + ' AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber'
         SET @c_SQLJoinLoc  = 'JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc'
      END

      IF @c_TableName = 'PICKDETAIL' AND @c_SQLJoinPick = ''
      BEGIN
         SET @c_SQLJoinPick = 'JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey'
                            + ' AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber'
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

   IF @n_MaxOpenQty > 0                                                             --(Wan08) - START
   BEGIN
      SET @c_SQLCond = @c_SQLCond + ' AND ORDERS.OpenQty <= @n_MaxOpenQty'
   END                                                                              --(Wan08) - END

   IF @b_debug = 1
   BEGIN
      PRINT '@c_SQLCond: ' + @c_SQLCond
   END
   ------------------------------------------------------
   -- Get Build Load Custom SP
   ------------------------------------------------------
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

         SET @c_SPParms = ''
         SELECT @c_SPParms = STRING_AGG(CONVERT(NVARCHAR(MAX),p.PARAMETER_NAME + '='
                                         + CASE WHEN p.PARAMETER_NAME='@c_ParmCodeCond' THEN '@c_SQLCond_SP'
                                                WHEN p.PARAMETER_NAME='@c_ParmCode' THEN '@c_BuildParmKey'
                                                WHEN p.PARAMETER_NAME='@n_NoOfOrderToRelease' THEN '@n_MaxLoadOrders'
                                                ELSE p.PARAMETER_NAME END)
                                          , ',' )
         WITHIN GROUP (ORDER BY p.ORDINAL_POSITION ASC)
         FROM [INFORMATION_SCHEMA].[PARAMETERS] AS p
         WHERE p.SPECIFIC_NAME = @c_SPName
         AND p.PARAMETER_NAME NOT IN ('@c_Parm01', '@c_Parm02','@c_Parm03','@c_Parm04','@c_Parm05'
                                     ,'@dt_StartDate', '@dt_EndDate'
                                     )
         AND  CHARINDEX(p.PARAMETER_NAME, @c_SQL,1) = 0                             --2023-09-20
      END

      SET @c_SQL  = RTRIM(@c_SQL)
                  + CASE WHEN CHARINDEX('@',@c_SQL, 1) > 0  THEN ',' ELSE ' ' END
                  + @c_SPParms

      SET @c_SQLCond_SP = @c_SQLCond + ' AND ORDERS.Userdefine09 = ''' + @c_Wavekey + ''''

      SET @c_SQLParms= N'@c_Facility      NVARCHAR(5)'
                     + ',@c_StorerKey     NVARCHAR(15)'
                     + ',@c_BuildParmKey  NVARCHAR(10)'
                     + ',@c_SQLCond_SP    NVARCHAR(MAX)'
                     + ',@n_MaxLoadOrders INT'

      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms
                        ,@c_Facility
                        ,@c_StorerKey
                        ,@c_BuildParmKey
                        ,@c_SQLCond_SP
                        ,@n_MaxLoadOrders

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 556013
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': ERROR Executing Stored Procedure: ' + RTRIM(@c_SPName)
                        + ' (lsp_Wave_BuildLoad)'
                        + '|' + RTRIM(@c_SPName)
         GOTO EXIT_SP
      END
      IF @c_SQLJoinTempOrd = ''
      BEGIN
         SET @c_SQLJoinTempOrd = 'JOIN #TMP_ORDERS TMP ON TMP.Orderkey = ORDERS.Orderkey'
      END
      FETCH NEXT FROM @CUR_BUILD_SP INTO @c_SQL
   END
   CLOSE @CUR_BUILD_SP
   DEALLOCATE @CUR_BUILD_SP                                                         --(Wan07) - END

   --------------------------------------------------
   -- Get Build Load By Sorting & Grouping Condition
   --------------------------------------------------
   SET @n_BuildGroupCnt = 0
   SET @c_GroupBySortField = ''
   SET @c_SQLBuildByGroupWhere = ''
   SET @CUR_BUILD_SORT = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TOP 10
         BPD.FieldName
      ,  BPD.Operator
      ,  BPD.[Type]
      ,  BuildTypeValue = ISNULL(BPD.[Value],'')                        --(Wan03)
   FROM  BUILDPARMDETAIL BPD WITH (NOLOCK)
   WHERE BPD.BuildParmKey = @c_BuildParmKey
   AND   BPD.[Type]  IN ('SORT','GROUP')
   ORDER BY BPD.BuildParmLineNo

   OPEN @CUR_BUILD_SORT

   FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                       ,@c_Operator
                                       ,@c_ParmBuildType
                                       ,@c_BuildTypeValue               --(Wan03)
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get Column Type
      -- (Wan03) - START

      SET @c_BuildTypeValue = dbo.fnc_GetParamValueFromString('@c_CustomFieldName',@c_BuildTypeValue, '')

      IF @c_ParmBuildType = 'GROUP' AND @c_BuildTypeValue <> ''
      BEGIN
         SET @c_TableName = 'ORDERS'
         SET @c_FieldName = @c_BuildTypeValue
         SET @c_ColType = 'nvarchar'

         -- IF @c_BuildTypeValue is a SQL FUNCTION
         SET @c_BuildTypeValue = TRANSLATE(@c_BuildTypeValue, ',', ' ')
         SET @c_BuildTypeValue = TRANSLATE(@c_BuildTypeValue, ')', ' ')
         SET @c_BuildTypeValue = STUFF(@c_BuildTypeValue, 1, CHARINDEX('(',@c_BuildTypeValue),'')

         --1. STC=>Split String by 1 empty space with Split column has '.'; Split_Text
         --2. VC => Split Each Split_Text's Column into Single Character IN a-z, 0-9 and . value. Gen RowID per Split_Text column, n = Character's id reference
         --3. TC => Concat character per Split_Text Column for Gen RowID = n
         --Lastly, Find If Valid Tablename and Column Name
         ;WITH STC AS
         (  SELECT TableName = LEFT(ss.[value], CHARINDEX('.', ss.[value]) -1)
                  ,Split_Text = ss.[value]
            FROM STRING_SPLIT(@c_BuildTypeValue,' ') AS ss
            WHERE CHARINDEX('.',ss.[value]) > 0
         )
         , x AS
         (
              SELECT TOP (100) n = ROW_NUMBER() OVER (ORDER BY Number)
              FROM master.dbo.spt_values ORDER BY Number
         )
         , VC AS
         (
            SELECT Single_Char = SUBSTRING(STC.Split_Text, x.n, 1)
                 , STC.Split_Text
                 , STC.TableName
                 , x.n
                 , RowID = ROW_NUMBER() OVER (PARTITION BY STC.Split_Text ORDER BY STC.Split_Text)
            FROM STC
            JOIN x ON x.n <= LEN(STC.Split_Text)
            WHERE SUBSTRING(STC.Split_Text, x.n, 1) LIKE '[A-Z,0-9,.]'
         )
         , TC AS
         (
            SELECT VC.Split_Text
               , VC.TableName
               , BuildCol = STRING_AGG(VC.Single_Char,'')
            FROM VC WHERE VC.RowiD = VC.n
            GROUP BY VC.Split_Text
                   , VC.TableName
         )
         SELECT @b_ValidTable  = ISNULL(MIN(IIF(TC.TableName = @c_TableName, 1 , 0 )),0)
               ,@b_ValidColumn = ISNULL(MIN(IIF(c.COLUMN_NAME IS NOT NULL , 1 , 0 )),0)
         FROM TC
         LEFT OUTER JOIN INFORMATION_SCHEMA.COLUMNS c WITH (NOLOCK) ON c.TABLE_NAME = TC.TableName AND c.TABLE_NAME + '.' + c.COLUMN_NAME = TC.BuildCol

         IF @b_ValidTable = 0 SET @c_TableName = ''
         IF @b_ValidColumn = 0 SET @c_ColType = ''
      END
      ELSE
      BEGIN
      -- (Wan03) - END
         SET @c_TableName = LEFT(@c_FieldName, CHARINDEX('.', @c_FieldName) - 1)
         SET @c_ColName   = SUBSTRING(@c_FieldName,
                            CHARINDEX('.', @c_FieldName) + 1, LEN(@c_FieldName) - CHARINDEX('.', @c_FieldName))
      END-- (Wan03)

      IF @c_TableName NOT IN ('ORDERS', 'ORDERDETAIL', 'LOC', 'SKU')    --(Wan04) --NJOW01
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 556003
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': Only allow Sort/Group for ORDERS table. (lsp_Wave_BuildLoad)'
         GOTO EXIT_SP
      END

      IF NOT (@c_ParmBuildType = 'GROUP' AND @c_BuildTypeValue <> '')               --(Wan03)
      BEGIN
         SET @c_ColType = ''
         SELECT @c_ColType = DATA_TYPE
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
         WHERE  TABLE_NAME = @c_TableName
         AND    COLUMN_NAME = @c_ColName
      END                                                                           --(Wan03)

      IF ISNULL(RTRIM(@c_ColType), '') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err     = 556004
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': Invalid Sort/Group Column Name: ' + @c_FieldName
                        + '. (lsp_Wave_BuildLoad)'
                        + '|' + @c_FieldName
         GOTO EXIT_SP
      END

      IF @c_ParmBuildType = 'SORT'
      BEGIN
         IF @c_Operator = 'DESC'
            SET @c_SortSeq = 'DESC'
         ELSE
            SET @c_SortSeq = ''

         IF @c_TableName IN ('SKU', 'LOC')                                          --(Wan04) - START
            SET @c_FieldName = 'MIN('+RTRIM(@c_FieldName) + ')'
         ELSE
         BEGIN                                                                      --(Wan04) - END
            IF ISNULL(@c_GroupBySortField,'') = ''
               SET @c_GroupBySortField = CHAR(13) + @c_FieldName
            ELSE
               SET @c_GroupBySortField = @c_GroupBySortField + CHAR(13) + ', ' +  RTRIM(@c_FieldName)
         END                                                                        --(Wan04)

         IF ISNULL(@c_SortBy,'') = ''
            SET @c_SortBy = CHAR(13) + @c_FieldName + ' ' + RTRIM(@c_SortSeq)
         ELSE
            SET @c_SortBy = @c_SortBy + CHAR(13) + ', ' +  RTRIM(@c_FieldName) + ' ' + RTRIM(@c_SortSeq)
      END

      IF @c_ParmBuildType = 'GROUP'
      BEGIN
         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1                      --Fixed counter increase for 'GROUP' only

         IF ISNULL(RTRIM(@c_TableName), '') NOT IN ('ORDERS','SKU','LOC') --NJOW01
         BEGIN
            SET @n_Continue = 3
            SET @n_Err     = 556005
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                          + 'Grouping Only Allow Refer To Orders Table''s Fields. Invalid Table: '+RTRIM(@c_FieldName)
                          + '. (lsp_Wave_BuildLoad)'
                          + '|' + @c_FieldName
            GOTO EXIT_SP
         END

         IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
         BEGIN
            SET @n_Continue = 3
            SET @n_Err     = 556006
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                          + 'Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: ' + RTRIM(@c_FieldName)
                          + '. (lsp_Wave_BuildLoad)'
                          + '|' + @c_FieldName
            GOTO EXIT_SP
         END

         IF @c_ColType IN ('char', 'nvarchar', 'varchar', 'nchar') -- SWT02
         BEGIN
            IF @c_SQLField <> ''
               SET @c_SQLField = @c_SQLField + CHAR(13)
            SET @c_SQLField = @c_SQLField + ',' + RTRIM(@c_FieldName)
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
            IF @c_SQLField <> ''
               SET @c_SQLField = @c_SQLField + CHAR(13)

            SET @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@c_FieldName) + ',112)'
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

      IF @c_TableName = 'LOC' AND @c_SQLJoinLoc = ''                                --(Wan07) - START
      BEGIN
         SET @c_SQLJoinPick = 'JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey'
                            + ' AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber'
         SET @c_SQLJoinLoc  = 'JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc'
      END                                                                           --(Wan07) - END

      FETCH NEXT FROM @CUR_BUILD_SORT INTO @c_FieldName
                                          ,@c_Operator
                                          ,@c_ParmBuildType
                                          ,@c_BuildTypeValue               --(Wan03)
   END
   CLOSE @CUR_BUILD_SORT
   DEALLOCATE @CUR_BUILD_SORT

   DEFAULT_BUILD_BY_CONSIGNEE:
   IF ISNULL(@c_SQLBuildByGroupWhere,'') = '' AND ISNULL(@c_SortBy,'') = ''
   BEGIN
      SET @n_BuildGroupCnt = 2
      SET @c_SQLField = ',ORDERS.Consigneekey'
           + CHAR(13) + ',ORDERS.C_Company'
      SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                       + CHAR(13) + 'AND ORDERS.Consigneekey = @c_Field01'
                       + CHAR(13) + 'AND ORDERS.C_Company = @c_Field02'
   END

   IF ISNULL(@c_SortBy,'') = ''
   BEGIN
      SET @c_SortBy = 'WAVEDETAIL.WaveDetailKey'
   END

   ------------------------------------------------------
   -- Construct Build Load SQL
   ------------------------------------------------------
   SET @c_PICKTRF = '0'
   SELECT TOP 1 @c_PICKTRF = sValue
   FROM  STORERCONFIG AS sc WITH(NOLOCK)
   WHERE sc.StorerKey = @c_StorerKey
   AND   sc.ConfigKey = 'PICK-TRF'
   AND   sc.SValue = '1'

   SET @c_NoMixRoute = '0'
   SELECT TOP 1 @c_NoMixRoute = sValue
   FROM  STORERCONFIG AS sc WITH(NOLOCK)
   WHERE sc.StorerKey = @c_StorerKey
   AND   sc.ConfigKey = 'NoMixRoutingTool_LP'
   AND   sc.SValue = '1'

   SET @c_NoMixHoldSOStatus = '0'
   SELECT TOP 1 @c_NoMixHoldSOStatus = sValue
   FROM  STORERCONFIG AS sc WITH(NOLOCK)
   WHERE sc.StorerKey = @c_StorerKey
   AND   sc.ConfigKey = 'NoMixHoldSOStatus_LP'
   AND   sc.SValue = '1'

   SET @c_SQLBuildByGroupWhere = @c_SQLBuildByGroupWhere
                               + CASE WHEN @c_PICKTRF = '0' THEN ''
                                      ELSE
                                 CHAR(13) + 'AND ((ORDERS.UserDefine08 = ''Y'' AND @c_UserDefine08 = ''Y'') OR @c_UserDefine08 <> ''Y'')'
                                      END
                               + CASE WHEN @c_NoMixRoute = '0' THEN ''
                                      ELSE
                                 CHAR(13) + 'AND ORDERS.Route = @c_Route'
                                      END
                               + CASE WHEN @c_NoMixHoldSOStatus = '0' THEN ''
                                      ELSE
                                 CHAR(13) + 'AND ORDERS.SOStatus = @c_SOStatus'
                                      END

   SET @c_SQL = N'INSERT INTO #tWaveOrder(RNUM,OrderKey,ExternOrderKey,Consigneekey,C_Company,OpenQty'
      + CHAR(13) + ',[Type],[Priority],[Door],[Route]'
      + CHAR(13) + ',OrderDate,DeliveryDate,DeliveryPlace,Rds,Status'
      + CHAR(13) + ',[Weight],[Cube],NoOfOrdLines,AddWho)'
      + CHAR(13) + ' SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@c_SortBy) + ') AS Number'
      + CHAR(13) + ',ORDERS.OrderKey,ORDERS.ExternOrderKey,ORDERS.Consigneekey,ORDERS.C_Company,ORDERS.OpenQty'
      + CHAR(13) + ',ORDERS.[Type],ORDERS.[Priority],ORDERS.[Door],ORDERS.[Route]'
      + CHAR(13) + ',ORDERS.OrderDate,ORDERS.DeliveryDate,ORDERS.DeliveryPlace,ORDERS.Rds,ORDERS.Status'
      + CHAR(13) + ',SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt), SUM(ORDERDETAIL.OpenQty * SKU.StdCube)'
      + CHAR(13) + ',COUNT(DISTINCT ORDERDETAIL.OrderLineNumber)'
      + CHAR(13) + ',''*'' + RTRIM(sUser_sName())'

   SET @c_SQLWhere = N' FROM WAVEDETAIL WITH (NOLOCK) '
      + CHAR(13) + 'JOIN ORDERS WITH (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey'
      + CHAR(13) + 'JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey'
      + CHAR(13) + 'JOIN SKU WITH (NOLOCK) ON ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.SKU = SKU.SKU'
      --(Wan07) - START
      + CHAR(13) + @c_SQLJoinPick
      + CHAR(13) + @c_SQLJoinLoc
      + CHAR(13) + @c_SQLJoinTempOrd
      --+ CHAR(13) + CASE WHEN @b_JoinPickdetail = 0 THEN '' ELSE
      --             'JOIN PICKDETAIL WITH (NOLOCK) ON ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey'
      --+ CHAR(13) +                             ' AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber'
      --             END
      --+ CHAR(13) + CASE WHEN @b_JoinLoc = 0 THEN '' ELSE 'JOIN LOC WITH (NOLOCK) ON PICKDETAIL.Loc = LOC.LOc' END
      --(Wan07) - END
      + CHAR(13) + 'WHERE WAVEDETAIL.Wavekey = @c_Wavekey'
      + CHAR(13) + 'AND ORDERS.StorerKey = @c_StorerKey'
      + CHAR(13) + 'AND ORDERS.Facility = @c_Facility'
      + CHAR(13) + 'AND ORDERS.Status < ''9'''
      + CHAR(13) + 'AND (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'

   SET @c_SQLWhere = @c_SQLWhere + @c_SQLCond                                       --(Wan07)

   SET @c_SQLGroupBy = CHAR(13) + N'GROUP BY'
                     + CHAR(13) +  'WAVEDETAIL.WaveDetailkey'
                     + CHAR(13) + ',ORDERS.OrderKey'
                     + CHAR(13) + ',ORDERS.ExternOrderKey'
                     + CHAR(13) + ',ORDERS.Consigneekey'
                     + CHAR(13) + ',ORDERS.C_Company'
                     + CHAR(13) + ',ORDERS.OpenQty'
                     + CHAR(13) + ',ORDERS.[Type]'
                     + CHAR(13) + ',ORDERS.[Priority]'
                     + CHAR(13) + ',ORDERS.[Door]'
                     + CHAR(13) + ',ORDERS.[Route]'
                     + CHAR(13) + ',ORDERS.OrderDate'
                     + CHAR(13) + ',ORDERS.DeliveryDate'
                     + CHAR(13) + ',ORDERS.DeliveryPlace'
                     + CHAR(13) + ',ORDERS.Rds'
                     + CHAR(13) + ',ORDERS.Status'

   IF @c_GroupBySortField <> ''
   BEGIN
      SET @c_SQLGroupBy= @c_SQLGroupBy+ ', ' + @c_GroupBySortField
   END

   SET @c_SQL = @c_SQL + @c_SQLWhere + @c_SQLBuildByGroupWhere + @c_SQLGroupBy

   IF @b_debug = 1
   BEGIN
      PRINT '@c_SQL: ' + @c_SQL
   END

   --Storerconfig Move up                                                           --(Wan08) - START
   SET @c_AutoUpdSuperOrderFlag = '0'
   SELECT @c_AutoUpdSuperOrderFlag = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoUpdSupOrdflag')
   --IF @c_AutoUpdSuperOrderFlag = '1'
   --BEGIN
   --   SET @c_SuperOrderFlag = 'Y'
   --END

   SET @c_AutoUpdLoadDfStorerStrg = '0'
   SELECT @c_AutoUpdLoadDfStorerStrg = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoUpdLoadDefaultStorerStrg')
   IF @c_AutoUpdLoadDfStorerStrg = '1'
   BEGIN
      SET @c_DefaultStrategykey = 'Y'
   END                                                                              --(Wan08) - END

   IF @c_SQLBuildByGroupWhere <> ''
   BEGIN
      SET @n_MaxLoad = 0

      SET @c_SQLFieldGroupBy = @c_SQLField
                             + CASE WHEN @c_PICKTRF = '0' THEN ''
                                    ELSE CHAR(13) + ',CASE WHEN ORDERS.UserDefine08 = ''Y'' THEN ''Y'' ELSE '''' END'
                                    END
                             + CASE WHEN @c_NoMixRoute = '0' THEN ''
                                    ELSE CHAR(13) + ',ORDERS.Route'
                                    END
                             + CASE WHEN @c_NoMixHoldSOStatus = '0' THEN ''
                                    ELSE CHAR(13) + ',ORDERS.SOStatus'
                                    END

      WHILE @n_BuildGroupCnt < 10
      BEGIN
         SET @c_SQLField = @c_SQLField
                         + CHAR(13) + ','''''

         SET @n_BuildGroupCnt = @n_BuildGroupCnt + 1
      END

      SET @c_SQLField = @c_SQLField
                      + CHAR(13) + CASE WHEN @c_PICKTRF = '0' THEN ','''''
                                        ELSE ',CASE WHEN ORDERS.UserDefine08 = ''Y'' THEN ''Y'' ELSE '''' END'
                                        END
                      + CHAR(13) + CASE WHEN @c_NoMixRoute = '0' THEN ',''''' ELSE ',ORDERS.Route' END
                      + CHAR(13) + CASE WHEN @c_NoMixHoldSOStatus = '0' THEN ',''''' ELSE ',ORDERS.SOStatus' END

      SET @c_SQLBuildByGroup  = N'DECLARE CUR_LOADGRP CURSOR FAST_FORWARD READ_ONLY FOR '
                              + CHAR(13) + ' SELECT @c_Storerkey'
                              + CHAR(13) + @c_SQLField
                              + CHAR(13) + @c_SQLWhere
                              + CHAR(13) + ' GROUP BY ORDERS.Storerkey '
                              + CHAR(13) + @c_SQLFieldGroupBy

      IF @b_debug = 1
      BEGIN
         PRINT '@c_SQLBuildByGroup: ' + @c_SQLBuildByGroup
      END
      EXEC SP_EXECUTESQL @c_SQLBuildByGroup
            , N'@c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)
              , @n_MaxOpenQty INT'                                                  --(Wan08)
            , @c_StorerKey
            , @c_Facility
            , @c_Wavekey
            , @n_MaxOpenQty                                                         --(Wan08)

      OPEN CUR_LOADGRP
      FETCH NEXT FROM CUR_LOADGRP INTO @c_Storerkey
                                    ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05
                                    ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                    ,  @c_UserDefine08, @c_Route, @c_SOStatus
      WHILE @@FETCH_STATUS = 0 AND @n_Continue = 1                                  --(Wan08)
      BEGIN
         GOTO START_BUILDLOAD
         RETURN_BUILDLOAD:

         FETCH NEXT FROM CUR_LOADGRP INTO @c_Storerkey
                                       ,  @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05
                                       ,  @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
                                       ,  @c_UserDefine08, @c_Route, @c_SOStatus
      END
      CLOSE CUR_LOADGRP
      DEALLOCATE CUR_LOADGRP

      GOTO END_BUILDLOAD
   END
START_BUILDLOAD:
   TRUNCATE TABLE #tWaveOrder

   IF @b_debug = 2
   BEGIN
      SET @d_EndTime_Debug = GETDATE()
      PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
      PRINT '--2.Do Execute SQL Statement--'
      SET @d_StartTime_Debug = GETDATE()
   END
   IF @b_debug = 1
   BEGIN
      PRINT 'Build Load @c_SQL: ' + @c_SQL
   END

   SET @c_SQLParms= N'@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60), @c_Field03 NVARCHAR(60), @c_Field04 NVARCHAR(60)'
                  +', @c_Field05 NVARCHAR(60), @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60)'
                  +', @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60), @c_StorerKey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_WaveKey NVARCHAR(10)'
                  +', @c_UserDefine08 NVARCHAR(10), @c_Route NVARCHAR(10), @c_SOStatus NVARCHAR(10)'
                  +', @n_MaxOpenQty INT'                                            --(Wan08)

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
                     ,@c_WaveKey
                     ,@c_UserDefine08
                     ,@c_Route
                     ,@c_SOStatus
                     ,@n_MaxOpenQty                                                 --(Wan08)

   IF @b_debug = 2
   BEGIN
      SET @d_EndTime_Debug = GETDATE()
      PRINT '--Finish Execute SQL Statement--(Check Temp DataStore In [Select View])'
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
      SELECT * FROM #tWaveOrder
      PRINT '--3.Do Initial Value Set Up--'
      SET @d_StartTime_Debug = GETDATE()
   END

   SET @n_MaxOrders =  @n_MaxLoadOrders
   IF @n_MaxLoadOrders = 0
   BEGIN
      SELECT @n_MaxOrders = COUNT(DISTINCT OrderKey)
      FROM   #tWaveOrder
   END

   IF @b_debug = 2
   BEGIN
      SET @d_EndTime_Debug = GETDATE()
      PRINT '--Finish Initial Value Setup--'
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
      PRINT '@n_MaxOrders = ' + CAST(@n_MaxOrders AS NVARCHAR(20))
          + ' ,@n_MaxOpenQty = ' +  CAST(@n_MaxOpenQty AS NVARCHAR(20))
      PRINT '--4.Do Buil Load Plan--'
      SET @d_StartTime_Debug = GETDATE()
   END


   WHILE @@TRANCOUNT > 0
      COMMIT TRAN;

   SET @n_OrderCnt     = 0
   SET @n_TotalOrderCnt= 0
   SET @n_TotalOpenQty = 0
   SET @c_Loadkey      = ''

   IF @n_BatchNo = 0                                                                --(Wan06) - START
   BEGIN
      SET @d_StartTime = GETDATE()
      INSERT INTO BUILDLOADLOG
         (  Facility
         ,  Storerkey
         ,  BuildParmGroup
         ,  BuildParmCode
         ,  BuildParmString
         ,  Duration
         ,  UDF01
         ,  AddWho
         ,  AddDate
         ,  Wavekey
         )
      VALUES
         (  @c_Facility
         ,  @c_StorerKey
         ,  @c_BuildParmGroup
         ,  @c_BuildParmKey
         ,  @c_SQL
         ,  N'00:00:00.000'
         ,  @@SPID
         ,  @c_UserName
         ,  @d_StartTime
         ,  @c_Wavekey
         )

      SET @n_BatchNo = @@IDENTITY
   END                                                                              --(Wan06) - END

   SET @CUR_BUILDLOAD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RNum, OpenQty, OrderKey, [Weight], [Cube], [RDS], [Status]                --(Wan09)
   FROM #tWaveOrder
   ORDER BY RNum

   OPEN @CUR_BUILDLOAD

   WHILE 1 = 1            --@@FETCH_STATUS <> -1                                    --(Wan08) - START
   BEGIN
      FETCH NEXT FROM @CUR_BUILDLOAD INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube
                                          ,@c_rds, @c_Status                        --(Wan09)

      IF @c_Loadkey <> ''
      BEGIN
         IF @b_debug = 1    PRINT @c_Loadkey + ' ' +  CAST (@n_TotalOpenQty AS NVARCHAR(10))

         IF (@n_OrderCnt + 1 > @n_MaxOrders) OR
            (@n_TotalOpenQty + @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0)
         BEGIN
            SET @c_Loadkey = ''
         END

         IF @c_Loadkey = '' OR @@FETCH_STATUS = -1
         BEGIN
            SELECT @n_CustCnt = COUNT(DISTINCT two.C_Company)                       --(Wan09) - START
            FROM #tWaveOrder AS two
            WHERE two.RNum BETWEEN @n_RNumS AND @n_RNumE

            UPDATE LOADPLAN WITH (ROWLOCK)
            SET [Status] = @c_LoadStatus
               ,[Cube]   = @n_TotalCube
               ,[Weight] = @n_TotalWeight
               ,OrderCnt = @n_OrderCnt
               ,CustCnt  = @n_CustCnt
               ,PalletCnt= @n_LoadPalletCnt
               ,CaseCnt  = @n_LoadCaseCnt
               ,SuperOrderFlag = @c_SuperOrderFlag
               ,EditWho = SUSER_SNAME()
               ,EditDate= GETDATE()
               ,Archivecop = NULL
            WHERE Loadkey = @c_BuildLoadKey                                         --(Wan09) - END

            INS_DETLOG:
            IF @n_Continue = 3 AND @@TRANCOUNT > 0 ROLLBACK TRAN

            IF @c_BuildLoadKey <> ''
            BEGIN
               SET @d_EndTime = GETDATE()
               INSERT INTO BUILDLOADDETAILLOG
                  (  Loadkey
                  ,  Storerkey
                  ,  BatchNo
                  ,  TotalOrderCnt
                  ,  TotalOrderQty
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
                     @c_BuildLoadKey
                  ,  @c_Storerkey
                  ,  @n_BatchNo
                  ,  @n_OrderCnt
                  ,  @n_TotalOpenQty
                  ,  ''
                  ,  ''
                  ,  ''
                  ,  ''
                  ,  ''
                  ,  @c_UserName
                  ,  @d_StartTime
                  ,  CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)
                  )
            END
         END
      END

      WHILE @@ROWCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      IF @n_Continue IN (2,3)
      BEGIN
         BREAK
      END

      IF @@FETCH_STATUS = -1
      BEGIN
         BREAK
      END                                                                           --(Wan08) - END

      IF @@TRANCOUNT = 0
         BEGIN TRAN;

      --IF @n_OpenQty > @n_MaxOpenQty AND @n_MaxOpenQty > 0                         --(Wan08) - START
      --BEGIN
      --   IF @n_TotalOpenQty = 0 AND @c_Loadkey = ''
      --   BEGIN
      --      SET @n_Continue = 3
      --      SET @n_Err     = 556007
      --      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
      --                     + ': No Order to Generate. (lsp_Wave_BuildLoad)'
      --      GOTO EXIT_SP
      --   END
      --   BREAK
      --END                                                                         --(Wan08) - END

      IF @c_Loadkey = ''
      BEGIN
         IF @n_MaxLoad > 0 AND @n_MaxLoad >= @n_LoadCnt
         BEGIN
            SET @n_Continue = 2                                                     --(Wan08)
            GOTO INS_DETLOG   --END_BUILDLOAD                                       --(Wan08)
         END

         SET @d_StartTime = GETDATE()
         SET @b_success = 1
         BEGIN TRY
            EXECUTE nspg_GetKey
                  'LoadKey'
                  , 10
                  , @c_Loadkey  OUTPUT
                  , @b_success  OUTPUT
                  , @n_err      OUTPUT
                  , @c_ErrMsg   OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_Err     = 556008
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Error Executing nspg_GetKey - Loadkey. (lsp_Wave_BuildLoad)'
         END CATCH

         IF @b_success <> 1 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO INS_DETLOG   --END_BUILDLOAD                                       --(Wan08)
         END

         BEGIN TRY
            INSERT INTO LoadPlan(LoadKey, Facility, UserDefine04, SuperOrderFlag, DefaultStrategykey)
            VALUES(@c_LoadKey, @c_Facility, @c_BuildParmKey, @c_SuperOrderFlag, @c_DefaultStrategykey)
         END TRY

         BEGIN CATCH
            SET @n_Continue = 3
            SET @c_ErrMsg  = ERROR_MESSAGE()
            SET @n_Err     = 556009
            SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                           + ': Insert Into LOADPLAN Failed. (lsp_Wave_BuildLoad) '
                           + '(' + @c_ErrMsg + ') '

            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN

               WHILE @@TRANCOUNT < @n_StartTCnt
               BEGIN
                  BEGIN TRAN
               END
            END
            GOTO INS_DETLOG   --END_BUILDLOAD                                       --(Wan08)
         END CATCH

         SET @n_RNumS         = @n_Num                                              --(Wan09)
         SET @n_RNumE         = @n_Num                                              --(Wan09)
         SET @n_LoadPalletCnt = 0                                                   --(Wan09)
         SET @n_LoadCaseCnt   = 0                                                   --(Wan09)
         SET @n_OrderCnt      = 0
         SET @n_TotalOpenQty  = 0
         SET @n_TotalWeight   = 0.00
         SET @n_TotalCube     = 0.00
         SET @n_LoadCnt       = @n_LoadCnt + 1
         SET @c_BuildLoadKey  = @c_Loadkey
         SET @c_SuperOrderFlag= 'N'                                                 --(Wan09)
         IF @c_AutoUpdSuperOrderFlag = '1' SET @c_SuperOrderFlag = 'Y'              --(Wan09)
         SET @c_LoadStatus    = '0'                                                 --(Wan09)
      END

      IF @c_Loadkey = ''
      BEGIN
         SET @n_Continue = 2
         GOTO INS_DETLOG   --END_BUILDLOAD                                          --(Wan08)
      END

      IF @@TRANCOUNT = 0            --(Wan02)
         BEGIN TRAN;                --(Wan02)

      --(Wan08) - START
      SET @n_TotalWeight  = @n_TotalWeight + @n_Weight
      SET @n_TotalCube    = @n_TotalCube + @n_Cube

      SET @n_OrderCnt     = @n_OrderCnt + 1
      SET @n_TotalOrderCnt= @n_TotalOrderCnt + 1
      SET @n_TotalOpenQty = @n_TotalOpenQty + @n_OpenQty

      IF @c_Status <= '5'                                                           --(Wan09) - START
      BEGIN
         IF @c_Status IN (3,4) SET @c_Status = '2'
         SET @c_LoadStatus = CASE WHEN @c_LoadStatus = '1' THEN '1'
                                  WHEN @c_LoadStatus = '5' AND @c_Status < '2' THEN '1'
                                  WHEN @c_LoadStatus = '2' AND @c_Status < '2' THEN '1'
                                  WHEN @c_LoadStatus = '2' AND @c_Status > '2' THEN '2'
                                  ELSE @c_Status
                                  END
      END

      IF @c_AutoUpdSuperOrderFlag = '1'
      BEGIN
         IF @c_Rds = 'Y' SET @c_SuperOrderFlag = 'N'
      END

      SET @n_RNumE = @n_Num                                                         --(Wan09) - END

      BEGIN TRY
         SET @c_LoadLineNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_OrderCnt),5)
         INSERT INTO LOADPLANDETAIL
            (LoadKey,            LoadLineNumber
            ,OrderKey,           ConsigneeKey
            ,ExternOrderKey,     CustomerName
            ,[Type],             [Priority]
            ,Door,               [Stop],           [Route]
            ,OrderDate,          DeliveryDate,     DeliveryPlace
            ,[Weight],           [Cube]
            ,NoOfOrdLines,       CaseCnt
            ,[Status],           AddWho
            ,TrafficCop
            )
         SELECT LoadKey       = @c_Loadkey
            ,   Loadplandetail= @c_LoadLineNumber
            ,   Orderkey      = ISNULL(T.OrderKey,'')
            ,   ConsigneeKey  = ISNULL(T.ConsigneeKey,'')
            ,   ExternOrderKey= ISNULL(T.ExternOrderKey,'')
            ,   C_Company     = ISNULL(T.C_Company,'')
            ,   [Type]        = ISNULL(T.[Type],'')
            ,   [Priority]    = ISNULL(T.[Priority],'')
            ,   Door          = ISNULL(T.Door,'')
            ,   [Stop]        = ''
            ,   [Route]       = ISNULL(T.[Route],'')
            ,   OrderDate     = T.OrderDate
            ,   DeliveryDate  = T.DeliveryDate
            ,   DeliveryPlace = ISNULL(T.DeliveryPlace,'')
            ,   [Weight]      = T.[Weight]
            ,   [Cube]        = T.[Cube]
            ,   NoOfOrdLines  = T.NoOfOrdLines
            ,   CaseCnt       = 0
            ,   [Status]      = T.[Status]
            ,   addwho        = '*' + RTRIM(sUser_sName())
            ,   '9'
         FROM #tWaveOrder T
         WHERE T.RNUM = @n_Num

         IF EXISTS (SELECT 1 FROM dbo.ORDERS AS o (NOLOCK) WHERE o.OrderKey = @c_Orderkey
                    AND (Loadkey = '' OR Loadkey IS NULL))
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
               SET Loadkey = @c_Loadkey
                  ,EditWho = SUSER_SNAME()
                  ,EditDate= GETDATE()
                  ,ArchiveCop = NULL                                                --(Wan01)
            WHERE Orderkey = @c_Orderkey
         END

         SET @CUR_OD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT o.OrderLineNumber
               ,PalletCnt = CONVERT(INTEGER, CASE WHEN p.Pallet = 0 THEN 0
                                                  ELSE (o.OpenQty / p.Pallet)
                                                  END)
               ,CaseCnt = CONVERT(INTEGER, CASE WHEN p.CaseCnt = 0 THEN 0
                                                ELSE (o.OpenQty / p.CaseCnt)
                                                END)
         FROM dbo.ORDERDETAIL AS o WITH (NOLOCK)
         JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = o.StorerKey AND s.Sku = o.Sku
         JOIN dbo.PACK AS p (NOLOCK) ON p.PackKey = s.PACKKey
         WHERE o.Orderkey = @c_Orderkey
         AND  o.LoadKey IN ('', NULL)

         OPEN @CUR_OD
         FETCH NEXT FROM @CUR_OD INTO @c_OrderLineNumber, @n_PalletCnt, @n_CaseCnt

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_LoadPalletCnt = @n_LoadPalletCnt + @n_PalletCnt
            SET @n_LoadCaseCnt = @n_LoadCaseCnt + @n_CaseCnt

            UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET Loadkey = @c_Loadkey
                  ,EditWho = SUSER_SNAME()
                  ,EditDate= GETDATE()
                  ,ArchiveCop = NULL
            WHERE Orderkey = @c_Orderkey
            AND OrderLineNumber = @c_OrderLineNumber

            FETCH NEXT FROM @CUR_OD INTO @c_OrderLineNumber, @n_PalletCnt, @n_CaseCnt
         END
         CLOSE @CUR_OD
         DEALLOCATE @CUR_OD

         --EXEC isp_InsertLoadplanDetail
         --      @cLoadKey          = @c_Loadkey
         --   ,  @cFacility         = @c_Facility
         --   ,  @cOrderKey         = @c_OrderKey
         --   ,  @cConsigneeKey     = @c_ConsigneeKey
         --   ,  @cPrioriry         = @c_Priority
         --   ,  @dOrderDate        = @d_OrderDate
         --   ,  @dDelivery_Date    = @d_DeliveryDate
         --   ,  @cOrderType        = @c_Type
         --   ,  @cDoor             = @c_Door
         --   ,  @cRoute            = @c_Route
         --   ,  @cDeliveryPlace    = @c_DeliveryPlace
         --   ,  @nStdGrossWgt      = @n_Weight
         --   ,  @nStdCube          = @n_Cube
         --   ,  @cExternOrderKey   = @c_ExternOrderKey
         --   ,  @cCustomerName     = @c_C_Company
         --   ,  @nTotOrderLines    = @n_NoOfOrdLines
         --   ,  @nNoOfCartons      = 0
         --   ,  @cOrderStatus      = @c_Status
         --   ,  @b_Success         = @b_Success  OUTPUT
         --   ,  @n_Err             = @n_Err      OUTPUT
         --   ,  @c_ErrMsg          = @c_ErrMsg   OUTPUT
         --   ,  @b_WaveBuildLoad   = 1                                               --(Wan10)
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @c_ErrMsg  = ERROR_MESSAGE()
         SET @n_Err     = 556010
         SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                        + ': Update Orders/Orderdetail Fail. (lsp_Wave_BuildLoad) '--(Wan08)
                        + '(' + @c_ErrMsg + ') '

         IF (XACT_STATE()) = -1
         BEGIN
            ROLLBACK TRAN

            WHILE @@TRANCOUNT < @n_StartTCnt
            BEGIN
               BEGIN TRAN
            END
         END
         GOTO INS_DETLOG   --END_BUILDLOAD                                          --(Wan08)
      END CATCH

      --WHILE @@TRANCOUNT > 0                                                       --(Wan06) - START
      --BEGIN
      --   COMMIT TRAN
      --END                                                                         --(Wan06) - END

      --IF (@n_OrderCnt >= @n_MaxOrders) OR                                         --(Wan08) - START
      --   (@n_TotalOpenQty >= @n_MaxOpenQty AND @n_MaxOpenQty > 0)
      --BEGIN
      --   SET @c_Loadkey = ''
      --END                                                                         --(Wan08) - END

      IF @b_debug = 1
      BEGIN
         SELECT @@TRANCOUNT AS [TranCounts]
         SELECT @c_Loadkey 'Loadkey', @n_OpenQty '@n_OpenQty',     @n_TotalOpenQty '@n_TotalOpenQty'
      END

      --(Wan08) - START
      --FETCH NEXT FROM @CUR_BUILDLOAD INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube

      --IF @c_Loadkey = '' OR @@FETCH_STATUS = -1                                   --(Wan06) - START
      --BEGIN
      --   SET @d_EndTime = GETDATE()
      --   INSERT INTO BUILDLOADDETAILLOG
      --      (  Loadkey
      --      ,  Storerkey
      --      ,  BatchNo
      --      ,  TotalOrderCnt
      --      ,  TotalOrderQty
      --      ,  UDF01
      --      ,  UDF02
      --      ,  UDF03
      --      ,  UDF04
      --      ,  UDF05
      --      ,  AddWho
      --      ,  AddDate
      --      ,  Duration
      --      )
      --   VALUES
      --      (
      --         @c_BuildLoadKey
      --      ,  @c_Storerkey
      --      ,  @n_BatchNo
      --      ,  @n_OrderCnt
      --      ,  @n_TotalOpenQty
      --      ,  ''
      --      ,  ''
      --      ,  ''
      --      ,  ''
      --      ,  ''
      --      ,  @c_UserName
      --      ,  @d_StartTime
      --      ,  CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)
      --      )
      --END
      --WHILE @@TRANCOUNT > 0
      --BEGIN
      --   COMMIT TRAN
      --END                                                                         --(Wan06) - END
      --(Wan08) - END

   END -- WHILE 1=1
   CLOSE @CUR_BUILDLOAD
   DEALLOCATE @CUR_BUILDLOAD

   IF @c_SQLBuildByGroup <> ''
   BEGIN
      GOTO RETURN_BUILDLOAD
   END

 END_BUILDLOAD:
   IF @n_BatchNo > 0                                                                --(Wan06) - START
   BEGIN
      ------------------------------------------------------
      -- Get Build Load POST Custom SP
      ------------------------------------------------------
      --(Wan08) - START
      IF @n_Continue IN (1,2)
      BEGIN
         SET @c_SPName = ''

         SELECT TOP 1 @c_SPName = BPD.[Value]
         FROM   BUILDPARMDETAIL BPD WITH (NOLOCK)
         WHERE  BPD.BuildParmKey = @c_BuildParmKey
         AND    BPD.[Type] =  'POSTSPROC'
         ORDER BY BPD.BuildParmLineNo

         IF @c_SPName <> ''
         BEGIN
            SET @n_idx = CHARINDEX(' ',@c_SPName, 1)
            IF @n_idx > 0
            BEGIN
               SET @c_SPName = SUBSTRING(@c_SPName, 1, @n_idx - 1)
            END

            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = OBJECT_ID(@c_SPName) AND TYPE = 'P')
            BEGIN
               SET @c_SQL = 'EXEC ' + @c_SPName
                             + '  @c_Facility= @c_Facility'
                             + ', @c_StorerKey=@c_StorerKey'
                             + ', @c_WaveKey = @c_WaveKey'
                             + ', @n_BatchNo = @n_BatchNo'
                             + ', @c_ParmCode= @c_BuildParmKey'
                             + ', @b_Success = @b_Success   OUTPUT'
                             + ', @n_Err     = @n_Err       OUTPUT'
                             + ', @c_ErrMsg  = @c_ErrMsg    OUTPUT'

               SET @c_SQLParms= N'@c_Facility      NVARCHAR(5)'
                              + ',@c_StorerKey     NVARCHAR(15)'
                              + ',@c_WaveKey       NVARCHAR(10)'
                              + ',@n_BatchNo       INT'
                              + ',@c_BuildParmKey  NVARCHAR(10)'
                              + ',@b_Success       INT            OUTPUT'
                              + ',@n_Err           INT            OUTPUT'
                              + ',@c_ErrMsg        NVARCHAR(255)  OUTPUT'

               EXEC sp_executesql @c_SQL
                                 ,@c_SQLParms
                                 ,@c_Facility
                                 ,@c_StorerKey
                                 ,@c_WaveKey
                                 ,@n_BatchNo
                                 ,@c_BuildParmKey
                                 ,@b_Success OUTPUT
                                 ,@n_Err     OUTPUT
                                 ,@c_ErrMsg  OUTPUT

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err     = 556014
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err)
                                 + ': ERROR Executing POSTSPROC Stored Procedure: ' + RTRIM(@c_SPName)
                                 + ' (lsp_Wave_BuildLoad)'
                                 + '|' + RTRIM(@c_SPName)
                  GOTO EXIT_SP
               END
            END
         END
      END
      --(Wan08) - END
      IF @d_EndTime IS NULL SET @d_EndTime = GETDATE()                              --(Wan08)

      UPDATE BuildLoadLog
      SET  Duration = CONVERT(CHAR(12), @d_EndTime - @d_StartTime, 114)
         , TotalLoadCnt = @n_LoadCnt
         , UDF01    = ''
         , [Status] = '9'
         , EditDate = @d_EndTime
         , EditWho  = @c_UserName
         , Trafficcop = NULL
      WHERE BatchNo = @n_BatchNo
   END                                                                              --(Wan06) - END

   IF @b_debug = 2
   BEGIN
      SET @d_EndTime_Debug = GETDATE()
      PRINT '--Finish Build Load Plan--'
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
      PRINT '--5.Insert Trace Log--'
      SET @d_StartTime_Debug = GETDATE()
   END

   SET @c_ErrMsg = ''
   SET @n_Continue = 0
   IF @b_debug = 2
   BEGIN
      SET @d_EndTime_Debug = GETDATE()
      PRINT '--Finish Insert Trace Log--'
      PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   END

   END TRY

   BEGIN CATCH
      SET @n_Continue = 3                                                           --(Wan06)
      SET @c_ErrMsg = ERROR_MESSAGE()                                               --(Wan06)
      GOTO EXIT_SP
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch
             --
EXIT_SP:
   IF CURSOR_STATUS( 'GLOBAL', 'CUR_LOADGRP') in (0 , 1)                            --(Wan06) - START
   BEGIN
      CLOSE CUR_LOADGRP
      DEALLOCATE CUR_LOADGRP
   END                                                                              --(Wan06) - END

   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL                              --(Wan07) - START
   BEGIN
      DROP TABLE #TMP_ORDERS
   END                                                                              --(Wan07) - END

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      SET @c_ErrMsg = @c_ErrMsg + ' Load #:' + @c_Loadkey

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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   REVERT
   IF @b_debug = 2
   BEGIN
      PRINT 'SP-lsp_Wave_BuildLoad DEBUG-STOP...'
      PRINT '@b_Success = ' + CAST(@b_Success AS NVARCHAR(2))
      PRINT '@c_ErrMsg = ' + @c_ErrMsg
   END
-- End Procedure

GO