SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/                                                                                  
/* Store Procedure: isp_WM_Gen_BuildOrderSelect                         */                                                                                  
/* Creation Date: 12-Apr-2021                                           */                                                                                  
/* Copyright: IDS                                                       */                                                                                  
/* Written by: SHONG                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: Build Loadplan with UserDefine Parameters                   */                                                                                  
/*                                                                      */                                                                                  
/* Called By: PowerBuidler                                              */                                                                                  
/*                                                                      */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 5.4                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2023-10-23  Wan01    1.1   LFWM-4554 - PROD - CN  Auto Allocation    */
/*                            Backend SP enhancement                    */
/************************************************************************/                                                                                  
CREATE   PROC [WM].[isp_WM_Gen_BuildOrderSelect]                                                                                                                       
   @cParmCode              NVARCHAR(10),                                                                                                                    
   @cFacility              NVARCHAR(5),                                                                                                                     
   @cStorerKey             NVARCHAR(15),                                                                                                                    
   @nSuccess               INT = 1             OUTPUT,                                                                                                      
   @cErrorMsg              NVARCHAR(255)       OUTPUT,                                                                                                      
   @bDebug                 INT = 0,                                                                                                                
   @cSQLSelect             NVARCHAR(4000)      OUTPUT,                                                                                                      
   @cBatchNo               NVARCHAR(10) = ''   OUTPUT                                                                                                       
AS        
SET NOCOUNT ON                                                                                                                                           
SET ANSI_NULLS OFF                                                                                                                                       
SET QUOTED_IDENTIFIER OFF                                                                                                                                
SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
          
DECLARE @bInValid BIT                                                                                                                                       
          
DECLARE @cTableName NVARCHAR(30),
        @cValue NVARCHAR(250),
        @cColumnName NVARCHAR(250),
        @cCondLevel NVARCHAR(10),
        @cColName NVARCHAR(128),
        @cColType NVARCHAR(128),
        @n_err INT,
        @cOrAnd NVARCHAR(10),
        @cOperator NVARCHAR(10),
        @nTotalOrders INT,
        @nTotalOpenQty INT,
        @nMaxOrders INT,
        @nMaxOpenQty INT,
        @nPreCondLevel INT,
        @nCurrCondLevel INT,
        @n_HoldOrders INT,
        @n_Weight FLOAT,
        @n_Cube FLOAT,
        @n_Palletcnt INT,
        @n_Casecnt INT,
        @n_Custcnt INT,
        @n_Ordercnt INT,
        @c_LoadKey NVARCHAR(10),
        @d_StartTime DATETIME,
        @d_EndTime DATETIME,
        @d_StartTime_Debug DATETIME,
        @d_EndTime_Debug DATETIME,
        @d_EditDate DATETIME,
        @n_Num INT,
        @n_sNum INT,
        @c_UserName NVARCHAR(36),
        @c_Authority NVARCHAR(1),
        @c_SuperOrderFlag NVARCHAR(1),
        @cSQL NVARCHAR(MAX),
        @b_success INT,
        @c_ExecSPSQL NVARCHAR(500),
        @c_ParmCodeCond NVARCHAR(4000),
        @c_SPName NVARCHAR(50),
        @n_idx INT,
        @b_SPProcess INT,
        @b_ForceSubSPCommit INT,
        @d_StartBatchTime DATETIME        ,
        @b_GetBatchNo INT,
        @n_LoadplanCnt INT  ,
        @c_ParmGroup NVARCHAR(30)                                                                                                          
          
  
DECLARE @cSortBy NVARCHAR(2000),
        @cSortSeq NVARCHAR(10),
        @cCondType NVARCHAR(10),
        @c_SQLField NVARCHAR(2000),
        @c_SQLWhere NVARCHAR(2000),
        @c_SQLGroup NVARCHAR(2000),
        @c_SQLCond NVARCHAR(4000),
        @c_SQLDYN01 NVARCHAR(MAX),
        @n_cnt INT,
        @c_GroupFlag NVARCHAR(1),
        @c_Storerkey NVARCHAR(15),
        @c_Field01 NVARCHAR(60),
        @c_Field02 NVARCHAR(60),
        @c_Field03 NVARCHAR(60),
        @c_Field04 NVARCHAR(60),
        @c_Field05 NVARCHAR(60),
        @c_Field06 NVARCHAR(60),
        @c_Field07 NVARCHAR(60),
        @c_Field08 NVARCHAR(60),
        @c_Field09 NVARCHAR(60),
        @c_Field10 NVARCHAR(60),
        @n_StartTranCnt INT,
        @c_Orderkey NVARCHAR(10),
        @c_GroupBySortField NVARCHAR(2000) 

      , @b_JoinPickDetail  BIT            --(Wan01)
      , @b_JoinLoc         BIT            --(Wan01)                                                                                                
          
DECLARE @c_AutoUpdLoadDefaultStorerStrg NVARCHAR(10),
        @c_AutoUpdSuperOrderFlag NVARCHAR(10)                                                                                                               
          
DECLARE @t_TraceInfo TABLE(
        TraceName NVARCHAR(160),
        TimeIn DATETIME,
        [TIMEOUT] DATETIME,
        TotalTime NVARCHAR(40),
        Step3 NVARCHAR(40),
        Step4 NVARCHAR(40),
        Step5 NVARCHAR(40),
        Col1 NVARCHAR(40),
        Col2 NVARCHAR(40),
        Col3 NVARCHAR(40),
        Col4 NVARCHAR(40),
        Col5 NVARCHAR(40)
        )                                                                                                                                  
          
CREATE TABLE #tOrderData
(
   RNUM               INT PRIMARY KEY,
   OrderKey           NVARCHAR(10),
   ExternOrderKey     NVARCHAR(60),
   OrderDate          DATETIME,
   DeliveryDate       DATETIME,
   Priority           NVARCHAR(20),
   ConsigneeKey       NVARCHAR(30),
   C_Company          NVARCHAR(90) NULL,
   OpenQty            INT,
   STATUS             NVARCHAR(20),
   TYPE               NVARCHAR(20),
   Door               NVARCHAR(20),
   ROUTE              NVARCHAR(20),
   DeliveryPlace      NVARCHAR(60) NULL,
   WEIGHT             FLOAT NULL,
   CUBE               FLOAT NULL,
   NoOfOrdLines       INT,
   AddWho             NVARCHAR(36),
   STOP               NVARCHAR(20) DEFAULT ''
)         
          
                                                                                                                                          
CREATE TABLE #TMP_ORDERS
(
   OrderKey NVARCHAR(10) NULL
)         
          
SET @b_ForceSubSPCommit = 0                                                                                                                                           
          
IF @bDebug = 2
BEGIN
    SET @d_StartTime_Debug = GETDATE() 
    PRINT 'SP-isp_WM_Gen_BuildOrderSelect DEBUG-START...' 
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
SET @d_StartTime = GETDATE()                                                                                                                                
SET @c_UserName = RTRIM(SUSER_SNAME())                                                                                                                      
SET @n_StartTranCnt = @@TRANCOUNT   
SET @d_StartBatchTime = GETDATE()              
SET @b_GetBatchNo = 1                      
SET @n_LoadplanCnt = 0                                                                                                                                      
  
SELECT @c_SQLField = '',
       @c_SQLWhere      = '',
       @c_SQLGroup      = '',
       @n_cnt           = 0,
       @c_GroupFlag     = 'N',
       @C_SQLCond       = ''                                                

SELECT @c_ParmGroup = ISNULL(RTRIM(bpc.ParmGroup), '')
FROM BUILDPARMGROUPCFG AS bpc WITH(NOLOCK)
JOIN BUILDPARM AS bp WITH(NOLOCK) ON bp.ParmGroup = bpc.ParmGroup
WHERE bpc.[Type] = 'BackEndAlloc'
AND bp.BuildParmKey = @cParmCode
          
SET @b_JoinPickDetail = 0
SET @b_JoinLoc = 0
         
DECLARE CUR_BUILD_LOAD_SORT CURSOR LOCAL FAST_FORWARD READ_ONLY 
FOR
    --SELECT TOP 10 Long,
    --       UDF03,
    --       Short
    --FROM   CODELKUP WITH (NOLOCK)
    --WHERE  ListName = @cParmCode
    --       AND Short IN ('SORT', 'GROUP')
    --ORDER BY Code                             
  
  SELECT TOP 10 bc.FieldName, bc.Operator, bc.[Type]  
  FROM dbo.BUILDPARMDETAIL AS bc WITH(NOLOCK)
  JOIN dbo.BUILDPARM AS bp WITH(NOLOCK) ON bp.BuildParmKey = bc.BuildParmKey
  JOIN dbo.BUILDPARMGROUPCFG AS bgc WITH(NOLOCK) ON bgc.ParmGroup = bp.ParmGroup
  WHERE bgc.[Type] = 'BackEndAlloc' 
  AND bc.[Type] IN ('SORT','GROUP') 
  AND bc.BuildParmKey = @cParmCode
  ORDER BY bc.BuildParmLineNo                                                                                                                      
          
OPEN CUR_BUILD_LOAD_SORT                                                                                                                                    
          
FETCH NEXT FROM CUR_BUILD_LOAD_SORT INTO @cColumnName, @cOperator, @cCondType                                                                               
          
WHILE @@FETCH_STATUS <> -1
BEGIN
    SET @n_cnt = @n_cnt + 1 
    -- Get Column Type                                                                                                                                       
    SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)                                                                                   
    SET @cColName = SUBSTRING(
            @cColumnName,
            CHARINDEX('.', @cColumnName) + 1,
            LEN(@cColumnName) - CHARINDEX('.', @cColumnName)
        )                                                            
    
    SET @cColType = ''                                                                                                                                       
    SELECT @cColType = DATA_TYPE
    FROM   INFORMATION_SCHEMA.COLUMNS
    WHERE  TABLE_NAME          = @cTableName
           AND COLUMN_NAME     = @cColName                                                                                                                           
    
    IF ISNULL(RTRIM(@cColType), '') = ''
    BEGIN
        SET @bInValid = 1                                                                                                                                     
        SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName 
        GOTO QUIT
    END    
    
    IF @cCondType = 'SORT'
    BEGIN
        IF @cOperator = 'DESCENDING'
            SET @cSortSeq = 'DESCENDING'
        ELSE
            SET @cSortSeq = ''                                                                                                                                 
        
        IF @cTableName IN('ORDERDETAIL','LOC','PICKDETAIL') --NJOW02
            SET @cColumnName = 'MIN(' + RTRIM(@cColumnName) + ')'
        ELSE
        IF ISNULL(@c_GroupBySortField, '') = ''                                                                                                 
            SET @c_GroupBySortField = @cColumnName
        ELSE
            SET @c_GroupBySortField = @c_GroupBySortField + ', ' + RTRIM(@cColumnName)                                                                    
        
        IF ISNULL(@cSortBy, '') = ''
            SET @cSortBy = @cColumnName + ' ' + RTRIM(@cSortSeq)
        ELSE
            SET @cSortBy = @cSortBy + ', ' + RTRIM(@cColumnName) + ' ' + RTRIM(@cSortSeq)
    END        
    
   --(Wan01) - START
   IF @cTableName = 'LOC'
   BEGIN 
      SET @b_JoinPickDetail = 1
      SET @b_JoinLoc = 1
   END 

   IF @cTableName = 'PICKDETAIL'
   BEGIN 
      SET @b_JoinPickDetail = 1
   END 
   --(Wan01) - END  

    FETCH NEXT FROM CUR_BUILD_LOAD_SORT INTO @cColumnName, @cOperator, @cCondType
END       
CLOSE CUR_BUILD_LOAD_SORT                                                                                                                                   
DEALLOCATE CUR_BUILD_LOAD_SORT                                                                                                                              
          
DECLARE CUR_BUILD_LOAD_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                                                                         
  SELECT bc.FieldName, bc.[Value], bc.ConditionLevel, bc.OrAnd, bc.Operator
  FROM dbo.BUILDPARMDETAIL AS bc WITH(NOLOCK)
  JOIN dbo.BUILDPARM AS bp WITH(NOLOCK) ON bp.BuildParmKey = bc.BuildParmKey
  JOIN dbo.BUILDPARMGROUPCFG AS bgc WITH(NOLOCK) ON bgc.ParmGroup = bp.ParmGroup
  WHERE bgc.[Type] = 'BackEndAlloc' 
  AND bc.[Type] IN ('CONDITION') 
  AND bc.BuildParmKey = @cParmCode
  ORDER BY bc.BuildParmLineNo   
  
            
OPEN CUR_BUILD_LOAD_COND                                                                                                                                    
          
FETCH NEXT FROM CUR_BUILD_LOAD_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, 
@cOperator                                                            
          
WHILE @@FETCH_STATUS <> -1
BEGIN
   IF ISNUMERIC(@cCondLevel) = 1
   BEGIN
      IF @nPreCondLevel = 0
         SET @nPreCondLevel = CAST(@cCondLevel AS INT)
        
      SET @nCurrCondLevel = CAST(@cCondLevel AS INT)
   END 
    
   -- Get Column Type                                                                                                                                                  
   BEGIN TRY
      SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)   
      SET @cColName = SUBSTRING(
            @cColumnName,
            CHARINDEX('.', @cColumnName) + 1,
            LEN(@cColumnName) - CHARINDEX('.', @cColumnName)
         )                                                            
      
      
   END TRY
   BEGIN CATCH          
      SELECT @cColName '@cColName', @cColumnName '@cColumnName', @cTableName '@cTableName'
   END CATCH                                                                         
    
   SET @cColType = ''                                                                                                                                       
   SELECT @cColType = DATA_TYPE
   FROM  INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_NAME          = @cTableName
   AND COLUMN_NAME     = @cColName                                                                                                                           
    
   IF ISNULL(RTRIM(@cColType), '') = ''
   BEGIN
      SET @bInValid = 1                                                                                                                                     
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName 
      GOTO QUIT
   END    
    
   IF @cColType = 'datetime'
      AND ISDATE(@cValue) <> 1
   BEGIN
      -- SHONG01                                                                                                                                            
      IF @cValue IN ('today', 'now', 'startofmonth', 'endofmonth', 
                     'startofyear', 'endofyear')
         OR LEFT(@cValue, 6) IN ('today+', 'today-') --NJOW06
      BEGIN
         SET @cValue = CASE 
                              WHEN @cValue = 'today' THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                              WHEN LEFT(@cValue, 6) IN ('today+', 'today-') AND 
                                 ISNUMERIC(SUBSTRING(@cValue, 7, 10)) = 1 --NJOW06
                                    THEN LEFT(
                                       CONVERT(
                                          VARCHAR(30),
                                          DATEADD(DAY, CONVERT(INT, SUBSTRING(@cValue, 6, 10)), GETDATE()),
                                          120
                                       ),
                                       10
                                 )
                              WHEN @cValue = 'now' THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                              WHEN @cValue = 'startofmonth' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                                 + '-' 
                                 + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) 
                                 + ('-01')
                              WHEN @cValue = 'endofmonth' THEN CONVERT(
                                       VARCHAR(30),
                                       DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, GETDATE()) + 1, 0)),
                                       120
                                 )
                              WHEN @cValue = 'startofyear' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                                 + '-01-01'
                              WHEN @cValue = 'endofyear' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                                 + '-12-31 23:59:59'
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
      SET @c_SQLCond = @c_SQLCond + ' ' + MASTER.dbo.fnc_GetCharASCII(13) +
         ' ' + @cOrAnd + N' ('
        
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE 
   IF @nPreCondLevel > @nCurrCondLevel
   BEGIN
      SET @c_SQLCond = @c_SQLCond + N') ' + MASTER.dbo.fnc_GetCharASCII(13) +
         ' ' + @cOrAnd
        
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE
   BEGIN
      SET @c_SQLCond = @c_SQLCond + ' ' + MASTER.dbo.fnc_GetCharASCII(13) +
         ' ' + @cOrAnd
   END  
    
   IF @cOperator = 'IN SQL'                                                         --(Wan01) - START
   BEGIN
      SET @cOperator = 'IN'
   END

   IF @cOperator = 'NOT IN SQL'
   BEGIN
      SET @cOperator = 'NOT IN'
   END                                                                              --(Wan01) - END
    
   IF @cColType IN ('char', 'nvarchar', 'varchar', 'nchar') --SWT02
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator +
         CASE 
               WHEN @cOperator IN ( 'IN', 'NOT IN') THEN                          --(Wan01)                                                                                                      
                     CASE 
                        WHEN LEFT(RTRIM(LTRIM(@cValue)), 1) <> '(' THEN '('
                        ELSE ''
                     END +
                     RTRIM(LTRIM(@cValue)) +
                     CASE 
                        WHEN RIGHT(RTRIM(LTRIM(@cValue)), 1) <> ')' THEN ') '
                        ELSE ''
                     END
               ELSE ' N' +
                     CASE 
                        WHEN LEFT(RTRIM(LTRIM(@cValue)), 1) <> '''' THEN ''''
                        ELSE ''
                     END +
                     RTRIM(LTRIM(@cValue)) +
                     CASE 
                        WHEN RIGHT(RTRIM(LTRIM(@cValue)), 1) <> '''' THEN 
                              ''' '
                        ELSE ''
                     END
               END
   ELSE 
   IF @cColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 
                  'real', 'bigint')
                                                
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator  + 
            CASE WHEN @cOperator IN ('IN','NOT IN') THEN                            --(Wan01)                                                                                                        
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '(' THEN '(' ELSE '' END +                                                                        
               RTRIM(LTRIM(@cValue)) +                                                                                                                      
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> ')' THEN ') ' ELSE '' END    
            WHEN @cOperator = 'LIKE' THEN    
               ' N' +                                                                                                                                     
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN '''' ELSE '' END +                                                                      
               RTRIM(LTRIM(@cValue)) +                                        
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN ''' ' ELSE '' END      
            ELSE
               RTRIM(@cValue)    
            END  
   ELSE 
   IF @cColType IN ('datetime')
      SET @c_SQLCond = @c_SQLCond + ' ' + @cColumnName + ' ' + @cOperator +
         ' ''' + @cValue + ''' '
    

   IF @cTableName = 'LOC'
   BEGIN 
      SET @b_JoinPickDetail = 1
      SET @b_JoinLoc = 1
   END 

   IF @cTableName = 'PICKDETAIL'
   BEGIN 
      SET @b_JoinPickDetail = 1
   END

   FETCH NEXT FROM CUR_BUILD_LOAD_COND INTO @cColumnName, @cValue, @cCondLevel, 
   @cOrAnd, @cOperator
END       
CLOSE CUR_BUILD_LOAD_COND                                                                                                            
DEALLOCATE CUR_BUILD_LOAD_COND                                                                                                                              
          
WHILE @nPreCondLevel > 1
BEGIN
    SET @c_SQLCond = @c_SQLCond + N') '                                                                                                                      
    SET @nPreCondLevel = @nPreCondLevel - 1
END       
          
IF ISNULL(@cSortBy, '') = ''
    SET @cSortBy = 'ORDERS.[OrderKey]'                                                                                                                       
   
START_BUILDLOAD:

DELETE FROM #tOrderData
                                                                                                                                     
SET @nPreCondLevel = 0                                                                                                                                      
SET @nCurrCondLevel = 0                                                                                                                                     
SET @nMaxOrders = 0                                                                                                                                         
SET @nMaxOpenQty = 0                                                                                                                                        
SET @n_sNum = 1 

SET @cSQL = 
    N'SELECT ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@cSortBy) +
    ') AS Number,ORDERS.OrderKey,
   ORDERS.ExternOrderKey,ORDERS.OrderDate,ORDERS.DeliveryDate,ORDERS.Priority,ORDERS.ConsigneeKey,
   ORDERS.C_Company,ORDERS.OpenQty,ORDERS.Status,ORDERS.Type,ORDERS.Door,ORDERS.Route,ORDERS.DeliveryPlace,
   SUM(ORDERDETAIL.OpenQty * SKU.StdGrossWgt) AS TotalGrossWgt, SUM(ORDERDETAIL.OpenQty * SKU.StdCube) AS TotalCube,
   COUNT(DISTINCT ORDERDETAIL.OrderLineNumber) AS OrderLines,''*'' + RTRIM(sUser_sName()) AS [UserName]
   FROM ORDERS WITH (NOLOCK)
   LEFT OUTER JOIN OrderDetail (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   LEFT OUTER JOIN SKU (NOLOCK) ON (ORDERDETAIL.SKU = SKU.SKU AND ORDERS.StorerKey = SKU.StorerKey)
   LEFT OUTER JOIN LoadPlanDetail LD (NOLOCK) ON LD.OrderKey = ORDERS.OrderKey 
   LEFT OUTER JOIN OrderInfo WITH(NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey '  
   + CASE WHEN @b_JoinPickDetail = 1 OR @b_JoinLoc = 1 
            THEN 'LEFT JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey=PICKDETAIL.Orderkey) AND (ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber)' + CHAR(13)
            ELSE ''
            END 
   + CASE WHEN @b_JoinLoc = 1 
            THEN 'LEFT JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc=LOC.Loc)'  + CHAR(13)
            ELSE ''
            END
 
   + ' WHERE ORDERS.StorerKey = N''' + @cStorerKey + '''' + 
   CASE WHEN ISNULL(@cFacility, '') <> '' THEN ' AND ORDERS.Facility = N''' + @cFacility + '''' 
        ELSE ''
   END + '
   AND ORDERS.Status < ''3'' AND LD.LoadKey IS NULL
   AND (ORDERS.LoadKey = '''' OR ORDERS.LoadKey IS NULL)
   AND ORDERS.SOStatus NOT IN (''PENDING'',''PENDCANC'',''HOLD'') '  + RTRIM(@c_SQLCond)                                                                                      
 
           
IF ISNULL(@c_GroupFlag, '') = 'Y'
    SET @cSQL = RTRIM(@cSQL) + ' ' + CHAR(13) + @c_SQLWhere                                                                                                 
          
SET @cSQL = RTRIM(@cSQL) + CHAR(13) +
    N' GROUP BY
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
          
IF ISNULL(@c_GroupBySortField, '') <> ''                                                                                                
    SET @cSQL = RTRIM(@cSQL) + ',' + CHAR(13) + RTRIM(@c_GroupBySortField)                                                                                   
          
IF @bDebug = 2
BEGIN
    SET @d_EndTime_Debug = GETDATE() 
    PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])' 
    PRINT 'Time Cost:' + CONVERT(CHAR(12), @d_EndTime_Debug - @d_StartTime_Debug, 114)                                                                        
    SELECT @cSQL 
    PRINT '--2.Do Execute SQL Statement--'                                                                                                                   
    SET @d_StartTime_Debug = GETDATE()
END       
          
SET @cSQLSelect = @cSQL                                                                                                                                      

QUIT:
          
          
IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_BUILD_LOAD_SORT')) >= 0
BEGIN
    CLOSE CUR_BUILD_LOAD_SORT 
    DEALLOCATE CUR_BUILD_LOAD_SORT
END
     
IF (SELECT CURSOR_STATUS('GLOBAL', 'cur_LPGroup')) >= 0
BEGIN
    CLOSE cur_LPGroup 
    DEALLOCATE cur_LPGroup
END
     
IF (SELECT CURSOR_STATUS('LOCAL', 'CUR_BUILD_LOAD_COND')) >= 0
BEGIN
    CLOSE CUR_BUILD_LOAD_COND 
    DEALLOCATE CUR_BUILD_LOAD_COND
END   
                                                                                                                             
IF @b_ForceSubSPCommit = 1 AND @bInValid = 1
BEGIN
    SET @nSuccess = 0                                                                                                                                        
    SET @cErrorMsg = @cErrorMsg                                                                                                  
    SET @bInValid = 0
END                                                                                                                                           
          
IF @bInValid = 1
BEGIN
    SET @nSuccess = 0                                                                                                                                        
    SET @cErrorMsg = @cErrorMsg                                                                                                 
    
    IF @@TRANCOUNT = 1
       AND @@TRANCOUNT > @n_StartTranCnt
    BEGIN
        ROLLBACK TRAN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT > @n_StartTranCnt
        BEGIN
            COMMIT TRAN
        END
    END
END
ELSE
BEGIN
    WHILE @@TRANCOUNT > @n_StartTranCnt
    BEGIN
        COMMIT TRAN
    END
END       
         
WHILE @@TRANCOUNT < @n_StartTranCnt 
   BEGIN TRAN                                                                                                                                               
          
IF @bDebug = 2
BEGIN
    PRINT 'SP-isp_WM_Gen_BuildOrderSelect DEBUG-STOP...' 
    PRINT '@nSuccess = ' + CAST(@nSuccess AS NVARCHAR(2)) 
    PRINT '@c_ErrMsg = ' + @cErrorMsg
END-- End Procedure

GO