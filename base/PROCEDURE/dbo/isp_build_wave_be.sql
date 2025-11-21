SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Build_Wave_BE                                   */
/* Creation Date: 11-May-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 369136-Build Wave with UserDefine condition at wave setup   */
/*                 criteria                                             */
/*                                                                      */
/* Called By: PowerBuidler                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 20-Oct-2016  Leong     1.1   IN00171620 - cater for single quote.    */
/* 27-Jun-2018  NJOW01    1.2   Fix - include NCHAR                     */
/* 09-Aug-2018  NJOW02    1.3   WMS-5960 Skip userdefine08 checking     */ 
/* 22-Nov-2021  WLChooi   1.7   WMS-18409 Extend @cValue length to      */
/*                              NVARCHAR(4000) (WL01)                   */
/* 22-Nov-2021  WLChooi   1.7   DevOps Combine Script                   */
/************************************************************************/

CREATE PROC [dbo].[isp_Build_Wave_BE]
    @c_Wavekey              NVARCHAR(10)
   ,@c_OrderSelectionkey    NVARCHAR(10) 
   ,@c_Status               NVARCHAR(10) = '2'
   ,@c_Option               NVARCHAR(10) = 'CN' --Country get from client option (user.ini)
   ,@nSuccess               INT = 0 OUTPUT
   ,@cErrorMsg              NVARCHAR(255) = '' OUTPUT
   ,@cSQLPreview            NVARCHAR(4000) = '' OUTPUT
   ,@bDebug                 INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @bInValid          BIT,
        @cTableName        NVARCHAR(30),
        @cValue            NVARCHAR(4000),   --WL01
        @cColumnName       NVARCHAR(250),
        @cCondLevel        NVARCHAR(10),
        @cColName          NVARCHAR(128),
        @cColType          NVARCHAR(128),
        @cOrAnd            NVARCHAR(10),
        @cOperator         NVARCHAR(10),
        @nTotalOrders      INT,
        @nTotalOpenQty     INT,
        @nMaxOrders        INT,
        @nMaxOpenQty       INT,
        @nPreCondLevel     INT,
        @nCurrCondLevel    INT,
        @d_StartTime_Debug DATETIME,
        @d_EndTime_Debug   DATETIME,
        @n_sNum            INT,
        @cSQL              NVARCHAR(MAX),
        @cSQL2             NVARCHAR(MAX),
        @c_FacilityCond    NVARCHAR(1000),
        @c_StatusCond      NVARCHAR(1000),
        @c_TopCond         NVARCHAR(20),
        @cSortBy           NVARCHAR(2000),
        @cSortSeq          NVARCHAR(10),
        @n_StartTranCnt    INT,
        @cGroupBy          NVARCHAR(2000)
        
DECLARE @b_success INT,
        @n_err INT,
        @c_Errmsg NVARCHAR(250),
        @c_Orderkey NVARCHAR(10),
        @c_Wavedetailkey NVARCHAR(10)                

DECLARE @t_TraceInfo TABLE(
   TraceName NVARCHAR(160),
   TimeIn    DATETIME,
   TimeOut   DATETIME,
   TotalTime NVARCHAR(40),
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
   ,ExternOrderkey     NVARCHAR(30) NULL
   ,OpenQty            INT
)

IF @bDebug = 2
BEGIN
   SET @d_StartTime_Debug = GETDATE()
   PRINT 'SP-isp_Build_Wave_BE DEBUG-START...'
   PRINT '--1.Do Generate SQL Statement--'
END

SET @bInValid       = 0
SET @cErrorMsg      = ''
SET @nSuccess       = 1
SET @nTotalOrders   = 0
SET @nTotalOpenQty  = 0
SET @nPreCondLevel  = 0
SET @nCurrCondLevel = 0
SET @nMaxOrders     = 0
SET @nMaxOpenQty    = 0
SET @n_sNum         = 1
SET @cGroupBy  = N' GROUP BY
                    ORDERS.OrderKey
                   ,ORDERS.ExternOrderkey
                   ,ORDERS.OpenQty'

SET @c_OrderSelectionKey = REPLACE(@c_OrderSelectionKey, '''', '''''') -- IN00171620

SET @n_StartTranCnt = @@TRANCOUNT

IF NOT EXISTS(SELECT 1 FROM WAVE (NOLOCK) WHERE Wavekey = @c_Wavekey)
BEGIN
    SET @bInValid = 1
    SET @cErrorMsg = 'Invalid Wavekey: ' + @c_wavekey
    GOTO QUIT	
END

IF NOT EXISTS(SELECT 1 FROM OrderSelection(NOLOCK) WHERE OrderSelectionKey = @c_OrderSelectionkey)
BEGIN
    SET @bInValid = 1
    SET @cErrorMsg = 'Invalid Orderselectionkey: ' + @c_OrderSelectionkey
    GOTO QUIT	
END

IF EXISTS(SELECT 1 FROM WAVEDETAIL (NOLOCK) WHERE Wavekey = @c_Wavekey)
BEGIN
    SET @bInValid = 1
    SET @cErrorMsg = 'This wave already have order. Wavekey: ' + @c_wavekey
    GOTO QUIT	
END

IF @@TRANCOUNT = 0
   BEGIN TRAN

DECLARE CUR_BUILD_WAVE_SORT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TOP 10 FieldName, Operator
   FROM   OrderSelectionCondition WITH (NOLOCK)
   WHERE  OrderSelectionKey = @c_OrderSelectionKey
   AND    [Type] = 'SORT'
   ORDER BY OrderSelectionLineNumber

OPEN CUR_BUILD_WAVE_SORT
FETCH NEXT FROM CUR_BUILD_WAVE_SORT INTO @cColumnName, @cOperator

WHILE @@FETCH_STATUS <> -1
BEGIN
   SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName, CHARINDEX('.', @cColumnName) + 1, LEN(@cColumnName) - CHARINDEX('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE
   FROM   INFORMATION_SCHEMA.COLUMNS
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = ''
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName
      GOTO QUIT
   END

   IF @cOperator = 'DESC'
      SET @cSortSeq = 'DESC'
   ELSE
      SET @cSortSeq = ''

   IF @cTableName = 'ORDERDETAIL'
      SET @cColumnName = 'MIN('+RTRIM(@cColumnName) + ')'
   ELSE
      SET @cGroupBy = @cGroupBy + CHAR(13) + ',' + RTRIM(@cColumnName)

   IF ISNULL(@cSortBy,'') = ''
      SET @cSortBy = @cColumnName + ' ' + RTRIM(@cSortSeq)
   ELSE
      SET @cSortBy = @cSortBy + ', ' +  RTRIM(@cColumnName) + ' ' + RTRIM(@cSortSeq)

   FETCH NEXT FROM CUR_BUILD_WAVE_SORT INTO @cColumnName, @cOperator
END
CLOSE CUR_BUILD_WAVE_SORT
DEALLOCATE CUR_BUILD_WAVE_SORT

IF @c_Option = 'HK'
BEGIN
   SET @c_StatusCond = ' AND (ORDERS.Status >= N''' + RTRIM(ISNULL(@c_Status,'')) + ''' AND ORDERS.Status < N''5'') '
   SET @c_FacilityCond = ' AND (ORDERS.Facility = OrderSelection.Facility) '
END
ELSE
BEGIN
   SET @c_StatusCond = ' AND (ORDERS.Status = N''' + RTRIM(ISNULL(@c_Status,'')) + ''' AND ORDERS.Status < N''8'') '
   SET @c_FacilityCond = ' AND (ORDERS.Facility = CASE
                           WHEN ISNULL(OrderSelection.Facility, '''') <> '''' THEN OrderSelection.Facility
                           ELSE ORDERS.Facility END) '
END

SELECT TOP 1 @nMaxOrders= CASE WHEN ISNUMERIC([Value]) = 1 THEN CAST([Value] AS INT) ELSE 0 END
FROM   OrderSelectionCondition WITH (NOLOCK)
WHERE  OrderSelectionKey = @c_OrderSelectionKey
AND FieldName = 'Max_Orders_Per_Wave'

SELECT TOP 1 @nMaxOpenQty= CASE WHEN ISNUMERIC([Value]) = 1 THEN CAST([Value] AS INT) ELSE 0 END
FROM   OrderSelectionCondition WITH (NOLOCK)
WHERE  OrderSelectionKey = @c_OrderSelectionKey
AND FieldName = 'Max_Qty_Per_Wave'

IF ISNULL(@nMaxOrders,0) > 0
   SET @c_TopCond = 'TOP ' + RTRIM(CAST(@nMaxOrders AS NVARCHAR))
ELSE
   SET @c_TopCond = ''

IF ISNULL(@cSortBy,'') = ''
   SET @cSortBy = 'ORDERS.[OrderKey]'

SET @cSQL = CASE WHEN @bDebug  = 1 THEN N'' ELSE
   N'INSERT INTO #tOrderData(RNUM, OrderKey, ExternOrderkey, OpenQty) ' END + CHAR(13) +
   N'SELECT ' + @c_TopCond + ' ROW_NUMBER() OVER (ORDER BY ' + RTRIM(@cSortBy) + ') AS Number, ORDERS.OrderKey, ORDERS.ExternOrderkey, ORDERS.OpenQty
     FROM ORDERS WITH (NOLOCK) 
     JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
     JOIN OrderSelection WITH (NOLOCK) ON  (ORDERS.Storerkey >= OrderSelection.storerkeystart)
         AND (ORDERS.Storerkey <= OrderSelection.storerkeyend)  
         AND (ORDERS.OrderDate >= OrderSelection.orderdatestart)
         AND (ORDERS.OrderDate <= OrderSelection.orderdateend)
     LEFT JOIN V_StorerConfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = ''WaveSkipUserdefine08Chk''                                   
     WHERE (OrderSelection.OrderSelectionKey = N''' + @c_OrderSelectionKey + '''' + ') ' + ' 
     AND (ORDERS.UserDefine08 = ''Y'' OR ISNULL(SC.Svalue,'''')=''1'')     
     AND (NOT ORDERS.Status IN (''8'', ''9'') )
     AND (ORDERS.ConsigneeKey >= OrderSelection.consigneekeystart)
     AND (ORDERS.ConsigneeKey <=  OrderSelection.consigneekeyend)
     AND (ORDERS.Type >=  OrderSelection.ordertypestart)
     AND (ORDERS.Type <=  OrderSelection.OrderTypeEnd)
     AND (ORDERS.DeliveryDate >= OrderSelection.deliveryDateStart)
     AND (ORDERS.DeliveryDate <= OrderSelection.deliveryDateEnd)
     AND (ORDERS.Priority >= OrderSelection.orderpriorityStart)
     AND (ORDERS.Priority <= OrderSelection.orderpriorityEnd)
     AND (ORDERS.Intermodalvehicle >= OrderSelection.carrierkeystart)
     AND (ORDERS.Intermodalvehicle <= OrderSelection.carrierkeyend)
     AND (ORDERS.Orderkey >= OrderSelection.OrderkeyStart)
     AND (ORDERS.Orderkey <= OrderSelection.OrderkeyEnd)
     AND (ORDERS.ExternOrderkey >= OrderSelection.ExternOrderkeyStart)
     AND (ORDERS.ExternOrderkey <= OrderSelection.ExternOrderkeyEnd)
     AND (ORDERS.Route >= OrderSelection.RouteStart)
     AND (ORDERS.Route <= OrderSelection.RouteEnd)
     AND (ORDERS.Door >= OrderSelection.DoorStart)
     AND (ORDERS.Door <= OrderSelection.DoorEnd)
     AND (ORDERS.Stop >= OrderSelection.StopStart)
     AND (ORDERS.Stop <= OrderSelection.StopEnd)
     AND (ORDERS.OrderGroup >= OrderSelection.ordergroupstart)
     AND (ORDERS.OrderGroup <= OrderSelection.ordergroupEnd)
     AND (ISNULL(ORDERS.BuyerPO,'''') >= OrderSelection.BuyerPOStart)
     AND (ISNULL(ORDERS.BuyerPO,'''') <= OrderSelection.BuyerPOEnd)
     AND (ORDERS.UserDefine09 IS NULL OR ORDERS.UserDefine09 = '''')
     AND (ORDERS.SOStatus <> ''PENDING'')
     AND (ORDERS.SOStatus NOT IN (SELECT CODELKUP.Code
                                  FROM CODELKUP WITH (NOLOCK)
                                  WHERE CODELKUP.Listname = ''WBEXCSOSTS''
                                  AND CODELKUP.Storerkey = ORDERS.Storerkey))
     AND (ISNULL(ORDERS.Doctype,'''') >= OrderSelection.DocTypeStart)
     AND (ISNULL(ORDERS.Doctype,'''') <= OrderSelection.DocTypeEnd)
     AND (ISNULL(ORDERS.BillToKey,'''') >= OrderSelection.BillToKeyStart)
     AND (ISNULL(ORDERS.BillToKey,'''') <= OrderSelection.BillToKeyEnd)
     AND (ISNULL(ORDERS.M_ISOCntryCode,'''') >= OrderSelection.M_ISOCntryCodeStart)
     AND (ISNULL(ORDERS.M_ISOCntryCode,'''') <= OrderSelection.M_ISOCntryCodeEnd)
     AND (ISNULL(ORDERS.UserDefine05,'''') >= OrderSelection.UserDefine05Start)
     AND (ISNULL(ORDERS.UserDefine05,'''') <= OrderSelection.UserDefine05End)
     AND (ISNULL(ORDERS.SpecialHandling,'''') >= OrderSelection.SpecialHandlingStart)
     AND (ISNULL(ORDERS.SpecialHandling,'''') <= OrderSelection.SpecialHandlingEnd)
     AND (ISNULL(ORDERS.DeliveryNote,'''') >= OrderSelection.DeliveryNoteStart)
     AND (ISNULL(ORDERS.DeliveryNote,'''') <= OrderSelection.DeliveryNoteEnd) '
     --+ CHAR(13) + @c_FacilityCond
     --+ CHAR(13) + @c_StatusCond

SET @cSQL2 = CHAR(13) + @c_FacilityCond + CHAR(13) + @c_StatusCond      

DECLARE CUR_BUILD_WAVE_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT FieldName, ISNULL([Value],''), ConditionGroup, OperatorAndOr, Operator
   FROM   OrderSelectionCondition WITH (NOLOCK)
   WHERE  OrderSelectionKey = @c_OrderSelectionKey
   AND    [Type] = 'CONDITION'
   ORDER BY OrderSelectionLineNumber

OPEN CUR_BUILD_WAVE_COND
FETCH NEXT FROM CUR_BUILD_WAVE_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator

WHILE @@FETCH_STATUS <> -1
BEGIN
   IF ISNUMERIC(@cCondLevel) = 1
   BEGIN
      IF @nPreCondLevel=0
         SET @nPreCondLevel = CAST(@cCondLevel AS INT)
      SET @nCurrCondLevel = CAST(@cCondLevel AS INT)
   END

   SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)
   SET @cColName   = SUBSTRING(@cColumnName, CHARINDEX('.', @cColumnName) + 1, LEN(@cColumnName) - CHARINDEX('.', @cColumnName))

   SET @cColType = ''
   SELECT @cColType = DATA_TYPE
   FROM   INFORMATION_SCHEMA.COLUMNS
   WHERE  TABLE_NAME = @cTableName
   AND    COLUMN_NAME = @cColName

   IF ISNULL(RTRIM(@cColType), '') = ''
   BEGIN
      SET @bInValid = 1
      SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName
      GOTO QUIT
   END

   IF @cColType = 'DATETIME' AND
      ISDATE(@cValue) <> 1
   BEGIN
      IF @cValue IN ('today','now', 'startofmonth', 'endofmonth', 'startofyear', 'endofyear')
      BEGIN
         SET @cValue = CASE @cValue
                           WHEN 'today'
                              THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                           WHEN 'now'
                              THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                           WHEN 'startofmonth'
                              THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-'
                                 + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) + ('-01')
                           WHEN 'endofmonth'
                              THEN CONVERT(VARCHAR(30), DATEADD(s,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)), 120)
                           WHEN 'startofyear'
                              THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-01-01'
                           WHEN 'endofyear'
                              THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-12-31 23:59:59'
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
      SET @cSQL2 = @cSQL2 + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd + N' ('
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE IF @nPreCondLevel > @nCurrCondLevel
   BEGIN
      SET @cSQL2 = @cSQL2 + N') '  + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd
      SET @nPreCondLevel = @nCurrCondLevel
   END
   ELSE
   BEGIN
      SET @cSQL2 = @cSQL2 + ' ' + master.dbo.fnc_GetCharASCII(13) + ' ' + @cOrAnd
   END

   IF @cColType IN ('CHAR', 'NVARCHAR', 'VARCHAR','NCHAR') --NJOW01
      SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator +
            CASE WHEN @cOperator = 'IN' THEN
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '(' THEN '(' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> ')' THEN ') ' ELSE '' END
            ELSE ' N' +
               CASE WHEN LEFT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN '''' ELSE '' END +
               RTRIM(LTRIM(@cValue)) +
               CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)),1) <> '''' THEN ''' ' ELSE '' END
            END
   ELSE IF @cColType IN ('FLOAT', 'MONEY', 'INT', 'DECIMAL', 'NUMERIC', 'TINYINT', 'REAL', 'BIGINT')
      SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator  + RTRIM(@cValue)
   ELSE IF @cColType IN ('DATETIME')
      SET @cSQL2 = @cSQL2 + ' ' + @cColumnName + ' ' + @cOperator + ' '''+ @cValue + ''' '
   FETCH NEXT FROM CUR_BUILD_WAVE_COND INTO @cColumnName, @cValue, @cCondLevel, @cOrAnd, @cOperator
END
CLOSE CUR_BUILD_WAVE_COND
DEALLOCATE CUR_BUILD_WAVE_COND

WHILE @nPreCondLevel > 1
BEGIN
   SET @cSQL2 = @cSQL2 + N') '
   SET @nPreCondLevel = @nPreCondLevel - 1
END

SET @cSQL2 = RTRIM(@cSQL2) + CHAR(13) + @cGroupBy

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Generate SQL Statement--(Check Result In [Select View])'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   SELECT @cSQL
   PRINT '--2.Do Execute SQL Statement--'
   SET @d_StartTime_Debug = GETDATE()
END

SET @cSQLPreview = @cSQL + @cSQL2

IF @bDebug <> 1
BEGIN
   EXEC (@cSQL + ' ' + @cSQL2)
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

SELECT @n_sNum=ISNULL(MAX(RNUM),'0') FROM #tOrderData
IF @n_sNum = 0
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'No Orders Found(isp_Build_Wave_BE)'
   GOTO QUIT
END

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Initial Value Setup--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   PRINT '@nMaxOrders = ' + CAST(@nMaxOrders AS NVARCHAR(20)) + ' ,@nMaxOpenQty = ' +  CAST(@nMaxOpenQty AS NVARCHAR(20))
   PRINT '--4.Do Buil Wave Plan--'
   SET @d_StartTime_Debug = GETDATE()
END

IF @n_sNum > 0
BEGIN
   SELECT @nTotalOpenQty = SUM(OpenQty) FROM #tOrderData WHERE RNUM <= @n_sNum
   IF @nTotalOpenQty > @nMaxOpenQty AND ISNULL(@nMaxOpenQty,0) > 0
   BEGIN
      SELECT T1.RNUM, T2.CumSum
      INTO #t_CumOrder
      FROM #tOrderData T1
          CROSS APPLY (
          SELECT   SUM(T2.OpenQty) AS CumSum
          FROM     #tOrderData T2
          WHERE    T1.RNUM >= T2.RNUM
          ) T2
      WHERE T1.RNUM <= @n_sNum

      SELECT @n_sNum = MAX(RNUM) FROM #t_CumOrder WHERE CumSum <= @nMaxOpenQty

      IF ISNULL(@n_sNUM,0) = 0
      BEGIN
        SET @bInValid = 1
        SET @cErrorMsg = 'No Orders Found(isp_Build_Wave_BE)'
        GOTO QUIT
      END
   END
END

DECLARE cur_WaveOrd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT T.Orderkey
   FROM #tOrderData T
   WHERE T.RNUM <= @n_sNum
   ORDER BY T.RNUM
   
OPEN cur_WaveOrd
       
FETCH FROM cur_WaveOrd INTO @c_Orderkey
       
WHILE @@FETCH_STATUS = 0 
BEGIN       	      
	 SET @b_success = 0
	 SET @c_Wavedetailkey = ''
	 
   EXEC dbo.nspg_GetKey                
       @KeyName = 'WavedetailKey'    
      ,@fieldlength = 10    
      ,@keystring = @c_Wavedetailkey OUTPUT    
      ,@b_Success = @b_success OUTPUT    
      ,@n_err = @n_err OUTPUT    
      ,@c_errmsg = @c_errmsg OUTPUT
      ,@b_resultset = 0    
      ,@n_batch     = 1           
      
   IF @b_Success = 1
   BEGIN         
      INSERT INTO WAVEDETAIL(Wavekey, Wavedetailkey, Orderkey)
      VALUES (@c_Wavekey, @c_Wavedetailkey, @c_Orderkey)
   END   

   FETCH FROM cur_WaveOrd INTO @c_Orderkey
END
CLOSE cur_WaveOrd
DEALLOCATE cur_WaveOrd
   
IF OBJECT_ID('tempdb..#t_CumOrder','u') IS NOT NULL
   DROP TABLE #t_CumOrder;

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Build Load Plan--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
   PRINT '--5.Insert Trace Log--'
   SET @d_StartTime_Debug = GETDATE()
END

INSERT INTO TraceInfo(TraceName, TimeIn, TimeOut, TotalTime,Step5,Col1, Col2, Col3, Col4,Col5)
SELECT * FROM @t_TraceInfo
IF @@ERROR <> 0
BEGIN
   SET @bInValid = 1
   SET @cErrorMsg = 'Insert Into TranInfo Failed. (isp_Build_Wave_BE)'
   GOTO QUIT
END

SET @cErrorMsg = ''
SET @bInValid = 0

IF @bDebug = 2
BEGIN
   SET @d_EndTime_Debug = GETDATE()
   PRINT '--Finish Insert Trace Log--'
   PRINT 'Time Cost:' + CONVERT(CHAR(12),@d_EndTime_Debug - @d_StartTime_Debug ,114)
END

QUIT:
IF @bInValid = 1
BEGIN
   SET @nSuccess = 0
   SET @cErrorMsg = @cErrorMsg + ' OrderSelectionKey:' + @c_OrderSelectionkey
   IF @@TRANCOUNT=1
       AND @@TRANCOUNT>@n_StartTranCnt
   BEGIN
       ROLLBACK TRAN
   END
   ELSE
   BEGIN
       WHILE @@TRANCOUNT>@n_StartTranCnt
       BEGIN
           COMMIT TRAN
       END
   END
   execute nsp_logerror 36000, @cErrorMsg, 'isp_Build_Wave_BE'
    RAISERROR (@cErrorMsg, 16, 1) WITH SETERROR    -- SQL2012
END
ELSE
BEGIN
   WHILE @@TRANCOUNT>@n_StartTranCnt
   BEGIN
       COMMIT TRAN
   END
END
IF @bDebug = 2
BEGIN
   PRINT 'SP-isp_Build_Wave_BE DEBUG-STOP...'
   PRINT '@nSuccess = ' + CAST(@nSuccess AS NVARCHAR(2))
   PRINT '@c_ErrMsg = ' + @cErrorMsg
END
-- End Procedure


GO