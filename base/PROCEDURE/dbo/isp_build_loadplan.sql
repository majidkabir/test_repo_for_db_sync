SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Build_Loadplan                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: Build Loadplan with UserDefine Parameters                   */
/*                                                                      */
/* Called By: PowerBuidler                                              */
/*          : isp_GetEOrder_Analysis                                    */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2014/10/24   Shong     V1.0  Form Select SQL With UDF Parameters     */
/* 2014/11/4    He ZhiJun V1.0  GenerateLoadPlan                        */
/* 2015/04/23   Shong     V1.1  Enhancement                             */
/* 2015/06/10   NJOW01    V1.2  Fix IN operator                         */
/* 2015/08/21   SHONG01   V1.3  Added Date type SOS#349640              */
/* 2016/04/25   NJOW02    V1.4  368531-Add sorting and grouping condition*/
/* 2016/07/22   Wan01     V1.4  SOS#373149 - TH-MFG Auto assign Order to*/
/*                              LoadPlan                       */
/* 2016/09/07   TLTING    V1.5  Performance tune                        */
/* 2016/09/14   TLTING    V1.5  Cursor Update Orders, OD                */
/* 2016/09/28   NJOW03    V1.6  Group by include custom sorting fields  */
/* 2016/11/01   NJOW04    V1.7  Fix AutoUpdSupOrdflag                   */
/* 2016/11/11   NJOW05    V1.8  Fix restriction                         */
/* 2016/11/11   Wan03     V1.8  Fix                                     */
/* 2016/11/23   Wan04     V1.9  Enhancement - Change to Loop - Loadplan */
/*                              insert                                  */
/* 2016/11/23   Wan05     V1.9  Enhancement - Change to traceinfo to    */
/*                              Permenant Table                         */
/* 2017/01/24   NJOW06    V2.0  WMS-881 Add auto add day function to    */
/*                              date value                              */
/* 22-MAR-2017  JayLim   2.1  SQL2012 compatibility modification (Jay01)*/
/* 2017/05/05   TLTING01  V2.0  Tuning - LoadplanDetail insert          */
/* 2017/05/11   Wan06     V2.1  WMS-1719 - ECOM Nov 11 - Order          */
/*                              Management screen                       */
/* 2017/09/12   SWT01     V2.2  Performance Tuning + Enhancement        */
/* 2017/10/11   Wan07     V2.3  Fixed. blocking due to uncommit trans   */
/* 2017/10/19   NJOW07    V2.4  WMS-3225 include orderinfo table        */
/* 2018/02/22   Wan08     V2.5  WMS-3970 - Build load enhancement       */
/* 2018/05/04   Wan09     V2.5  1) Start & End Date SQLCond before call */
/*                              Sub-SP 2) Insert #TMP_ORDER at Sub-SP   */
/* 2018/05/08   NJOW08    V2.6  WMS-4734 - Add no of sku in order filter*/
/* 2018/06/11   Wan10     V2.6  Fixed GROUP If Call From E Analysis     */
/* 2018/06/25   SWT02     V2.6  Added new data type NCHAR               */
/* 2018/07/06   Wan11     V2.6  Fixed IN and LIKE operator for INT type */
/* 2018/07/18   TLTING01  V2.6  remove rowlock                          */
/* 2018/09/26   Wan12     V2.7  Fixed Pass In Start & End Date to SubSP */
/* 2018/09/26   Wan13     V2.7  Fixed Commit Tran no request begin tran */
/* 2019/06/12   SWT03     V2.8  WMS-9417 Control of Max Order Per Load  */
/* 2019/08/13   NJOW09    V2.9  WMS-9551 add @n_NoOfOrderToRelease param*/
/*                              for calling sub-stored proc             */
/* 2019/09/10   WLChooi   V3.0  WMS-10497 Add new conditions NOT LIKE & */
/*                                        NOT IN (WL01)                 */
/* 2020/03/19   NJOW10    V3.1  Fix sort by sku or pickdetail table need*/
/*                              to include min function for the field   */
/* 2022/02/22   SYChua    v3.2  JSM-51723 Extend @cValue parameter from */
/*                              NVARCHAR(250) to NVARCHAR(4000) (SY01)  */
/* 2022/11/10   NJOW11    v3.3  log @n_NoOfOrderToRelease to buildloadlog*/
/*                              UDF02 and fix Max order to release      */
/************************************************************************/
CREATE    PROC [dbo].[isp_Build_Loadplan]
   @cParmCode              NVARCHAR(10),
   @cFacility              NVARCHAR(5),
   @cStorerKey             NVARCHAR(15),
   @nSuccess               INT = 1           OUTPUT,
   @cErrorMsg              NVARCHAR(255)       OUTPUT,
   @bDebug                 INT = 0,          -- 1-RETURN SQLPREVIEW, 2-Debug mode, 3-RETURN Analysis
   @cSQLPreview            NVARCHAR(4000)      OUTPUT,
   @cBatchNo               NVARCHAR(10) = ''   OUTPUT,
   @dt_StartDate           DATETIME = NULL,  --(Wan06)
   @dt_EndDate             DATETIME = NULL,  --(Wan06)
   @c_DateMode             NVARCHAR(10) = '',--(Wan06)
   @n_NoOfOrderToRelease   INT = 0,          --(Wan06)
   @n_RelOrdFlag           INT = 0           --(Wan06)  0: Normal, 2:Allocated Order Status
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @bInValid BIT

DECLARE @cTableName        NVARCHAR(30),
        @cValue            NVARCHAR(4000),  --SY01
        @cColumnName       NVARCHAR(250),
        @cCondLevel        NVARCHAR(10),
        @cColName          NVARCHAR(128),
        @cColType          NVARCHAR(128),
        @n_err             INT,
        @cOrAnd            NVARCHAR(10),
        @cOperator         NVARCHAR(10),
        @nTotalOrders      INT,
        @nTotalOpenQty     INT,
        @nMaxOrders        INT,
        @nMaxOpenQty     INT,
        @nPreCondLevel     INT,
        @nCurrCondLevel    INT,
        @n_HoldOrders      INT,
        @n_Weight          FLOAT,
        @n_Cube            FLOAT,
        @n_Palletcnt       INT,
        @n_Casecnt         INT,
        @n_Custcnt         INT,
        @n_Ordercnt        INT,
        @c_LoadKey         NVARCHAR(10),
        @d_StartTime       DateTime,
        @d_EndTime         DateTime,
        @d_StartTime_Debug DateTime,
        @d_EndTime_Debug   DateTime,
        @d_EditDate        DateTime,
        @n_Num             INT,
        @n_sNum            INT,
        @c_UserName        NVARCHAR(36),
        @c_Authority       NVARCHAR(1),
        @c_SuperOrderFlag  NVARCHAR(1),
        @cSQL              NVARCHAR(Max),
        @b_success         INT
      , @c_ExecSPSQL       NVARCHAR(500)  --(Wan01)
      , @c_ParmCodeCond    NVARCHAR(4000) --(Wan01)
      , @c_SPName          NVARCHAR(50)   --(Wan01)
      , @n_idx             INT            --(Wan01)
      , @b_SPProcess       INT            --(Wan01)
      , @b_ForceSubSPCommit   INT         --(Wan01)

      , @d_StartBatchTime  DATETIME       --(Wan05)
      , @b_GetBatchNo      INT            --(Wan05)
      , @n_LoadplanCnt  INT            --(Wan05)
      , @c_ParmGroup       NVARCHAR(30)   --(Wan05)

      , @b_NewTmpOrders    INT            --(Wan06)
      , @n_TotalOrderCnt   INT            --(Wan06)
      , @c_Status          INT            --(Wan06)

      , @n_BatchNo         BIGINT --(Wan07)
      , @b_JoinPickDetail  BIT            --(Wan08)
      , @b_JoinLoc         BIT            --(Wan08)
      , @n_NoOfSKUInOrder  INT --NJOW08
      , @c_Operator        NVARCHAR(30)   --NJOW08


--NJOW02
DECLARE @cSortBy           NVARCHAR(2000),
        @cSortSeq          NVARCHAR(10),
        @cCondType         NVARCHAR(10),
        @c_SQLField        NVARCHAR(2000),
        @c_SQLWhere        NVARCHAR(2000),
        @c_SQLGroup        NVARCHAR(2000),
        @c_SQLCond         NVARCHAR(4000),
        @c_SQLDYN01        NVARCHAR(Max),
        @n_cnt             int,
        @c_GroupFlag       NVARCHAR(1),
        @c_Storerkey       NVARCHAR(15),
        @c_Field01         NVARCHAR(60),
        @c_Field02         NVARCHAR(60),
        @c_Field03         NVARCHAR(60),
        @c_Field04         NVARCHAR(60),
        @c_Field05         NVARCHAR(60),
        @c_Field06         NVARCHAR(60),
        @c_Field07         NVARCHAR(60),
        @c_Field08         NVARCHAR(60),
        @c_Field09         NVARCHAR(60),
        @c_Field10         NVARCHAR(60),
        @n_StartTranCnt    INT,
        @c_Orderkey         NVARCHAR(10),
        @c_GroupBySortField NVARCHAR(2000) --NJOW03

-- SWT01
DECLARE @cPickTrf               NVARCHAR(1) = '0',
        @cAllowLPWithoutAlloc   NVARCHAR(1) = '0',
        @cOWITF                 NVARCHAR(1) = '0',
        @cSQLWhere              NVARCHAR(Max) = ''

DECLARE @c_AutoUpdLoadDefaultStorerStrg NVARCHAR(10),
        @c_AutoUpdSuperOrderFlag NVARCHAR(10)

DECLARE @n_MaxOrderPerBuild INT = 0 -- SWT03

DECLARE @t_TraceInfo TABLE(
   TraceName NVARCHAR(160),
   TimeIn    DATETIME,
   TimeOut   DATETIME,
   TotalTime NVARCHAR(40),
   Step3     NVARCHAR(40),
   Step4     NVARCHAR(40),
   Step5     NVARCHAR(40),
   Col1      NVARCHAR(40),
   Col2      NVARCHAR(40),
   Col3      NVARCHAR(40),
   Col4      NVARCHAR(40),
   Col5      NVARCHAR(40))

CREATE TABLE #tOrderData
(
   RNUM                INT PRIMARY KEY
   ,OrderKey           NVARCHAR(10)
   ,ExternOrderKey     NVARCHAR(60)
   ,OrderDate          DATETIME
   ,DeliveryDate       DATETIME
   ,Priority           NVARCHAR(20)
   ,ConsigneeKey       NVARCHAR(30)
   ,C_Company          NVARCHAR(90) NULL
   ,OpenQty            INT
   ,STATUS             NVARCHAR(20)
   ,TYPE               NVARCHAR(20)
   ,Door               NVARCHAR(20)
   ,ROUTE              NVARCHAR(20)
   ,DeliveryPlace      NVARCHAR(60) NULL
   ,[WEIGHT]           FLOAT        NULL
   ,[CUBE]             FLOAT        NULL
   ,NoOfOrdLines       INT
   ,AddWho             NVARCHAR(36)
   ,STOP               NVARCHAR(20) DEFAULT ''
)

--(Wan06) - START  -- Create New TMP_ORDERS if not create from the calling SP
SET @b_NewTmpOrders = 0
--(Wan01) - START
IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
BEGIN
   CREATE TABLE #TMP_ORDERS
   (
      OrderKey       NVARCHAR(10)   NULL
   )
   SET @b_NewTmpOrders = 1
END
SET @b_ForceSubSPCommit = 0
--(Wan01) - END
--(Wan06) - END

IF @bDebug = 2
BEGIN
   SET @d_StartTime_Debug = GETDATE()
   PRINT 'SP-isp_Build_Loadplan DEBUG-START...'
   PRINT '--1.Do Generate SQL Statement--'
END

SET @n_err = 0
SET @bInValid = 0
SET @cErrorMsg = ''
SET @nSuccess = 1
SET @nTotalOrders = 0
SET @nTotalOpenQty = 0
SET @nPreCondLevel = 0
SET @nCurrCondLevel = 0
SET @c_LoadKey = ''
SET @nMaxOrders = 0
SET @nMaxOpenQty = 0
SET @n_sNum = 1
SET @d_StartTime = GetDate()
SET @c_UserName = RTRIM(sUser_sName())
SET @n_StartTranCnt = @@TRANCOUNT
SET @d_StartBatchTime = GetDate()         --(Wan05)
SET @b_GetBatchNo  = 1                    --(Wan05)
SET @n_LoadplanCnt = 0                    --(Wan05)

--NJOW02 Start
SELECT @c_SQLField = '', @c_SQLWhere = '', @c_SQLGroup = '', @n_cnt = 0, @c_GroupFlag = 'N', @C_SQLCond = ''

--move up from bottom
SET @c_AutoUpdSuperOrderFlag = ''

SELECT TOP 1 @c_AutoUpdSuperOrderFlag = ISNULL(RTRIM(Svalue),'')
FROM StorerConfig sc WITH (NOLOCK)
WHERE sc.ConfigKey = 'AutoUpdSupOrdflag'
   AND sc.StorerKey = @cStorerKey
   AND sc.Facility = CASE WHEN ISNULL(RTRIM(sc.Facility), '') = '' THEN sc.Facility ELSE @cFacility END
IF @c_AutoUpdSuperOrderFlag = ''
BEGIN
   SELECT TOP 1 @c_AutoUpdSuperOrderFlag = ISNULL(RTRIM(Svalue),'')
   FROM StorerConfig sc WITH (NOLOCK)
   WHERE sc.ConfigKey = 'AutoUpdSupOrdflag'
      AND sc.StorerKey = @cStorerKey
END
IF @c_AutoUpdSuperOrderFlag = '1'
BEGIN
   SET @c_SuperOrderFlag = 'Y'
END

SET @c_AutoUpdLoadDefaultStorerStrg = ''
SELECT TOP 1 @c_AutoUpdLoadDefaultStorerStrg = ISNULL(RTRIM(Svalue),'0')
FROM StorerConfig sc WITH (NOLOCK)
WHERE sc.ConfigKey = 'AutoUpdLoadDefaultStorerStrg'
   AND sc.StorerKey = @cStorerKey
   AND sc.Facility = CASE WHEN ISNULL(RTRIM(sc.Facility), '') = '' THEN sc.Facility ELSE @cFacility END

--(Wan05) - START
--(Wan08) - START
SET @b_JoinPickDetail = 0
SET @b_JoinLoc = 0
--(Wan08) - END
SET @c_ParmGroup = ''
SELECT @c_ParmGroup = ISNULL(RTRIM(ListGroup),'')
FROM CODELIST WITH (NOLOCK)
WHERE ListName = @cParmCode
--(Wan05) - END

--NJOW08
SELECT TOP 1 @n_NoOfSKUInOrder= CASE WHEN ISNUMERIC(Notes) = 1 THEN CAST(Notes AS INT) ELSE 0 END,
             @c_Operator = UDF03
FROM Codelkup WITH (NOLOCK)
WHERE LISTNAME = @cParmCode
AND long = 'No_Of_SKU_In_Order'

DECLARE CUR_BUILD_LOAD_SORT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT TOP 10 Long, UDF03, Short
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cParmCode
AND    Short IN('SORT','GROUP')
ORDER BY Code

OPEN CUR_BUILD_LOAD_SORT

FETCH NEXT FROM CUR_BUILD_LOAD_SORT INTO @cColumnName, @cOperator, @cCondType

WHILE @@FETCH_STATUS <> -1
BEGIN
   -- Get Column Type
   SET @cTableName = LEFT(@cColumnName, CharIndex('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName,
             CharIndex('.', @cColumnName) + 1, LEN(@cColumnName) - CharIndex('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE
   FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = ''
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName
      GOTO QUIT
   END

   IF @cCondType = 'SORT'
   BEGIN
      IF @cOperator = 'DESC'
         SET @cSortSeq = 'DESC'
      ELSE
         SET @cSortSeq = ''

      IF @cTableName IN('ORDERDETAIL','LOC','PICKDETAIL') --NJOW10
         SET @cColumnName = 'MIN('+RTRIM(@cColumnName) + ')'
      ELSE
         IF ISNULL(@c_GroupBySortField,'') = ''  --NJOW03
            SET @c_GroupBySortField = @cColumnName
         ELSE
            SET @c_GroupBySortField = @c_GroupBySortField  + ', ' +  RTRIM(@cColumnName)

      IF ISNULL(@cSortBy,'') = ''
         SET @cSortBy = @cColumnName + ' ' + RTRIM(@cSortSeq)
      ELSE
         SET @cSortBy = @cSortBy + ', ' +  RTRIM(@cColumnName) + ' ' + RTRIM(@cSortSeq)
   END

   IF @cCondType = 'GROUP'
   BEGIN
      SET @n_cnt = @n_cnt + 1                      --(Wan10) Fixed counter increase for 'GROUP' only
      IF ISNULL(RTRIM(@cTableName), '') NOT IN('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC') --NJOW07--(Wan08)
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'Grouping Only Allow Refer To Orders/Orderinfo Table''s Fields. Invalid Table: '+RTRIM(@cColumnName)
         GOTO QUIT
      END

      IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint','text')
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'Numeric/Text Column Type Is Not Allowed For Load Plan Grouping: ' + RTRIM(@cColumnName)
         GOTO QUIT
      END

      IF @cColType IN ('char', 'nvarchar', 'varchar', 'nchar') -- SWT02
      BEGIN
         SELECT @c_SQLField = @c_SQLField + ',' + RTRIM(@cColumnName)
         SELECT @c_SQLWhere = @c_SQLWhere + ' AND ' + RTRIM(@cColumnName) + '=' +
                CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                     WHEN @n_cnt = 2 THEN '@c_Field02'
                     WHEN @n_cnt = 3 THEN '@c_Field03'
                     WHEN @n_cnt = 4 THEN '@c_Field04'
                     WHEN @n_cnt = 5 THEN '@c_Field05'
                     WHEN @n_cnt = 6 THEN '@c_Field06'
                     WHEN @n_cnt = 7 THEN '@c_Field07'
                     WHEN @n_cnt = 8 THEN '@c_Field08'
                     WHEN @n_cnt = 9 THEN '@c_Field09'
                     WHEN @n_cnt = 10 THEN '@c_Field10' END
         SET @c_GroupFlag = 'Y'
      END

      IF @cColType IN ('datetime')
      BEGIN
         SELECT @c_SQLField = @c_SQLField + ', CONVERT(NVARCHAR(10),' + RTRIM(@cColumnName) + ',112)'
         SELECT @c_SQLWhere = @c_SQLWhere + ' AND CONVERT(NVARCHAR(10),' + RTRIM(@cColumnName) + ',112)=' +
                CASE WHEN @n_cnt = 1 THEN '@c_Field01'
                     WHEN @n_cnt = 2 THEN '@c_Field02'
                     WHEN @n_cnt = 3 THEN '@c_Field03'
                     WHEN @n_cnt = 4 THEN '@c_Field04'
                     WHEN @n_cnt = 5 THEN '@c_Field05'
                     WHEN @n_cnt = 6 THEN '@c_Field06'
                     WHEN @n_cnt = 7 THEN '@c_Field07'
                     WHEN @n_cnt = 8 THEN '@c_Field08'
                     WHEN @n_cnt = 9 THEN '@c_Field09'
                     WHEN @n_cnt = 10 THEN '@c_Field10' END
         SET @c_GroupFlag = 'Y'
      END
   END
   --(Wan08) - START
   IF @cTableName = 'LOC'
   BEGIN
      SET @b_JoinPickDetail = 1
      SET @b_JoinLoc = 1
   END

   IF @cTableName = 'PICKDETAIL'
   BEGIN
      SET @b_JoinPickDetail = 1
   END
   --(Wan08) - END
   FETCH NEXT FROM CUR_BUILD_LOAD_SORT INTO @cColumnName, @cOperator, @cCondType
END
CLOSE CUR_BUILD_LOAD_SORT
DEALLOCATE CUR_BUILD_LOAD_SORT


DECLARE CUR_BUILD_LOAD_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT Long, ISNULL(Notes,''), UDF01, UDF02, UDF03
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cParmCode
AND    Short    = 'CONDITION'
ORDER BY Code

OPEN CUR_BUILD_LOAD_COND

FETCH NEXT FROM CUR_BUILD_LOAD_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF ISNUMERIC(@cCondLevel) = 1
   BEGIN
      IF @nPreCondLevel=0
         SET @nPreCondLevel = CAST(@cCondLevel AS INT)
      SET @nCurrCondLevel = CAST(@cCondLevel AS INT)
   END

   -- Get Column Type
   SET @cTableName = LEFT(@cColumnName, CharIndex('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName,
             CharIndex('.', @cColumnName) + 1, LEN(@cColumnName) - CharIndex('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE
   FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = ''
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName
      GOTO QUIT
   END

   IF @cColType = 'datetime' AND
      ISDATE(@cValue) <> 1
   BEGIN
      -- SHONG01
      IF @cValue IN ('today','now', 'startofmonth', 'endofmonth', 'startofyear', 'endofyear')
         OR LEFT(@cValue,6) IN ('today+', 'today-') --NJOW06
      BEGIN
         SET @cValue = CASE
                        WHEN @cValue = 'today'
                              THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                        WHEN LEFT(@cValue,6) IN ('today+', 'today-') AND ISNUMERIC(SUBSTRING(@cValue,7,10)) = 1 --NJOW06
                           THEN LEFT(CONVERT(VARCHAR(30), DATEADD(DAY, CONVERT(INT,SUBSTRING(@cValue,6,10)),GETDATE()), 120), 10)
                        WHEN @cValue = 'now'
                           THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                        WHEN @cValue = 'startofmonth'
                           THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-'
                              + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) + ('-01')
                        WHEN @cValue = 'endofmonth'
                           THEN CONVERT(VARCHAR(30), DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)), 120)
                        WHEN @cValue = 'startofyear'
                           THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-01-01'
                        WHEN @cValue = 'endofyear'
                           THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-12-31 23:59:59'
                        ELSE LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10) --NJOW06
                       END
      END
      ELSE
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'Invalid Date Format: ' + @cValue
         GOTO QUIT
      END
   END

   IF @nPreCondLevel < @nCurrCondLevel
   BEGIN
      SET @c_SQLCond = @c_SQLCond + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd + N' ('
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE IF @nPreCondLevel > @nCurrCondLevel
   BEGIN
      SET @c_SQLCond = @c_SQLCond + N') '  + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE
   BEGIN
      SET @c_SQLCond = @c_SQLCond + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd
   END

   IF @cColType IN ('char', 'nvarchar', 'varchar', 'nchar') --SWT02
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator +
            CASE WHEN @cOperator = 'IN' OR @cOperator = 'NOT IN' THEN   --NJOW01      --WL01
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '(' THEN '(' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> ')' THEN ') ' ELSE '' END
            ELSE ' N' +
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN '''' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN ''' ' ELSE '' END
            END
   ELSE IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 'real', 'bigint')
      --(Wan11) - START
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator  +
            CASE WHEN @cOperator = 'IN' OR @cOperator = 'NOT IN' THEN     --WL01
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '(' THEN '(' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> ')' THEN ') ' ELSE '' END
            WHEN @cOperator = 'LIKE' OR @cOperator = 'NOT LIKE' THEN      --WL01
               ' N' +
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN '''' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN ''' ' ELSE '' END
            ELSE
               RTRIM(@cValue)
            END
      --(Wan11) - END
   ELSE IF @cColType IN ('datetime')
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator + ' '''+ @cValue + ''' '

   --(Wan08) - START
   IF @cTableName = 'LOC'
   BEGIN
      SET @b_JoinPickDetail = 1
      SET @b_JoinLoc = 1
   END

   IF @cTableName = 'PICKDETAIL'
   BEGIN
      SET @b_JoinPickDetail = 1
   END
   --(Wan08) - END
   FETCH NEXT FROM CUR_BUILD_LOAD_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator
END
CLOSE CUR_BUILD_LOAD_COND
DEALLOCATE CUR_BUILD_LOAD_COND

WHILE @nPreCondLevel > 1
BEGIN
   SET @c_SQLCond = @c_SQLCond + N') '
   SET @nPreCondLevel = @nPreCondLevel - 1
END

--(Wan09) - START
IF @dt_StartDate IS NOT NULL AND @dt_EndDate IS NOT NULL
BEGIN
   SET @c_SQLCond = @c_SQLCond
                  + ' AND'
                  + CASE WHEN @c_DateMode = 1 THEN ' ORDERS.AddDate' ELSE ' ORDERS.OrderDate' END
                  + ' BETWEEN @dt_StartDate AND @dt_EndDate'
END
--(Wan09) - END

--(Wan01) - START
SET @b_SPProcess = 0
DECLARE CUR_BUILD_LOAD_SP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT ISNULL(Notes,'')
FROM   CODELKUP WITH (NOLOCK)
WHERE  ListName = @cParmCode
AND    Short =  'STOREDPROC'
ORDER BY Code

OPEN CUR_BUILD_LOAD_SP

FETCH NEXT FROM CUR_BUILD_LOAD_SP INTO @c_ExecSPSQL

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF @c_ExecSPSQL <> ''
   BEGIN
      SET @c_SPName = @c_ExecSPSQL
      SET @n_idx = CHARINDEX(' ',@c_ExecSPSQL, 1)
      IF @n_idx > 0
      BEGIN
         SET @c_SPName = SUBSTRING(@c_ExecSPSQL,1, @n_idx - 1)
      END

      SET @c_ExecSPSQL = RTRIM(@c_ExecSPSQL)
                            + CASE WHEN CHARINDEX('@',@c_ExecSPSQL, 1) > 0  THEN ',' ELSE '' END
                            + ' @c_Facility = @cFacility'                                                               --(Wan06)
                            + ',@c_Storerkey= @cStorerKey'                                                              --(Wan06)
                            + ',@c_ParmCode = @cParmCode'                                                               --(Wan06)
                            + ',@c_ParmCodeCond = @c_SQLCond'                                                           --(Wan06)
                            + ',@dt_StartDate = @dt_StartDate'                                                          --(Wan12)
                            + ',@dt_EndDate = @dt_EndDate'
                            + ',@n_NoOfOrderToRelease = @nNoOfOrderToRelease'                                           --NJOW09

      EXEC sp_executesql @c_ExecSPSQL                                                                                   --(Wan06)
         , N'@cFacility NVARCHAR(5), @cStorerKey NVARCHAR(15), @cParmCode NVARCHAR(10), @c_SQLCond NVARCHAR(4000)
            ,@dt_StartDate DATETIME, @dt_EndDate DATETIME, @nNoOfOrderToRelease INT'                                    --(Wan12)
         ,@cFacility                                                                                                    --(Wan06)
         ,@cStorerKey                                                                                                   --(Wan06)
         ,@cParmCode                                                                                                    --(Wan06)
         ,@c_SQLCond                                                                                                    --(Wan06)

         ,@dt_StartDate                                                                                                 --(Wan12)
         ,@dt_EndDate                                                                                                   --(Wan12)
         ,@n_NoOfOrderToRelease                                                                                         --NJOW09

      IF @@ERROR <> 0
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'ERROR Executing Stored Procedure: ' + RTRIM(@c_SPName)
                        + '. (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
         GOTO QUIT
      END
      SET @b_SPProcess = 1

   END
   FETCH NEXT FROM CUR_BUILD_LOAD_SP INTO @c_ExecSPSQL
END
CLOSE CUR_BUILD_LOAD_SP
DEALLOCATE CUR_BUILD_LOAD_SP

IF @b_SPProcess = 1
BEGIN
   IF NOT EXISTS (SELECT 1
                  FROM #TMP_ORDERS
                  )
   BEGIN
      SET @b_ForceSubSPCommit = 1
   END

   SET @c_SQLCond = @c_SQLCond
                  + ' AND EXISTS (SELECT 1 FROM #TMP_ORDERS TMP WHERE TMP.Orderkey = ORDERS.Orderkey)'
END
--(Wan01) - END

SET @cOWITF = '0'
SELECT TOP 1 @cOWITF = sValue
FROM  StorerConfig AS sc WITH(NOLOCK)
WHERE sc.StorerKey = @cStorerKey
AND   sc.ConfigKey = 'OWITF'
AND   sc.SValue = '1'

SET @cPickTrf = '0'
SELECT TOP 1 @cPickTrf = sValue
FROM  StorerConfig AS sc WITH(NOLOCK)
WHERE sc.StorerKey = @cStorerKey
AND   sc.ConfigKey = 'PICK-TRF'
AND   sc.SValue = '1'

SET @cAllowLPWithoutAlloc = '0'     SELECT TOP 1 @cAllowLPWithoutAlloc = sValue
FROM  StorerConfig AS sc WITH(NOLOCK)
WHERE sc.StorerKey = @cStorerKey
AND   sc.ConfigKey = 'AllowLPWithoutAlloc'
AND   sc.SValue = '1'

SELECT @cSQLWhere = N' FROM ORDERS WITH (NOLOCK) ' + CHAR(13)



      + ' LEFT OUTER JOIN OrderDetail (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey ' + CHAR(13)
      + ' LEFT OUTER JOIN SKU (NOLOCK) ON (ORDERDETAIL.SKU = SKU.SKU AND ORDERS.StorerKey = SKU.StorerKey) ' + CHAR(13) --(Wan08)
      + ' LEFT OUTER JOIN LoadPlanDetail LD (NOLOCK) ON LD.OrderKey = ORDERS.OrderKey ' + CHAR(13)
      + ' LEFT OUTER JOIN ORDERINFO (NOLOCK) ON ORDERS.OrderKey = ORDERINFO.OrderKey ' + CHAR(13)  --NJOW07
      --(Wan08) - START
      + CASE WHEN @b_JoinPickDetail = 1 OR @b_JoinLoc = 1
             THEN 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey=PICKDETAIL.Orderkey) AND (ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber)' + CHAR(13)
             ELSE ''
             END
      + CASE WHEN @b_JoinLoc = 1
             THEN 'LEFT JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc=LOC.Loc AND LOC.Facility = @cFacility)'  + CHAR(13)
             ELSE ''
             END
      --(Wan08) - END
      + ' WHERE ORDERS.StorerKey = @cStorerKey ' + CHAR(13)
      + ' AND ORDERS.Facility =  @cFacility' + CHAR(13)
      + ' AND ORDERS.Status < ''9'' ' + CHAR(13)
      +   CASE WHEN @bDebug = 3 THEN ''
               ELSE
                  ' AND LD.LoadKey IS NULL ' + CHAR(13)
      +           ' AND (ORDERS.LoadKey = '''' OR ORDERS.LoadKey IS NULL) '  END + CHAR(13)
      + ' AND ((ORDERS.UserDefine08 = ''N'' AND ( ORDERS.UserDefine09 = '''' OR ORDERS.UserDefine09 is NULL) AND (ORDERS.Status < ''8'') ) OR ' + CHAR(13)
      + '      (ORDERS.UserDefine08 = ''Y'' AND ORDERS.UserDefine09 <> '''' AND (ORDERS.Status >= ''1'' AND ORDERS.Status < ''8'' ) )  ' + CHAR(13)
      + CASE WHEN @cAllowLPWithoutAlloc <> '1' THEN '' ELSE ' OR (ORDERS.UserDefine08 = ''Y'' AND ORDERS.Status < ''8'' ) ' END
      + ') ' + CHAR(13)
      + CASE WHEN @cOWITF = '1' AND @cPickTrf = '1' THEN ' AND ORDERS.UserDefine08 = ''Y'' ' ELSE '' END
      + CASE WHEN @cOWITF = '1' AND @cPickTrf <> '1' THEN ' AND ORDERS.UserDefine08 = ''N'' ' ELSE '' END



      + ' AND ORDERS.SOStatus <> ''PENDING'' '  + CHAR(13)
      + ' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) '
      + ' WHERE CODELKUP.Code = ORDERS.SOStatus '
      + ' AND CODELKUP.Listname = ''LBEXCSOSTS'' '
      + ' AND CODELKUP.Storerkey = ORDERS.Storerkey) ' + CHAR(13)
      + CASE WHEN @cOWITF = '0' THEN ''
               ELSE ' AND (ORDERS.UserDefine08 = ''Y'' ' +
                  ' AND NOT EXISTS(SELECT 1 FROM Transmitlog (NOLOCK) WHERE ORDERS.OrderKey = TRANSMITLOG.Key1 ' +
                  ' AND TableName IN (''OWORDALLOC'', ''OWDPREPICK''))) '
         END
      + CASE WHEN @n_RelOrdFlag = 2 THEN ' AND ORDERS.Status = ''2'''            --(Wan06)
             ELSE '' END + CHAR(13)                                            --(Wan06)
      + RTRIM(@c_SQLCond)

IF ISNULL(@cSortBy,'') = ''
   SET @cSortBy = 'ORDERS.[OrderKey]'

 SET @n_TotalOrderCnt = 0   --(Wan06)  --NJOW11 move up
 
IF ISNULL(@c_GroupFlag,'') = 'Y' AND  @bDebug <> 3                               -- (Wan10)
BEGIN
   SELECT @c_SQLGroup = @c_SQLField
   WHILE @n_cnt < 10
   BEGIN
      SET @n_cnt = @n_cnt + 1
       SELECT @c_SQLField = @c_SQLField + ','''''

      SELECT @c_SQLWhere = @c_SQLWhere + ' AND ''''=' +
             CASE WHEN @n_cnt = 1  THEN 'ISNULL(@c_Field01,'''')'
                  WHEN @n_cnt = 2  THEN 'ISNULL(@c_Field02,'''')'
                  WHEN @n_cnt = 3  THEN 'ISNULL(@c_Field03,'''')'
                  WHEN @n_cnt = 4  THEN 'ISNULL(@c_Field04,'''')'
                  WHEN @n_cnt = 5  THEN 'ISNULL(@c_Field05,'''')'
                  WHEN @n_cnt = 6  THEN 'ISNULL(@c_Field06,'''')'
                  WHEN @n_cnt = 7  THEN 'ISNULL(@c_Field07,'''')'
                  WHEN @n_cnt = 8  THEN 'ISNULL(@c_Field08,'''')'
                  WHEN @n_cnt = 9  THEN 'ISNULL(@c_Field09,'''')'
                  WHEN @n_cnt = 10 THEN 'ISNULL(@c_Field10,'''')' END
   END

   SELECT @c_SQLDYN01 = 'DECLARE cur_LPGroup CURSOR FAST_FORWARD READ_ONLY FOR '
         + ' SELECT ORDERS.Storerkey ' + @c_SQLField
         + @cSQLWhere
         + ' GROUP BY ORDERS.Storerkey ' + @c_SQLGroup
         + ' ORDER BY ORDERS.Storerkey ' + @c_SQLGroup

   EXEC sp_executesql @c_SQLDYN01
         , N'@cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @dt_StartDate DATETIME, @dt_EndDate DATETIME'      --(Wan06)
         ,@cStorerKey                                                                                             --(Wan06)
         ,@cFacility                                                                                              --(Wan06)
         ,@dt_StartDate                                                                                           --(Wan06)
         ,@dt_EndDate                                                                                            --(Wan06)

   OPEN cur_LPGroup
   FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                                    @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
   WHILE @@FETCH_STATUS = 0
   BEGIN
      GOTO START_BUILDLOAD
      RETURN_BUILDLOAD:

      FETCH NEXT FROM cur_LPGroup INTO @c_Storerkey, @c_Field01, @c_Field02, @c_Field03, @c_Field04, @c_Field05,
                      @c_Field06, @c_Field07, @c_Field08, @c_Field09, @c_Field10
   END
   CLOSE cur_LPGroup
   DEALLOCATE cur_LPGroup

   GOTO END_BUILDLOAD
END

START_BUILDLOAD:
DELETE FROM #tOrderData
SET @nPreCondLevel = 0
SET @nCurrCondLevel = 0
SET @nMaxOrders = 0
SET @nMaxOpenQty = 0
SET @n_sNum = 1
--NJOW02 End

SET @cSQL = CASE WHEN @bDebug  = 1 THEN N''
                 WHEN @bDebug  = 3 THEN         --(Wan06)
   N'INSERT INTO #TMP_EORDER_BUILDLOAD(OrderKey, Loadkey, OpenQty, Status) '
                 ELSE
   N'INSERT INTO #tOrderData(RNUM, OrderKey, ExternOrderKey, OrderDate, DeliveryDate, Priority,
     ConsigneeKey, C_Company, OpenQty, Status, Type, Door, Route, DeliveryPlace,
     [Weight], [Cube], NoOfOrdLines, AddWho) '
                  END + CHAR(13) +
            CASE WHEN @bDebug  = 3 THEN         --(Wan06)
   N'SELECT DISTINCT ORDERS.OrderKey, ORDERS.Loadkey,ORDERS.OpenQty,ORDERS.Status'
                 ELSE
   N'SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@cSortBy) + ') AS Number,ORDERS.OrderKey,
   ORDERS.ExternOrderKey,ORDERS.OrderDate,ORDERS.DeliveryDate,ORDERS.Priority,ORDERS.ConsigneeKey,
   ORDERS.C_Company,ORDERS.OpenQty,ORDERS.Status,ORDERS.Type,ORDERS.Door,ORDERS.Route,ORDERS.DeliveryPlace,
   SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt), SUM(ORDERDETAIL.OpenQty * SKU.StdCube),
   COUNT(DISTINCT ORDERDETAIL.OrderLineNumber),''*'' + RTRIM(sUser_sName()) '
                 END + CHAR(13)
         + @cSQLWhere

--NJOW02

--(Wan06) - START
IF @bDebug = 3
BEGIN
   SET @cSQL = RTRIM(@cSQL) + CHAR(13)
               + N' GROUP BY ORDERS.OrderKey'
               + ' ,ORDERS.Loadkey'
               + ' ,ORDERS.OpenQty'
               + ' ,ORDERS.Status'
END
ELSE
BEGIN
   IF ISNULL(@c_GroupFlag,'') = 'Y'
      SET @cSQL = RTRIM(@cSQL) + ' ' + CHAR(13) + @c_SQLWhere

   SET @cSQL = RTRIM(@cSQL) + CHAR(13) + N' GROUP BY
               ORDERS.OrderKey,
               ORDERS.ConsigneeKey,
               ORDERS.Priority,
               ORDERS.OrderDate,
               ORDERS.DeliveryDate,
               ORDERS.[TYPE],
               ORDERS.Door,
               ORDERS.ROUTE,
               ORDERS.DeliveryPlace,
               ORDERS.ExternOrderKey,
               ORDERS.C_Company,
               ORDERS.[STATUS],
               ORDERS.OpenQty'

   IF ISNULL(@c_GroupBySortField,'') <> '' --NJOW03
      SET @cSQL = RTRIM(@cSQL) + ',' + CHAR(13) + RTRIM(@c_GroupBySortField)
END
--(Wan06) - END

--NJOW08
IF ISNULL(@n_NoOfSKUInOrder,0) > 0
BEGIN
 IF ISNULL(@c_Operator,'') = ''
    SET @c_Operator = '='

 SET @cSQL = RTRIM(@cSQL) + ' ' + CHAR(13) + ' HAVING COUNT(DISTINCT ORDERDETAIL.SKU) ' + RTRIM(@c_Operator) + ' ' + CAST(@n_NoOfSKUInOrder AS NVARCHAR)
END

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   SELECT @cSQL
   PRINT '--2.Do Execute SQL Statement--'
   SET @d_StartTime_Debug = GETDATE()
END

SET @cSQLPreview = @cSQL
--BEGIN
IF @bDebug <> 1
BEGIN
   --(Wan10) - START
   IF @bDebug = 3
   BEGIN
      EXEC sp_executesql @cSQL,
         N'@cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @dt_StartDate DATETIME, @dt_EndDate DATETIME',
         @cStorerKey,
         @cFacility,
         @dt_StartDate,
         @dt_EndDate

      GOTO QUIT
   END
   --(Wan10) - END

   IF ISNULL(@c_GroupFlag,'') = 'Y'  --NJOW02
   BEGIN
   EXEC sp_executesql @cSQL,
         N'@c_Field01 NVARCHAR(60), @c_Field02 NVARCHAR(60),@c_Field03 NVARCHAR(60),@c_Field04 NVARCHAR(60), @c_Field05 NVARCHAR(60),
            @c_Field06 NVARCHAR(60), @c_Field07 NVARCHAR(60), @c_Field08 NVARCHAR(60), @c_Field09 NVARCHAR(60), @c_Field10 NVARCHAR(60)
          , @cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @dt_StartDate DATETIME, @dt_EndDate DATETIME',    --(Wan06)
         @c_Field01,
         @c_Field02,
         @c_Field03,
         @c_Field04,
         @c_Field05,
         @c_Field06,
         @c_Field07,
         @c_Field08,
         @c_Field09,
         @c_Field10,
         @cStorerKey,
         @cFacility,                                                                                              --(Wan06)
         @dt_StartDate,                                                                                           --(Wan06)
         @dt_EndDate                                                                                              --(Wan06)
   END
   ELSE
   BEGIN
   EXEC sp_executesql @cSQL,
         N'@cStorerKey NVARCHAR(15), @cFacility NVARCHAR(5), @dt_StartDate DATETIME, @dt_EndDate DATETIME',       --(Wan06)
         @cStorerKey,
         @cFacility,
         @dt_StartDate,                                                                                           --(Wan06)
         @dt_EndDate                                                                                            --(Wan06)
   END
END
ELSE
BEGIN
   GOTO QUIT
END

IF @bDebug = 2
BEGIN
  SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Execute SQL Statement--(Check Temp DataStore In [Select View])'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   SELECT * FROM #tOrderData
   PRINT '--3.Do Initial Value Set Up--'
   SET @d_StartTime_Debug = GETDATE()
END

SELECT @n_Num=ISNULL(MAX(RNUM),'0') FROM #tOrderData
IF @n_Num = 0
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'No Orders Found(isp_Build_Loadplan)'
   GOTO QUIT
END

IF EXISTS(SELECT TOP 1 1 FROM LoadPlanDetail LD WITH (NOLOCK)
          JOIN #tOrderData T ON LD.OrderKey = T.OrderKey)
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'Found Same Order in Different LoadPlanDetail(isp_Build_Loadplan)'
   GOTO QUIT
END

SET @c_Authority = ''
SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue),'')
FROM StorerConfig sc WITH (NOLOCK)
WHERE sc.ConfigKey = 'NoMixRoutingTool_LP'
   AND sc.StorerKey = @cStorerKey
IF @c_Authority = '1'
BEGIN
   IF((SELECT COUNT(DISTINCT ISNULL(RTRIM(O.RoutingTool),'')) FROM ORDERS O WITH (NOLOCK)
   JOIN #tOrderData T ON T.OrderKey = O.OrderKey)>=2)
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Didn''t Allow Mix RoutingTool In Orders(isp_Build_Loadplan)'
      GOTO QUIT
   END
END

SET @c_Authority = ''
SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue),'')
FROM StorerConfig sc WITH (NOLOCK)
WHERE sc.ConfigKey = 'NoMixHoldSOStatus_LP'
   AND sc.StorerKey = @cStorerKey
IF @c_Authority = '1'
BEGIN
   SELECT @n_HoldOrders = COUNT(1) FROM ORDERS O WITH (NOLOCK)
   JOIN #tOrderData T ON T.OrderKey = O.OrderKey
   WHERE O.SOStatus = 'HOLD'
   IF @n_HoldOrders >= 1 AND @n_HoldOrders < @n_Num
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Didn''t Allow Mix HoldSOStatus In Orders(isp_Build_Loadplan)'
      GOTO QUIT
   END
END

-- SWT03 Max Order Control Start
SET @nMaxOrders = 0
SELECT TOP 1 @nMaxOrders= CASE WHEN ISNUMERIC(Notes) = 1 THEN CAST(Notes AS INT) ELSE 0 END
FROM Codelkup WITH (NOLOCK)
WHERE LISTNAME = @cParmCode
AND long = 'Max_Orders_Per_Load'

IF @nMaxOrders = 0
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'Max Order Per Load is not configure(isp_Build_Loadplan)'
   GOTO QUIT
END

SET @n_MaxOrderPerBuild = 0
SELECT @n_MaxOrderPerBuild
      = CASE WHEN n.NSQLValue IS NULL THEN 0
            WHEN ISNUMERIC(n.NSQLValue) = 1 THEN CAST(n.NSQLValue AS INT)
            ELSE 0
       END
FROM NSQLCONFIG AS n WITH(NOLOCK)
WHERE n.ConfigKey = 'MAXORDPERBLD'

IF @nMaxOrders > @n_MaxOrderPerBuild
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'Max Order Per Load cannot greater than ' + CAST(@n_MaxOrderPerBuild AS VARCHAR(10)) + '(isp_Build_Loadplan)'
   GOTO QUIT
END
 -- SWT03 Max Order Control End

SELECT TOP 1 @nMaxOpenQty= CASE WHEN ISNUMERIC(Notes) = 1 THEN CAST(Notes AS INT) ELSE 0 END
FROM Codelkup WITH (NOLOCK)
WHERE LISTNAME = @cParmCode
AND long = 'Max_Qty_Per_Load'



--IF @nMaxOpenQty = 0 OR @nMaxOrders = 0
--BEGIN
--   SET @bInValid = 1
--   SET @cErrorMsg = 'Please Setup Maximum Total Order Qty AND Maximum Number Of Orders Per Load, Code Generate: ' + @cParmCode
--   GOTO QUIT
--END

--Wan03 - fixed
--IF @nMaxOpenQty > 0
--   SET @nMaxOpenQty = @nMaxOpenQty + 1
--Wan03 - fixed

IF @nMaxOrders = 0
BEGIN
   SELECT @nMaxOrders = COUNT(DISTINCT OrderKey)
   FROM   #tOrderData
END

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Initial Value Setup--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   PRINT '@cBatchNo = ' + @cBatchNo + ' ,@nMaxOrders = ' + CAST(@nMaxOrders AS NVARCHAR(20)) + ' ,@nMaxOpenQty = ' +  CAST(@nMaxOpenQty AS NVARCHAR(20))
   PRINT '--4.Do Buil Load Plan--'
   SET @d_StartTime_Debug = GETDATE()
END

WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

--(Wan04) - START
DECLARE @n_eNum            INT
      , @n_Rdscnt          INT
      , @n_LoadPalletcnt   INT
      , @n_LoadCaseCnt     INT
      , @n_LoadWeight      FLOAT
      , @n_LoadCube        FLOAT

      , @n_OpenQty         INT
      , @c_LoadLineNumber  NVARCHAR(5)
      , @c_OrderLineNumber NVARCHAR(5)

SET @nTotalOpenQty = 0
SET @n_OrderCnt    = 0

DECLARE CUR_ROWNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
SELECT RNUM, OpenQty, OrderKey, [Weight], [Cube]
FROM #tOrderData
ORDER BY RNUM

OPEN CUR_ROWNO
FETCH NEXT FROM CUR_ROWNO INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube
WHILE @@FETCH_STATUS <> -1
BEGIN
   IF @@TRANCOUNT = 0
      BEGIN TRAN;

   IF @n_OpenQty > @nMaxOpenQty AND @nMaxOpenQty > 0
   BEGIN
      IF @nTotalOpenQty = 0 AND @c_LoadKey = ''
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'No Order to Generate (isp_Build_Loadplan)'
         GOTO QUIT
      END
      BREAK
   END

   IF (@n_OrderCnt >= @nMaxOrders OR @n_OrderCnt = 0) OR ((@nTotalOpenQty + @n_OpenQty) > @nMaxOpenQty AND @nMaxOpenQty > 0)
   BEGIN
      --(Wan05) - START
      IF @b_GetBatchNo = 1
      BEGIN
         SET @n_BatchNo = 0 --(Wan07)
         INSERT INTO BUILDLOADLOG
            (  Facility
            ,  Storerkey
            ,  BuildParmGroup
            ,  BuildParmCode
            ,  BuildParmString
            ,  UDF01
            ,  UDF02
            ,  AddWho
            ,  AddDate)
         VALUES
            (  @cFacility
            ,  @cStorerKey
            ,  @c_ParmGroup
            ,  @cParmCode
            ,  @cSQL
            ,  @@SPID
            ,  CAST(@n_NoOfOrderToRelease AS NVARCHAR) --NJOW11
            ,  SUSER_NAME()
            ,  @d_StartBatchTime
            )
         SELECT @n_err  = @@ERROR , @n_BatchNo = @@IDENTITY --(Wan07)
         IF @n_err  <>0
         BEGIN
            SET @bInValid = 1
            SET @cErrorMsg = 'Insert Into BUILDLOADLOG Failed. (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
            GOTO QUIT
         END

         --(Wan07) - START
         SET @cBatchNo = ''
         --SET @n_BatchNo = SCOPE_IDENTITY()
         SET @cBatchNo  = CONVERT(VARCHAR(30), @n_BatchNo)


         IF @n_BatchNo = 0
         BEGIN
            SET @bInValid = 1
            SET @cErrorMsg = 'Batch # is blank. (isp_Build_Loadplan)'
            GOTO QUIT
     END
         --(Wan07) - END

         SET @b_GetBatchNo = 0
      END
      --(Wan05) - END

      SET @d_StartTime = GetDate()
      SELECT @b_success = 0
      EXECUTE nspg_GetKey
          'LoadKey',
          10,
          @c_LoadKey OUTPUT,
          @b_success OUTPUT,
          @n_err OUTPUT,
          @cErrorMsg OUTPUT

      IF @b_success = 1
      BEGIN
         INSERT INTO LoadPlan(LoadKey, Facility, UserDefine04, UserDefine05)
         VALUES(@c_LoadKey, @cFacility, @cParmCode, @cBatchNo)
         IF @@ERROR <>0
         BEGIN
            SET @bInValid = 1
            SET @cErrorMsg = 'Insert Into LoadPlan Failed. (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
            GOTO QUIT
         END
      END
      SET @n_sNum          = @n_Num
      SET @n_OrderCnt      = 0
      SET @n_LoadPalletcnt = 0
      SET @n_LoadCaseCnt   = 0
      SET @n_LoadWeight    = 0.00
      SET @n_LoadCube      = 0.00
      SET @nTotalOpenQty   = 0
      SET @n_LoadplanCnt   = @n_LoadplanCnt + 1    --(Wan05)
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   SET @n_TotalOrderCnt = @n_TotalOrderCnt + 1     --(Wan06)

   SET @n_OrderCnt    = @n_OrderCnt + 1
   SET @n_LoadWeight  = @n_LoadWeight + ISNULL(@n_Weight,0)
   SET @n_LoadCube    = @n_LoadCube   + ISNULL(@n_Cube,0)
   SET @nTotalOpenQty = @nTotalOpenQty+ @n_OpenQty


   BEGIN TRAN

   SET @d_EditDate = GETDATE()
   SET @c_LoadLineNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), @n_OrderCnt),5)

   INSERT INTO LoadPlanDetail
   (LoadKey,            LoadLineNumber,
    OrderKey,           ConsigneeKey,
    Priority,           OrderDate,
    DeliveryDate,       Type,
    Door,               Stop,
    Route,              DeliveryPlace,
    [Weight],           [Cube],
    ExternOrderKey,     CustomerName,
    NoOfOrdLines,       CaseCnt,
    Status,             AddWho,          TrafficCop)      --tlting01
   SELECT @c_LoadKey,        @c_LoadLineNumber,
          T.OrderKey,        T.ConsigneeKey,
          T.Priority,        T.OrderDate,
          T.DeliveryDate,    T.[TYPE],
          T.Door,            '',
          T.ROUTE,           ISNULL(T.DeliveryPlace,''),
          T.[Weight],        T.[Cube],
          T.ExternOrderKey,  ISNULL(T.C_Company,''),
          T.NoOfOrdLines,    0,
          T.[STATUS],        T.AddWho,      '9'
   FROM #tOrderData T
   WHERE T.RNUM = @n_Num

   IF @@ERROR <> 0
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'INSERT INTO LoadPlanDetail Failed(INSERT). (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
      GOTO QUIT
   END

   IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey= @c_Orderkey AND LoadKey = '')
   BEGIN
      UPDATE Orders WITH (ROWLOCK)
      SET LoadKey = @c_LoadKey,
         TrafficCop = NULL,
         EditWho = @c_UserName,
         EditDate = @d_EditDate
      WHERE Orderkey = @c_Orderkey

      IF @@ERROR <> 0
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'UPDATE Orders Failed(UPDATE). (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
         GOTO QUIT
      END
   END

   COMMIT TRAN

   SET @n_LoadPalletCnt = 0
   SET @n_LoadCaseCnt   = 0

   --BEGIN TRAN     -- (WAN13)

   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   Select OD.OrderLineNumber
         ,PalletCnt = CASE WHEN PCK.Pallet  > 0 THEN FLOOR(OD.OpenQty/PCK.Pallet)  ELSE 0 END
         ,CaseCnt   = CASE WHEN PCK.CaseCnt > 0 THEN FLOOR(OD.OpenQty/PCK.CaseCnt) ELSE 0 END
   FROM ORDERDETAIL OD  WITH (NOLOCK)
   JOIN SKU SKU WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey) AND (OD.Sku = SKU.Sku)
   JOIN PACK PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
   WHERE OD.Orderkey = @c_Orderkey

   OPEN CUR_OD
   FETCH NEXT FROM CUR_OD INTO @c_OrderLineNumber, @n_Palletcnt, @n_Casecnt

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_LoadPalletCnt = @n_LoadPalletCnt + @n_Palletcnt
      SET @n_LoadCaseCnt   = @n_LoadCaseCnt + @n_Casecnt

      -- Comment By SHONG
      IF EXISTS(SELECT 1 FROM ORDERDETAIL AS o WITH(NOLOCK)
                WHERE Orderkey = @c_Orderkey
                AND   OrderLineNumber = @c_OrderLineNumber
                AND  (o.LoadKey = '' OR o.LoadKey IS NULL))
      BEGIN
         BEGIN TRAN        --(Wan13)
         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET LoadKey = @c_LoadKey
            ,TrafficCop = NULL
            ,EditWho    = @c_UserName
            ,EditDate   = @d_EditDate
         WHERE Orderkey = @c_Orderkey
         AND   OrderLineNumber = @c_OrderLineNumber

         IF @@ERROR <> 0
         BEGIN
           SET @bInValid = 1
           SET @cErrorMsg = 'UPDATE OrderDetail Failed(UPDATE). (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
           GOTO QUIT
         END
         ELSE
         BEGIN
          COMMIT TRAN
         END

      END

      FETCH NEXT FROM CUR_OD INTO @c_OrderLineNumber, @n_Palletcnt, @n_Casecnt
   END
   CLOSE CUR_OD
   DEALLOCATE CUR_OD

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   IF @bDebug = 1
      SELECT @@TRANCOUNT AS [TranCounts]


   SET @n_eNum = @n_Num
   FETCH NEXT FROM CUR_ROWNO INTO  @n_Num, @n_OpenQty, @c_Orderkey, @n_Weight, @n_Cube

   IF (@n_OrderCnt >= @nMaxOrders) OR (@n_TotalOrderCnt >= @n_NoOfOrderToRelease AND @n_NoOfOrderToRelease > 0) OR -- (Wan06)
      ((@nTotalOpenQty + @n_OpenQty) > @nMaxOpenQty AND @nMaxOpenQty > 0) OR
      (@@FETCH_STATUS = -1)
   BEGIN
      SET @n_Custcnt = 0
      SET @n_Rdscnt  = 0
      SELECT @n_Custcnt = ISNULL(COUNT(DISTINCT T.C_Company),0)
            ,@n_Rdscnt  = ISNULL(SUM(CASE WHEN O.Rds = 'Y' THEN 1 ELSE 0 END),0)
      FROM #tOrderData T
      JOIN ORDERS O WITH (NOLOCK) ON (T.Orderkey = O.Orderkey)
      WHERE T.RNUM BETWEEN @n_sNum AND @n_eNum

      IF @c_AutoUpdSuperOrderFlag = '1'
      BEGIN
         IF @n_Rdscnt > 0
             SET @c_SuperOrderFlag = 'N'
         ELSE
             SET @c_SuperOrderFlag = 'Y'  --NJOW04
      END

      -- (Wan06) - START
      SET @c_Status = '0'
      SELECT @c_Status =   CASE
                           WHEN MAX(LPD.Status) = '0' THEN '0'
                           WHEN MIN(LPD.Status) = '0' and MAX(Status) >= '1' THEN '1'
                           ELSE MIN(LPD.Status)
                           END
      FROM  LOADPLANDETAIL LPD WITH (NOLOCK)
      WHERE LPD.Loadkey = @c_LoadKey
      -- (Wan06) - END

      BEGIN TRAN

      UPDATE LoadPlan WITH (ROWLOCK)
      SET CustCnt   = @n_Custcnt,
          OrderCnt  = @n_Ordercnt,
          [Weight]  = @n_LoadWeight,
          [Cube]    = @n_LoadCube,
          PalletCnt = @n_LoadPalletCnt,
          CaseCnt   = @n_LoadCasecnt,
          SuperOrderFlag = CASE WHEN @c_AutoUpdSuperOrderFlag = '1' THEN @c_SuperOrderFlag   --NJOW04
                                ELSE SuperOrderFlag
                           END,
          DefaultStrategykey = CASE WHEN @c_AutoUpdLoadDefaultStorerStrg = '1' THEN 'Y'
                                    ELSE DefaultStrategykey
                               END,
          Status    = @c_Status,  -- (Wan06) '0',
          Trafficcop = NULL,
          EditDate = GETDATE(),
          EditWho = SUSER_SNAME()
      WHERE LoadKey = @c_LoadKey

      IF @@ERROR <> 0
      BEGIN
         SET @bInValid = 1
         SET @cErrorMsg = 'UPDATE LoadPlan Failed(UPDATE). (isp_Build_Loadplan) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))
         GOTO QUIT
      END

      WHILE @@TRANCOUNT > 0 --(Wan07)
         COMMIT TRAN; --(Wan07)

      SET @d_EndTime = GetDate()

      INSERT INTO @t_TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step3,Step4, Step5,Col1, Col2, Col3, Col4,Col5)
      VALUES ('isp_Build_Loadplan', @d_StartTime, @d_EndTime,CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114),
      CAST(@@TRANCOUNT AS VARCHAR(10)), @cStorerKey, @cBatchNo
         ,@c_LoadKey,@c_UserName,@cParmCode,@n_OrderCnt, @nTotalOpenQty)

   END
   -- (Wan06) - START
   IF (@n_TotalOrderCnt >= @n_NoOfOrderToRelease AND @n_NoOfOrderToRelease > 0)
   BEGIN
      --BREAK
      
      --NJOW11 S
      CLOSE CUR_ROWNO  
      DEALLOCATE CUR_ROWNO  
      IF OBJECT_ID('tempdb..#T2','u') IS NOT NULL  
         DROP TABLE #T2;
      GOTO END_BUILDLOAD  
      --NJOW11 E
   END
   -- (Wan06) - END
END -- WHILE(@@FETCH_STATUS <> -1)
CLOSE CUR_ROWNO
DEALLOCATE CUR_ROWNO

IF OBJECT_ID('tempdb..#T2','u') IS NOT NULL
   DROP TABLE #T2;
IF ISNULL(@c_GroupFlag,'') = 'Y'
   GOTO RETURN_BUILDLOAD
END_BUILDLOAD:

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Build Load Plan--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   PRINT '--5.Insert Trace Log--'
   SET @d_StartTime_Debug = GETDATE()
END

--(Wan05) - START
--INSERT INTO TraceInfo(TraceName, TimeIn, TimeOut, TotalTime, Step3, Step4,Step5,Col1, Col2, Col3, Col4,Col5)
--SELECT TraceName, TimeIn, TimeOut, TotalTime, Step3, Step4,Step5,Col1, Col2, Col3, Col4,Col5
--FROM @t_TraceInfo

INSERT INTO BUILDLOADDETAILLOG(Loadkey
      , Storerkey
      , BatchNo
      --, BuildParmCode
      , TotalOrderCnt
      , TotalOrderQty
      , UDF01
      , UDF02
      , UDF03
      , UDF04
      , UDF05
      , AddWho
      , AddDate
      , Duration)
SELECT  Col1       -- Loadkey
      , Step4      -- Storerkey
      , Step5      -- BatchNo
      --, Col3       -- Parm Code
      , Col4       -- # Of Order
      , Col5       -- TotalOpenQty
      , Step3      -- Transaction count
      , ''
      , ''
      , ''
      , ''
      , Col2       -- UserName
      , TimeIn     -- TimeIn
      , TotalTime  -- TotalTime
FROM @t_TraceInfo

IF @@ERROR <> 0
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'Insert Into BUILDLOADDETAILLOG Failed. (isp_Build_Loadplan)'
   GOTO QUIT
END
--(Wan05) - END

--END
--OUTPUT VARIABLE SET
SET @cErrorMsg = ''
SET @bInValid = 0
IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Insert Trace Log--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
END

QUIT:

IF (SELECT CURSOR_STATUS('LOCAL','CUR_BUILD_LOAD_SORT')) >=0
  BEGIN
     CLOSE CUR_BUILD_LOAD_SORT
     DEALLOCATE CUR_BUILD_LOAD_SORT
  END
IF (SELECT CURSOR_STATUS('GLOBAL','cur_LPGroup')) >=0
  BEGIN
     CLOSE cur_LPGroup
     DEALLOCATE cur_LPGroup
  END
IF (SELECT CURSOR_STATUS('LOCAL','CUR_BUILD_LOAD_COND')) >=0
  BEGIN
     CLOSE CUR_BUILD_LOAD_COND
     DEALLOCATE CUR_BUILD_LOAD_COND
  END

--(Wan04) - START
IF (SELECT CURSOR_STATUS('LOCAL','CUR_ROWNO')) >=0
  BEGIN
 CLOSE CUR_ROWNO
     DEALLOCATE CUR_ROWNO
  END
IF (SELECT CURSOR_STATUS('LOCAL','CUR_OD')) >=0
  BEGIN
     CLOSE CUR_OD
     DEALLOCATE CUR_OD
  END
--(Wan04) - END

--(Wan01) - START
IF @b_ForceSubSPCommit = 1 AND @bInValid = 1
BEGIN
   SET @nSuccess = 0
   SET @cErrorMsg = @cErrorMsg + ' LoadKey:' + @c_LoadKey
   SET @bInValid = 0
END
--(Wan01) - END

IF @bInValid = 1
BEGIN
   SET @nSuccess = 0
   SET @cErrorMsg = @cErrorMsg + ' LoadKey:' + @c_LoadKey

 --(Wan07) - START
   IF @@TRANCOUNT > 0
   BEGIN
      ROLLBACK TRAN
   END
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > 0 --(Wan07)
   BEGIN
       COMMIT TRAN
   END
END

--(Wan05) - START
IF EXISTS ( SELECT 1
            FROM BUILDLOADLOG  WITH (NOLOCK)
            WHERE BatchNo = @cBatchNo
            AND @cBatchNo > 0
          )
BEGIN
   SET @d_EndTime = GETDATE()

   BEGIN TRAN
   UPDATE BUILDLOADLOG
      SET Duration = CONVERT(CHAR(12), @d_EndTime - @d_StartBatchTime, 114)
        , TotalLoadCnt = @n_LoadplanCnt
        , UDF01    = ''
        , Status   = '9'
        , EditDate = @d_EndTime
        , EditWho  = SUSER_NAME()
        , Trafficcop = NULL
   WHERE BatchNo = @cBatchNo

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      COMMIT TRAN
   END
END
--(Wan05) - END

--(Wan06) - START
IF @b_NewTmpOrders = 1 AND OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NOT NULL
BEGIN
   DROP TABLE #TMP_ORDERS
END
--(Wan06) - END

WHILE @@TRANCOUNT < @n_StartTranCnt
   BEGIN TRAN

IF @bDebug = 2
BEGIN
   PRINT 'SP-isp_Build_Loadplan DEBUG-STOP...'
   PRINT '@nSuccess = ' + CAST(@nSuccess AS NVARCHAR(2))
   PRINT '@c_ErrMsg = ' + @cErrorMsg
END
-- End Procedure

GO