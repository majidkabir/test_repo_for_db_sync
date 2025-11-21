SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: isp_OTM_Interface_Check                             */                                                                                  
/* Creation Date:                                                       */                                                                                  
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
/* Date         Author    Ver.  Purposes                                */    
/* 26-Jun-2018  Shong     1.1   Cater Multiple Param Group with Facility*/ 
/* 12-Jul-2018  Wan01     1.1   Fixed conditionlevel to close ')' issue */                                                                               
/************************************************************************/                                                                                  
CREATE PROC [dbo].[isp_OTM_Interface_Check]
   @c_StorerKey             NVARCHAR(15),
   @n_OTMLogKey             BIGINT, 
   @c_ParmType              NVARCHAR(20),                                                                                                                    
   @b_Success               INT = 0          OUTPUT,                                                                                                      
   @c_ErrorMsg              NVARCHAR(255)    OUTPUT,                                                                                                      
   @b_Debug                 INT = 0                                                                                                                                                                                
AS      
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          

   --SET @b_Debug = 1
             
   DECLARE @b_InValid             BIT,
         @c_BuildParmKey          NVARCHAR(10),                                                                                                                    
         @c_Facility              NVARCHAR(5),
         @c_BatchNo               NVARCHAR(10) = '',
         @c_SQLSelect             NVARCHAR(MAX) = ''                                                                                                                                       
          
   DECLARE @c_TableName NVARCHAR(200),
           @c_Value NVARCHAR(250),
           @c_ColumnName NVARCHAR(250),
           @c_CondLevel NVARCHAR(10),
           @c_ColName NVARCHAR(128),
           @c_ColType NVARCHAR(128),
           @n_err INT,
           @c_OrAnd NVARCHAR(10),
           @c_Operator NVARCHAR(10),
           @n_TotalOrders INT,
           @n_TotalOpenQty INT,
           @n_MaxOrders INT,
           @n_MaxOpenQty INT,
           @n_PreCondLevel INT,
           @n_CurrCondLevel INT,
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
           @c_SQL NVARCHAR(MAX),
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
            
   DECLARE @c_SortBy    NVARCHAR(2000),
           @c_SortSeq   NVARCHAR(10),
           @c_CondType  NVARCHAR(10),
           @c_SQLField  NVARCHAR(2000),
           @c_SQLWhere  NVARCHAR(2000),
           @c_SQLGroup  NVARCHAR(2000),
           @c_SQLCond   NVARCHAR(4000),
           @c_SQLDYN01  NVARCHAR(MAX),
           @n_cnt       INT,
           @c_GroupFlag NVARCHAR(1),
           @c_Field01   NVARCHAR(60),
           @c_Field02   NVARCHAR(60),
           @c_Field03   NVARCHAR(60),
           @c_Field04   NVARCHAR(60),
           @c_Field05   NVARCHAR(60),
           @c_Field06   NVARCHAR(60),
           @c_Field07   NVARCHAR(60),
           @c_Field08   NVARCHAR(60),
           @c_Field09   NVARCHAR(60),
           @c_Field10   NVARCHAR(60),
           
           @n_StartTranCnt     INT,
           @c_Orderkey         NVARCHAR(10),
           @c_GroupBySortField NVARCHAR(2000)                                                                                              
          
   DECLARE @c_AutoUpdLoadDefaultStorerStrg NVARCHAR(10),
           @c_AutoUpdSuperOrderFlag        NVARCHAR(10),                                                                                                               
           @c_FacilitySelect               NVARCHAR(MAX) = ''
           
   DECLARE @t_TraceInfo TABLE(
           TraceName    NVARCHAR(160),
           TimeIn       DATETIME,
           [TIMEOUT]    DATETIME,
           TotalTime    NVARCHAR(40),
           Step3        NVARCHAR(40),
           Step4        NVARCHAR(40),
           Step5        NVARCHAR(40),
           Col1         NVARCHAR(40),
           Col2         NVARCHAR(40),
           Col3         NVARCHAR(40),
           Col4         NVARCHAR(40),
           Col5         NVARCHAR(40)
           )                                                                                                                                            

   SET @n_err = 0                                                                                                                                              
   SET @b_InValid = 0                                                                                                                                           
   SET @c_ErrorMsg = ''                                                                                                                                         
   SET @b_Success = 1                                                                                                                                           
   SET @n_TotalOrders = 0                                                                                                                                       
   SET @n_TotalOpenQty = 0                                                                                                                                      
   SET @n_PreCondLevel = 0                                                                                                                                      
   SET @n_CurrCondLevel = 0                                                                                                                                     
   SET @c_LoadKey = ''                                                                                                                                         
   SET @n_MaxOrders = 0                                                                                                                                         
   SET @n_MaxOpenQty = 0                                                                                                                                        
   SET @n_sNum = 1                                                                                                                                             
   SET @d_StartTime = GETDATE()                                                                                                                                
   SET @c_UserName = RTRIM(SUSER_SNAME())                                                                                                                      
   SET @n_StartTranCnt = @@TRANCOUNT   
   SET @d_StartBatchTime = GETDATE()              
   SET @b_GetBatchNo = 1                      
   SET @n_LoadplanCnt = 0                                                                                                                                      
  
   DECLARE @c_OTMLOG_TableName   NVARCHAR(30) = '',
           @c_OTMLOG_Key1        NVARCHAR(20) = '',
           @c_OTMLOG_Key2        NVARCHAR(5 ) = '',
           @c_BaseTable          NVARCHAR(30) = '',
           @c_PhysicalTableName  NVARCHAR(60) = '',
           @c_FieldName1         NVARCHAR(60) = '',
           @c_FieldName2         NVARCHAR(60) = ''

   IF @b_Debug = 1
   BEGIN
      PRINT '>> OTMLOGKey: ' + CAST(@n_OTMLogKey AS VARCHAR(10)) 
   END
         
   SET @c_OTMLOG_TableName = '' 
   SELECT @c_OTMLOG_TableName = o.Tablename, 
          @c_OTMLOG_Key1 = o.Key1, 
          @c_OTMLOG_Key2 = o.Key2
   FROM OTMLOG AS o WITH(NOLOCK)
   WHERE o.OTMLOGKey = @n_OTMLogKey 
   
   IF @c_OTMLOG_TableName = ''
   BEGIN
      SET @b_Success = 0
      SET @c_ErrorMsg = 'OTMLogKey Not Found!'
       
      GOTO QUIT 	
   END
   
   SET @c_PhysicalTableName = ''
   SELECT @c_PhysicalTableName = PhysicalTableName, 
          @c_FieldName1 = Key1, 
          @c_FieldName2 = Key2 
   FROM V_OTM_Table_Mapping 
   WHERE TableName = @c_OTMLOG_TableName
   IF @c_PhysicalTableName = ''
   BEGIN
      SET @b_Success = 0
      SET @c_ErrorMsg = 'Table Name: ' + @c_OTMLOG_TableName + ', NOT IN V_OTM_Table_Mapping'
       
      GOTO QUIT 	
   END   	
	SET @c_SQLSelect = N' FROM ' + @c_PhysicalTableName + ' WITH (NOLOCK) ' + CHAR(13) + 
	                   N' JOIN OTMLOG WITH (NOLOCK) ON OTMLOG.Key1 = ' +  RTRIM(@c_PhysicalTableName) + '.' + LTRIM(@c_FieldName1)  
	   	   
   SELECT @c_SQLField   = '',
          @c_SQLWhere   = '',
          @c_SQLGroup   = '',
          @n_cnt        = 0,
          @c_GroupFlag  = 'N',
          @c_SQLCond    = ''                                                

   IF OBJECT_ID('tempdb..#TABLES') IS NULL
   BEGIN
	   CREATE TABLE #TABLES (TableName VARCHAR(200)) 
   END

   -- Cater Facility Setting  
   SET @c_Facility = ''  
   SET @c_FacilitySelect = '' 
   IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_NAME  = @c_PhysicalTableName
             AND COLUMN_NAME = 'Facility')
   BEGIN
   	SET @c_FacilitySelect = N'SELECT @c_Facility = ISNULL(' + @c_PhysicalTableName + '.Facility,'''') ' + CHAR(13) + 
   	                        @c_SQLSelect + CHAR(13) + 
   	                        N' WHERE OTMLOG.OTMLOGKey = @n_OTMLogKey ' 
   	                        
      EXEC sp_ExecuteSQL @c_FacilitySelect, N' @c_Facility NVARCHAR(5) OUTPUT, @n_OTMLogKey BIGINT ',  @c_Facility OUTPUT, @n_OTMLogKey 
      
      IF @b_Debug = 1
      BEGIN
      	PRINT '>> Facility Select '
      	PRINT @c_FacilitySelect 
      END
   END
   
   SET @c_ParmGroup = ''
   IF @c_Facility <> ''
   BEGIN
      SELECT @c_ParmGroup = ISNULL(RTRIM(B.ParmGroup), '')
      FROM BUILDPARMGROUPCFG AS b WITH(NOLOCK) 
      WHERE b.Storerkey = @c_StorerKey 
      AND   b.[Type] = @c_ParmType      
      AND   b.Facility = @c_Facility
         	
   END
   
   IF @c_ParmGroup = ''    
   BEGIN
      SELECT @c_ParmGroup = ISNULL(RTRIM(B.ParmGroup), '')
      FROM BUILDPARMGROUPCFG AS b WITH(NOLOCK) 
      WHERE b.Storerkey = @c_StorerKey 
      AND  (b.Facility = '' OR b.Facility IS NULL)
      AND   b.[Type] = @c_ParmType         	
   END

   
   IF @c_ParmGroup = ''
   BEGIN
	   SET @b_Success = 1
	   SET @c_ErrorMsg = 'Type:' + @c_ParmType + ' Not Exists in BuildParmGroupCfg'
	   GOTO QUIT   
   END   
   
   IF @b_Debug=1
   BEGIN
   	PRINT '>> Storer: ' + @c_StorerKey + ', Facility: ' + @c_Facility 
   	PRINT '>> ParmGroup: ' + @c_ParmGroup 
   END
   
   SET @c_BuildParmKey = ''
   SELECT @c_BuildParmKey = b.BuildParmKey
   FROM BUILDPARM AS b WITH(NOLOCK)
   WHERE b.ParmGroup = @c_ParmGroup       
     AND b.[Active] = '1'      
   IF @c_BuildParmKey = ''
   BEGIN
	   SET @b_Success = 1
	   SET @c_ErrorMsg = 'ParmGroup:' + @c_ParmGroup + ' Not Exists in BuildParm'
	   GOTO QUIT      
   END   
                                                                                                                               
   INSERT INTO #TABLES(	TableName )
   SELECT DISTINCT LEFT(FieldName, CHARINDEX('.', FieldName) - 1)
   FROM   BUILDPARMDETAIL WITH (NOLOCK)
   WHERE  BuildParmKey = @c_BuildParmKey
   AND    [Type] = 'CONDITION'
   AND    CHARINDEX('.', FieldName) > 0 

   DECLARE @n_Seq       INT = 0 

   DECLARE CUR_TABLENAME CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  CASE TableName 
               WHEN 'ORDERS' THEN 1 
               WHEN 'ORDERDETAIL' THEN 2
               WHEN 'RECEIPT' THEN 1
               WHEN 'RECEIPTDETAIL' THEN 2
               WHEN 'LOADPLANDETAIL' THEN 3             
               WHEN 'LOADPLAN' THEN 4
               WHEN 'MBOLDETAIL' THEN 5             
               WHEN 'MBOL' THEN 6
               WHEN 'SKU' THEN 7
               ELSE 99 
           END AS Seq, TableName                           
   FROM #TABLES 
   WHERE TableName <> @c_PhysicalTableName 
   ORDER BY Seq

   OPEN CUR_TABLENAME

   FETCH FROM CUR_TABLENAME INTO @n_Seq, @c_TableName

   WHILE @@FETCH_STATUS = 0
   BEGIN	
      IF @c_TableName = 'ORDERDETAIL' AND @c_PhysicalTableName = 'ORDERS'
	   BEGIN
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) +	N' JOIN ORDERDETAIL WITH (NOLOCK) ON  ORDERS.OrderKey = ORDERDETAIL.OrderKey '	 		
	   END
	   ELSE IF @c_TableName = 'RECEIPTDETAIL' AND @c_PhysicalTableName = 'RECEIPT'
	   BEGIN
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN RECEIPTDETAIL WITH (NOLOCK) ON  RECEIPT.ReceiptrKey = RECEIPTDETAIL.ReceiptrKey '  		
	   END
	   ELSE IF @c_TableName IN ('ORDERS') AND @c_PhysicalTableName = 'LOADPLAN'
	   BEGIN
		   IF NOT EXISTS(SELECT 1 FROM #TABLES WHERE TableName ='LOADPLANDETAIL' )
		      SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey '
		   
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey '  		
	   END   		
	   ELSE IF @c_TableName IN ('LOADPLANDETAIL') AND @c_PhysicalTableName = 'LOADPLAN'
	   BEGIN
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey ' 
	   END   	
	   ELSE IF @c_TableName IN ('MBOLDETAIL') AND @c_PhysicalTableName = 'ORDERS'
	   BEGIN
		   IF NOT EXISTS(SELECT 1 FROM #TABLES WHERE TableName ='MBOLDETAIL' )
		      SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN MBOLDETAIL WITH (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey ' 
		   
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN MBOL WITH (NOLOCK) ON MBOL.MBOLKey = ORDERS.MBOLKEY '  
	   END   		
	   ELSE IF @c_TableName IN ('MBOLDETAIL') AND @c_PhysicalTableName = 'MBOL'
	   BEGIN
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN MBOLDETAIL WITH (NOLOCK) ON MBOLDETAIL.MBOLKey = MBOL.MBOLKey ' 
	   END   	
	   ELSE IF @c_TableName IN ('ORDERS') AND @c_PhysicalTableName = 'MBOL'
	   BEGIN
	   	IF NOT EXISTS(SELECT 1 FROM #TABLES WHERE TableName ='MBOLDETAIL' )
		      SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN MBOLDETAIL WITH (NOLOCK) ON MBOLDETAIL.MBOLKey = MBOL.MBOLKey '
		       
		   SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = MBOLDETAIL.OrderKey ' 
	   END   		   	   	
	   FETCH FROM CUR_TABLENAME INTO @n_Seq, @c_TableName
   END

   CLOSE CUR_TABLENAME
   DEALLOCATE CUR_TABLENAME

	SET @c_SQLSelect = @c_SQLSelect + CHAR(13) + N' WHERE OTMLOG.OTMLOGKey = @n_OTMLogKey '
	                            
   DECLARE CUR_OTM_FILTER_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT FieldName ,
            [Value],
            ConditionLevel,
            [OrAnd],
            LTRIM(RTRIM([Operator])) 
      FROM   BUILDPARMDETAIL WITH (NOLOCK)
      WHERE  BuildParmKey = @c_BuildParmKey
         AND [Type] = 'CONDITION'
      ORDER BY BuildParmLineNo                                                                                                                                                
          
   OPEN CUR_OTM_FILTER_COND                                                                                                                                    
          
   FETCH NEXT FROM CUR_OTM_FILTER_COND INTO @c_ColumnName, @c_Value, @c_CondLevel, @c_OrAnd, @c_Operator                                                            
          
   WHILE @@FETCH_STATUS <> -1
   BEGIN
       IF ISNUMERIC(@c_CondLevel) = 1
       BEGIN
           IF @n_PreCondLevel = 0
               SET @n_PreCondLevel = CAST(@c_CondLevel AS INT)
        
           SET @n_CurrCondLevel = CAST(@c_CondLevel AS INT)
       END 
    
       -- Get Column Type                                                                                                                                       
       SET @c_TableName = LEFT(@c_ColumnName, CHARINDEX('.', @c_ColumnName) - 1)                                                                                   
       SET @c_ColName = SUBSTRING(
               @c_ColumnName,
               CHARINDEX('.', @c_ColumnName) + 1,
               LEN(@c_ColumnName) - CHARINDEX('.', @c_ColumnName)
           )                                                            
    
       SET @c_ColType = ''                                                                                                                                       
       SELECT @c_ColType = DATA_TYPE
       FROM  INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_NAME  = @c_TableName
         AND COLUMN_NAME = @c_ColName                                                                                                                           
    
       IF ISNULL(RTRIM(@c_ColType), '') = ''
       BEGIN
           SET @b_InValid = 1                                                                                                                                     
           SET @c_ErrorMsg = 'Invalid Column Name: ' + @c_ColumnName 
           GOTO QUIT
       END    
    
       IF @c_ColType = 'datetime' AND ISDATE(@c_Value) <> 1
       BEGIN                                                                                                                                        
           IF @c_Value IN ('today', 'now', 'startofmonth', 'endofmonth','startofyear', 'endofyear')
              OR LEFT(@c_Value, 6) IN ('today+', 'today-') --NJOW06
           BEGIN
               SET @c_Value = 
                   CASE 
                      WHEN @c_Value = 'today' THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                      WHEN LEFT(@c_Value, 6) IN ('today+', 'today-') AND 
                           ISNUMERIC(SUBSTRING(@c_Value, 7, 10)) = 1 --NJOW06
                            THEN LEFT(
                               CONVERT(
                                   VARCHAR(30),
                                   DATEADD(DAY, CONVERT(INT, SUBSTRING(@c_Value, 6, 10)), GETDATE()),
                                   120
                               ),
                               10
                           )
                      WHEN @c_Value = 'now' THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                      WHEN @c_Value = 'startofmonth' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                           + '-' 
                           + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) 
                           + ('-01')
                      WHEN @c_Value = 'endofmonth' THEN CONVERT(
                               VARCHAR(30),
                               DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, GETDATE()) + 1, 0)),
                               120
                           )
                      WHEN @c_Value = 'startofyear' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                           + '-01-01'
                      WHEN @c_Value = 'endofyear' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) 
                           + '-12-31 23:59:59'
                      ELSE LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10) --NJOW06
                   END
           END
           ELSE
           BEGIN
               SET @b_InValid = 1                                                                                                                                  
               SET @c_ErrorMsg = 'Invalid Date Format: ' + @c_Value 
               GOTO QUIT
           END
       END    
    
       IF @n_PreCondLevel < @n_CurrCondLevel
       BEGIN
           SET @c_SQLCond = @c_SQLCond + ' ' + MASTER.dbo.fnc_GetCharASCII(13) +
               ' ' + @c_OrAnd + N' ('
        
           SET @n_PreCondLevel = @n_CurrCondLevel
       END
       ELSE 
       IF @n_PreCondLevel > @n_CurrCondLevel
       BEGIN
           SET @c_SQLCond = @c_SQLCond + N') ' + MASTER.dbo.fnc_GetCharASCII(13) +
               ' ' + @c_OrAnd
        
           SET @n_PreCondLevel = @n_CurrCondLevel
       END
       ELSE
       BEGIN
           SET @c_SQLCond = @c_SQLCond + ' ' + MASTER.dbo.fnc_GetCharASCII(13) +
               ' ' + @c_OrAnd
       END    
    
       IF @c_ColType IN ('char', 'nvarchar', 'varchar')
       BEGIN
          SET @c_SQLCond = @c_SQLCond + ' ' + @c_ColumnName + ' ' + @c_Operator +
              CASE WHEN @c_Operator IN ('IN', 'NOT IN') THEN --NJOW01                                                                                                     
                      CASE 
                           WHEN LEFT(RTRIM(LTRIM(@c_Value)), 1) <> '(' THEN ' ('
                           ELSE ''
                      END +
                      RTRIM(LTRIM(@c_Value)) +
                      CASE 
                           WHEN RIGHT(RTRIM(LTRIM(@c_Value)), 1) <> ')' THEN ' ) '
                           ELSE ''
                      END
                   ELSE ' N' +
                      CASE 
                           WHEN LEFT(RTRIM(LTRIM(@c_Value)), 1) <> '''' THEN ''''
                           ELSE ''
                      END +
                      RTRIM(LTRIM(@c_Value)) +
                      CASE 
                           WHEN RIGHT(RTRIM(LTRIM(@c_Value)), 1) <> '''' THEN 
                                ''' '
                           ELSE ''
                      END
              END    	
       END
       ELSE 
       IF @c_ColType IN ('float', 'money', 'int', 'decimal', 'numeric', 'tinyint', 
                       'real', 'bigint')
           SET @c_SQLCond = @c_SQLCond + ' ' + @c_ColumnName + ' ' + @c_Operator +
               RTRIM(@c_Value)
       ELSE 
       IF @c_ColType IN ('datetime')
           SET @c_SQLCond = @c_SQLCond + ' ' + @c_ColumnName + ' ' + @c_Operator +
               ' ''' + @c_Value + ''' '
    
       FETCH NEXT FROM CUR_OTM_FILTER_COND INTO @c_ColumnName, @c_Value, @c_CondLevel, 
       @c_OrAnd, @c_Operator
   END -- Cursor  CUR_OTM_FILTER_COND      
   CLOSE CUR_OTM_FILTER_COND                                                                                                                                   
   DEALLOCATE CUR_OTM_FILTER_COND                                                                                                                              

   WHILE @n_PreCondLevel > 1  --(Wan01) 
   BEGIN
       SET @c_SQLCond = @c_SQLCond + N') '                                                                                                                      
       SET @n_PreCondLevel = @n_PreCondLevel - 1
   END

   IF @c_SQLCond <> ''
   BEGIN
	   SET @c_SQLSelect = ISNULL(RTRIM(@c_SQLSelect),'') + @c_SQLCond	   
	   
   END       
   
   START_CHECK:
   DECLARE 
   	  @n_CheckCnt        INT = 0 
   
   SET @c_SQLSelect = N'SELECT @n_CheckCnt = COUNT(1) ' + CHAR(13) + ISNULL(RTRIM(@c_SQLSelect),'')
   
   IF @b_Debug = 1
   BEGIN
   	PRINT ''
   	PRINT '---- SQL Statement ----'
   	PRINT @c_SQLSelect
   	PRINT ''
   END
   
   BEGIN TRY
       EXEC sp_ExecuteSQL @c_SQLSelect, N' @n_CheckCnt INT = 0 OUTPUT, @n_OTMLogKey BIGINT', @n_CheckCnt OUTPUT, @n_OTMLogKey   	
   END TRY
   BEGIN CATCH
   	IF @b_Debug = 1
   	BEGIN
   		SELECT
   			ERROR_NUMBER() AS ErrorNumber,
   			ERROR_SEVERITY() AS ErrorSeverity,
   			ERROR_STATE() AS ErrorState, 
   			ERROR_LINE() AS ErrorLine,
   			ERROR_MESSAGE() AS ErrorMessage   		
   	END 
   	SET @b_Success = 0
   	SET @c_ErrorMsg = 'Execute SQL Failed! '
   	GOTO QUIT
   END CATCH
  
   IF @b_Debug = 1
   BEGIN
   	PRINT '>>> @n_CheckCnt =' + CAST(@n_CheckCnt AS VARCHAR(10))
   END
   	   
   IF @n_CheckCnt = 0
   BEGIN
   	SET @b_Success = 0   	
   	
   	GOTO QUIT 
   END
   ELSE 
   BEGIN
   	SET @b_Success = 1
   END
	                      
                                                                                                                                               
   SET @b_SPProcess = 0                                                                                                                                        
   DECLARE CUR_OTM_FILTER_SP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT [Value]
      FROM   BUILDPARMDETAIL WITH (NOLOCK)
      WHERE  BuildParmKey = @c_BuildParmKey
      AND    [Type] = 'STOREDPROC'
      ORDER BY BuildParmLineNo 
                                                                                                                                                                   
   OPEN CUR_OTM_FILTER_SP                                                                                                                                      
          
   FETCH NEXT FROM CUR_OTM_FILTER_SP INTO @c_ExecSPSQL                                                                                                         
          
   WHILE @@FETCH_STATUS <> -1
   BEGIN
       IF @c_ExecSPSQL <> ''
       BEGIN
           SET @c_SPName = @c_ExecSPSQL                                                                                                                          
           SET @n_idx = CHARINDEX(' ', @c_ExecSPSQL, 1)                                                                                                           
           IF @n_idx > 0
           BEGIN
               SET @c_SPName = SUBSTRING(@c_ExecSPSQL, 1, @n_idx - 1)
           END 
        
           IF @c_SQLCond <> ''
           BEGIN
               SET @c_ParmCodeCond = @c_SQLCond                                                                                                                   
               SET @c_ParmCodeCond = REPLACE(@c_ParmCodeCond, 'N''', 'N''''')                                                                                      
               SET @c_ParmCodeCond = REPLACE(@c_ParmCodeCond, ''' ', ''''' ')
           END 
        
           IF RIGHT(@c_ParmCodeCond, 1) = ''''
           BEGIN
               SET @c_ParmCodeCond = @c_ParmCodeCond + ''''
           END 
        
           SET @c_ExecSPSQL = RTRIM(@c_ExecSPSQL) 

           SET @b_Success = 0 
           SET @c_ErrorMsg = ''
           BEGIN TRY
              EXEC sp_ExecuteSQL @c_ExecSPSQL, 
                  N'@c_StorerKey NVARCHAR(15), @n_OTMLogKey BIGINT, @b_Success OUTPUT, @c_ErrorMsg NVARCHAR(255) OUTPUT, @b_Debug INT'
                   ,@c_StorerKey 
                   ,@n_OTMLogKey  
                   ,@b_Success  OUTPUT      
                   ,@c_ErrorMsg OUTPUT                                                               
                   ,@b_Debug                	
           END TRY
           BEGIN CATCH
   	         IF @b_Debug = 1
   	         BEGIN
   		         SELECT
   			         ERROR_NUMBER() AS ErrorNumber,
   			         ERROR_SEVERITY() AS ErrorSeverity,
   			         ERROR_STATE() AS ErrorState, 
   			         ERROR_LINE() AS ErrorLine,
   			         ERROR_MESSAGE() AS ErrorMessage   		
   	         END 
   	         SET @b_Success = 0
   	         SET @c_ErrorMsg = 'Execute SP ' + @c_ExecSPSQL + ' Failed! '
   	         GOTO QUIT
           END CATCH
                                                                                                        
        
           IF ISNULL(RTRIM(@c_ErrorMsg),'') <> ''
           BEGIN
               SET @b_InValid = 1                                                                                                                                  
               SET @c_ErrorMsg = 'ERROR Executing Stored Procedure: ' + RTRIM(@c_SPName) 
                   + '. (isp_OTM_Interface_Check) Error Msg:' + @c_ErrorMsg 
            
               GOTO QUIT
           END         
       END
    
       FETCH NEXT FROM CUR_OTM_FILTER_SP INTO @c_ExecSPSQL
   END       
   CLOSE CUR_OTM_FILTER_SP                                                                                                                                     
   DEALLOCATE CUR_OTM_FILTER_SP                                                                                                                                
               

   QUIT:
          
   IF @b_Debug = 1
   BEGIN
   	 PRINT ''
       PRINT 'SP-isp_OTM_Interface_Check DEBUG-STOP...'
       PRINT  '-----------------------------------------'
       PRINT '@b_Success = ' + CAST(@b_Success AS NVARCHAR(2)) 
       PRINT '@c_ErrMsg = ' + @c_ErrorMsg
   END
END -- End Procedure     

GO