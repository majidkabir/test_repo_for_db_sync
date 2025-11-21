SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_AutoBackendAllocation                          */  
/* Creation Date:                                                       */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.7 (Unicode)                                          */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Rev   Purposes                                  */  
/* 05-Sep-2017  Shong   1.1   Reallocate Order after one hour           */  
/* 21-Sep-2017  Shong   1.2   Enhancement                               */  
/* 25-Sep-2017  Shonh   1.3   Exclude Order# in AutoAllocBatchDetail    */  
/*                            with status = 0                           */    
/* 20-Oct-2017  Shong   1.4   Bug Fixing                                */  
/* 01-Nov-2017  Shong   1.5   Filter Facility parameter = BLANK         */  
/* 18-Apr-2018  Shong   1.6   Enhancement                               */  
/* 27-JUL-2018  Wan01   1.7   Insert BatchJob After Detail inserted     */  
/* 23-Aug-2018  Shong   1.8   Change Begin & Commit Tran                */  
/* 16-jUN-2019  NJOW01  1.9   618 Fix re-submit to create duplicate     */
/*                            order in AutoallocBatchDetail table       */
/* 20-DEC-2021  NJOW02  2.0   WMS-18620 Support sorting configuration   */
/*                            for orders table                          */
/* 20-DEC-2021  NJOW02  2.0   DEVOPS combine script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_AutoBackendAllocation] (   
     @cParameterCode NVARCHAR(10) = ''  
   , @bSuccess       INT = 1            OUTPUT  
   , @nErr           INT = ''           OUTPUT  
   , @cErrMsg        NVARCHAR(250) = '' OUTPUT    
   , @bDebug         INT = 0   
   , @cStartOrderKey NVARCHAR(10) = ''  
   , @cEndOrderKey   NVARCHAR(10) = ''  
     
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
       
   DECLARE @cStorerKey            NVARCHAR(15),  
           @cFacility             NVARCHAR(5),  
           @cBL_ParamGroup        NVARCHAR(30),  
           @cBL_ParameterCode     NVARCHAR(10),  
           @cBL_ParmDesc          NVARCHAR(60),  
           @cBL_AllocStrategy     NVARCHAR(60),   
           @cBL_BatchSize         NVARCHAR(60),   
           @nSuccess              INT,      
           @cSQLSelect            NVARCHAR(MAX),  
           @cSQLCondition         NVARCHAR(MAX),                 
           @cBatchNo              NVARCHAR(10),   
           @nWherePosition        INT,   
           @nGroupByPosition      INT,   
           @cSQLParms             NVARCHAR(1000),  
           @nAllocBatchNo         BIGINT,   
           @nOrderCnt             INT,   
           @cSKU                  NVARCHAR(20),   
           @nPrevAllocBatchNo     BIGINT,   
           @dOrderAddDate         DATETIME,  
           @cCommand              NVARCHAR(2014),   
           @cAllocBatchNo         NVARCHAR(10),   
           @nNextAllocBatchNo     BIGINT,    
           @nBL_Priority          INT = 0,   
           @nTaskSeqNo            INT = 0,   
           @nRowID                INT = 0,  
           @nBatchCount           INT = 0,   
           @nMaxBatchCount        INT = 5,   
           @n_TotalSKU            INT = 0,  
           @n_AllocatedSKU        INT = 0,   
           @b_NewTmpOrders        INT = 0,  
           @b_SPProcess           BIT = 0,   
           @c_SPName              NVARCHAR(500) = '',  
           @n_Idx                 INT = 0,   
           @n_TempOrderCount      INT = 0   
  
   DECLARE @c_APP_DB_Name         NVARCHAR(20)  
         , @c_DataStream            VARCHAR(10)  
         , @n_ThreadPerAcct         INT   
         , @n_ThreadPerStream       INT   
         , @n_MilisecondDelay       INT   
         , @c_IP                    NVARCHAR(20)  
         , @c_PORT                  NVARCHAR(5)  
         , @c_IniFilePath           NVARCHAR(200)  
         , @c_CmdType               NVARCHAR(10)           
         , @c_TaskType              NVARCHAR(1)  
         , @c_ExecSPSQL             NVARCHAR(4000)      
         , @cMax_SKU_Per_Order      NVARCHAR(1000)    
  
   DECLARE @n_SafetyAllocateOrderCtn INT = 0   
         , @n_TaskPriorityByStorer   INT = 0  
  
   --(Wan01) - START  
   DECLARE @nPriority    INT = 9  
          ,@cStrategyKey NVARCHAR(20) = ''  
          ,@nTotalQty    INT = 0   
         , @n_StartTCnt  INT = @@TRANCOUNT       
   --(Wan01) - END  
   
   --NJOW02
   DECLARE @n_spos INT
          ,@c_Sort NVARCHAR(2000)
              
      SELECT @c_APP_DB_Name         = APP_DB_Name  
           , @c_DataStream          = DataStream   
           , @n_ThreadPerAcct       = ThreadPerAcct   
           , @n_ThreadPerStream     = ThreadPerStream   
           , @n_MilisecondDelay     = MilisecondDelay   
           , @c_IP                  = IP  
           , @c_PORT                = PORT  
           , @c_IniFilePath         = IniFilePath  
           , @c_CmdType             = CmdType               
           , @c_TaskType            = TaskType              
      FROM  QCmd_TransmitlogConfig WITH (NOLOCK)  
      WHERE TableName               = 'BACKENDALLOC'  
      AND   [App_Name]              = 'WMS'  
      AND   StorerKey               = 'ALL'   
  
   IF OBJECT_ID('tempdb..#StorerWIP') IS NOT NULL  
      DROP TABLE #StorerWIP  
  
   CREATE TABLE #StorerWIP (StorerKey NVARCHAR(15), Facility NVARCHAR(5), NoOfOrders INT)  
  
   IF OBJECT_ID('tempdb..#AllocBatch') IS NOT NULL  
      DROP TABLE #AllocBatch       
        
   CREATE TABLE #AllocBatch (AllocBatchNo BIGINT   PRIMARY KEY)  
  
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL    
   BEGIN                                                                                                                                        
      CREATE TABLE #TMP_ORDERS ( OrderKey NVARCHAR(10) )     
      SET @b_NewTmpOrders = 1                                                                                                                                                          
   END   
     
   INSERT INTO #StorerWIP(StorerKey, Facility, NoOfOrders)  
   SELECT o.StorerKey, o.Facility, COUNT(*)   
   FROM AutoAllocBatchDetail aabd (NOLOCK)   
   JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = aabd.OrderKey   
   WHERE o.[Status] IN ('0','1')   
   AND   aabd.[Status] IN ('0','1')             --(Wan01)  
   GROUP BY o.StorerKey, o.Facility   
  
   IF @cParameterCode = ''  
   BEGIN  
      DECLARE C_BuiLoadParameters CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
          SELECT VH.StorerKey,  
                 VH.Facility,  
                 VH.BL_ParamGroup,  
                 VH.BL_ParameterCode,  
                 VH.BL_ParmDesc,  
                 CASE WHEN ISNUMERIC(VH.BL_Priority) = 1 THEN CAST(BL_Priority AS INT) ELSE 99 END ,  
                 VH.BL_AllocStrategy,   
                 VH.BL_BatchSize                 
          FROM  V_Build_Load_Parm_Header VH   
          WHERE VH.BL_ActiveFlag = '1'   
          AND   VH.[BL_BuildType] = 'BACKENDALLOC'   
          AND   VH.Facility <> ''   
          ORDER BY CASE WHEN ISNUMERIC(VH.BL_Priority) = 1 THEN CAST(BL_Priority AS INT) ELSE 99 END, VH.BL_ParamGroup, VH.BL_ParameterCode       
   END    
   ELSE   
   BEGIN  
      DECLARE C_BuiLoadParameters CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
          SELECT VH.StorerKey,  
                 VH.Facility,  
                 VH.BL_ParamGroup,  
                 VH.BL_ParameterCode,  
                 VH.BL_ParmDesc,  
                 CASE WHEN ISNUMERIC(VH.BL_Priority) = 1 THEN CAST(BL_Priority AS INT) ELSE 99 END ,  
                 VH.BL_AllocStrategy,   
                 VH.BL_BatchSize                 
          FROM  V_Build_Load_Parm_Header VH   
          WHERE VH.BL_ActiveFlag = '1'   
          AND   VH.[BL_BuildType] = 'BACKENDALLOC'   
          AND   VH.Facility <> ''  
          AND VH.BL_ParameterCode = @cParameterCode    
          ORDER BY CASE WHEN ISNUMERIC(VH.BL_Priority) = 1 THEN CAST(BL_Priority AS INT) ELSE 99 END, VH.BL_ParamGroup, VH.BL_ParameterCode       
   END  
       
   OPEN C_BuiLoadParameters  
  
   FETCH FROM C_BuiLoadParameters INTO @cStorerKey, @cFacility, @cBL_ParamGroup,  
                             @cBL_ParameterCode, @cBL_ParmDesc, @nBL_Priority,  
                             @cBL_AllocStrategy, @cBL_BatchSize   
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN   
      SET @n_SafetyAllocateOrderCtn = 5000   
      SET @n_TaskPriorityByStorer = 99  
        
      SELECT @n_SafetyAllocateOrderCtn = CASE WHEN ISNUMERIC(Short) = 1 THEN CAST(c.Short AS INT) ELSE 5000 END   
      FROM CODELKUP AS c WITH(NOLOCK)  
      WHERE c.LISTNAME = 'AUTOALLOC'  
      AND c.Storerkey = @cStorerKey  
      AND c.Notes = @cFacility  
        
      IF EXISTS(SELECT 1 FROM #StorerWIP  
                WHERE StorerKey = @cStorerKey   
                AND   Facility = @cFacility   
                AND   NoOfOrders > @n_SafetyAllocateOrderCtn)  
      BEGIN  
         GOTO FETCH_NEXT  
      END  
       
      SET @nBatchCount = 0   
      SELECT @nBatchCount = COUNT(*)   
      FROM AutoAllocBatch AS aab WITH(NOLOCK)    
      WHERE aab.Storerkey = @cStorerKey   
      AND   aab.Facility = @cFacility   
      AND   aab.BuildParmGroup =  @cBL_ParamGroup   
      AND   aab.BuildParmCode =   @cBL_ParameterCode  
      AND   aab.[Status] <> '9'  
      AND   EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH(NOLOCK)   
                   WHERE aabd.AllocBatchNo = aab.AllocBatchNo)   
                     
      IF @nBatchCount >= @nMaxBatchCount   
         GOTO FETCH_NEXT  
        
      EXEC dbo.isp_Gen_BuildLoad_Select   
           @cParmCode  = @cBL_ParameterCode,   
           @cFacility  = @cFacility,   
           @cStorerKey = @cStorerKey,  
           @nSuccess   = @nSuccess OUTPUT,   
           @cErrorMsg  = @cErrMsg OUTPUT,   
           @bDebug     = @bDebug,   
           @cSQLSelect = @cSQLSelect OUTPUT,      
           @cBatchNo   = @cBatchNo   
     
      SET @nWherePosition =  CHARINDEX(' FROM ', @cSQLSelect, 1)  
      SET @nGroupByPosition = CHARINDEX('GROUP BY',  @cSQLSelect, 1)  
     
      IF @nGroupByPosition = 0   
         SET @nGroupByPosition = LEN(@cSQLSelect)   
     
      SET @cSQLCondition = SUBSTRING( @cSQLSelect,  
                                       @nWherePosition,   
                                       @nGroupByPosition - @nWherePosition)   
     
      SET @cMax_SKU_Per_Order = ''  
        
      SELECT  @cMax_SKU_Per_Order = ' HAVING COUNT(DISTINCT ORDERDETAIL.SKU) ' + RTRIM(blpd.Condition) + ' ' + blpd.[Values]   
      FROM V_Build_Load_Parm_Detail AS blpd WITH(NOLOCK)  
      WHERE blpd.BL_ParameterCode = @cBL_ParameterCode   
      AND   blpd.FieldName= 'No_Of_SKU_In_Order'                               
      AND   blpd.[Type]='RESTRICT'                  
      
      --NJOW02    
      SET @c_Sort = ''
      SET @n_spos = 0
      SET @n_spos = CHARINDEX(') AS Number', @cSQLSelect, 1)
      IF @n_spos > 0 
      BEGIN
      	SET @c_Sort = LEFT(@cSQLSelect, @n_spos - 1)
      	SET @n_spos = CHARINDEX('ORDER BY', @c_Sort, 1)  
      	SET @c_Sort = SUBSTRING(@c_Sort, @n_spos + 8, LEN(@c_Sort))
      	IF CHARINDEX('ORDERS', @c_Sort, 1) = 0  --none order table
      	   OR CHARINDEX('ORDERS.[OrderKey]', @c_Sort, 1) > 0   --none custom sorting
      	   OR CHARINDEX('MIN(', @c_Sort, 1) > 0 --detail table 
      	   SET @c_Sort = '' --skip sort     	
      END                  
                               
      SET @nOrderCnt  = 0  
      SET @cSQLSelect = N'SELECT @nOrderCnt = COUNT(DISTINCT ORDERS.OrderKey) ' +   
                        N', @dOrderAddDate = MIN(ORDERS.AddDate) ' + @cSQLCondition 
      
      --NJOW01                    
      SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' OR ( ORDERS.OpenQty > 1 AND ORDERS.Status = ''1'' ) ) ' + CHAR(13) +  
                     CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +   
                     CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +              
                     N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +                        
                     N' WHERE aabd.OrderKey = ORDERS.OrderKey ) '    

      /*SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' OR ( ORDERS.OpenQty > 1 AND ORDERS.Status = ''1'' ) ) ' + CHAR(13) +  
                     CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +   
                     CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +              
                     N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +                        
                     N' JOIN AutoAllocBatch AS aab WITH (NOLOCK) ON aab.AllocBatchNo = aabd.AllocBatchNo ' + CHAR(13) +  
                     N' WHERE aabd.OrderKey = ORDERS.OrderKey ' + CHAR(13) +   
                     N' AND ( ( aabd.[Status] IN (''0'',''1'',''6'',''8'') ) ' + --(Wan01)       
                     N' OR ( aab.[Status] IN (''0'',''1'') ) ) ) '    */
           
  
      SET @cSQLParms  = N'@nOrderCnt NVARCHAR(10) OUTPUT, @dOrderAddDate DATETIME OUTPUT '   
  
      IF @bDebug = 1  
      BEGIN  
         PRINT ''  
         PRINT '> Paramater Code: ' + @cBL_ParameterCode  + ', Storer: ' + @cStorerKey + ', Facility: ' + @cFacility         
         PRINT  N'-----------------------------------------------------------------------'   
         PRINT  @cSQLSelect     
         PRINT  N'-----------------------------------------------------------------------'  
      END         
               
      BEGIN TRY  
         EXEC sp_executesql @cSQLSelect, @cSQLParms, @nOrderCnt OUTPUT, @dOrderAddDate OUTPUT        
      END TRY  
      BEGIN CATCH  
          SELECT @cErrMsg = ERROR_MESSAGE(),   
                 @nErr    = ERROR_NUMBER()        
  
          IF @bDebug = 1  
          BEGIN  
             PRINT  '@cErrorMsg: ' + @cErrMsg     
          END         
                                       
          EXEC [dbo].[nsp_LogError] @n_err = @nErr, @c_errmsg = @cErrMsg, @c_module = 'isp_AutoBackendAllocation'  
                     
          GOTO FETCH_NEXT   
      END CATCH   
        
      IF @nOrderCnt > 0   
      BEGIN  
         SET @b_SPProcess = 0                                                                                                                                          
         DECLARE CUR_BUILD_LOAD_SP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                                                                             
         SELECT ISNULL(Notes,'')                                                                                                                                       
         FROM   CODELKUP WITH (NOLOCK)                                                                                                                                 
         WHERE  ListName = @cBL_ParameterCode                                                                                                                                  
         AND    Short =  'STOREDPROC'                                                                                                                                  
         ORDER BY Code                                                                                                                                                 
                                                                                                                                                     
         OPEN CUR_BUILD_LOAD_SP                                                                                                                                        
                                                                                                                                                              
         FETCH NEXT FROM CUR_BUILD_LOAD_SP INTO @c_ExecSPSQL                                                                                                           
                                                                                                                                                              
         WHILE @@FETCH_STATUS <> -1                                                                                                                                    
         BEGIN                                     
            IF @c_ExecSPSQL <> ''                                                                                                                                      
            BEGIN                                                                                                                                                      
               SET @c_SPName = @c_ExecSPSQL                                                                            
               SET @n_Idx = CHARINDEX(' ',@c_ExecSPSQL, 1)                                                                                                             
               IF @n_Idx > 0                                                                                                                                           
               BEGIN                                                                                                                                    
                  SET @c_SPName = SUBSTRING(@c_ExecSPSQL,1, @n_Idx - 1)                                                                                                
               END  
                                                                                                                                                                    
               SET @c_ExecSPSQL = RTRIM(@c_ExecSPSQL)                                                                                                                  
                  + CASE WHEN CHARINDEX('@',@c_ExecSPSQL, 1) > 0  THEN ',' ELSE '' END   
                  + ' @c_Facility = @c_Facility'                                                                                                                     
                  + ',@c_Storerkey= @c_Storerkey'                                                            
                  + ',@c_ParmCode = @c_ParmCode'                                                         
                  + ',@c_ParmCodeCond = @c_SQLCond'                                              
  
               IF @bDebug = 1  
               BEGIN  
                  PRINT '>>> Stored Procedure: ' + @c_ExecSPSQL  
               END  
                 
               BEGIN TRY  
                  TRUNCATE TABLE #TMP_ORDERS  
                    
                  SET @n_TempOrderCount = 0   
                    
                  INSERT INTO #TMP_ORDERS                                                                                                                                 
                  EXEC sp_executesql @c_ExecSPSQL                                                                                 
                     , N'@c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15), @c_ParmCode NVARCHAR(10), @c_SQLCond NVARCHAR(4000)'   
                     ,@cFacility      
                     ,@cStorerKey    
                     ,@cBL_ParameterCode     
                     ,@cSQLCondition     
                    
                  SELECT @n_TempOrderCount = COUNT(*)  
                  FROM #TMP_ORDERS AS to1 WITH(NOLOCK)  
                    
               END TRY  
               BEGIN CATCH  
                  SELECT @cErrMsg = 'ERROR Executing Stored Procedure: ' + RTRIM(@c_SPName) + ERROR_MESSAGE()                                                                          
                                 + '. (isp_AutoBackendAllocation) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))      
                                   
                  IF @bDebug = 1  
                  BEGIN  
                     PRINT '>>> Error: ' + @cErrMsg  
                  END  
  
                  GOTO QUIT  
               END CATCH                                         
            END                                                                                                                                                        
            FETCH NEXT FROM CUR_BUILD_LOAD_SP INTO @c_ExecSPSQL                                                                   
         END                                                                                                           
         CLOSE CUR_BUILD_LOAD_SP                                                                                                                                       
         DEALLOCATE CUR_BUILD_LOAD_SP       
           
           
         BEGIN TRY  
            BEGIN TRAN;  
                       
            INSERT INTO AutoAllocBatch   
            (  Facility,         Storerkey,        BuildParmGroup,  
               BuildParmCode,    BuildParmString,  Duration,  
               TotalOrderCnt,    UDF01,            UDF02,  
               UDF03,            UDF04,            UDF05,  
               [Status],         StrategyKey,      [Priority] )  
            VALUES   
            (  @cFacility,         @cStorerKey,        @cBL_ParamGroup,  
               @cBL_ParameterCode, @cSQLSelect,        0,  
               @nOrderCnt,         '',                 '',  
               '',                 '',                 '',  
               '0',                @cBL_AllocStrategy, @nBL_Priority )  
        
            SET @nAllocBatchNo = @@IDENTITY          
  
            INSERT INTO #AllocBatch( AllocBatchNo ) VALUES (@nAllocBatchNo)   
              
            IF @cBL_BatchSize = '' OR @cBL_BatchSize = '0' OR ISNUMERIC(@cBL_BatchSize) <> 1   
               SET @cBL_BatchSize = '5000'  
                                                            
            SET @cSQLSelect = N'INSERT INTO AutoAllocBatchDetail '  
                              +'( AllocBatchNo, OrderKey ) '  
                              +'SELECT TOP ' + @cBL_BatchSize + ' @nAllocBatchNo, ORDERS.OrderKey ' + @cSQLCondition   
  
            IF @bDebug = 1  
            BEGIN  
               PRINT '>>> @n_TempOrderCount: ' + CAST(@n_TempOrderCount AS VARCHAR(10))   
            END                          
                    
            IF @n_TempOrderCount > 0   
            BEGIN  
               SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' OR ( ORDERS.OpenQty > 1 AND ORDERS.Status = ''1'' ) ) ' + CHAR(13) +   
                              CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +   
                              CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +     
                              N' AND EXISTS(SELECT 1 FROM #TMP_ORDERS ORD WHERE ORD.OrderKey = ORDERS.OrderKey)' + CHAR(13) +
                              N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +     --NJOW01
                                             N' WHERE aabd.OrderKey = ORDERS.OrderKey) ' + CHAR(13) +  
                              --N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +    
                              --               N' JOIN AutoAllocBatch AS aab WITH (NOLOCK) ON aab.AllocBatchNo = aabd.AllocBatchNo ' + CHAR(13) +   
                              --               N' WHERE aabd.OrderKey = ORDERS.OrderKey ' + CHAR(13) +  
                              --               N' AND ( ( aabd.[Status] IN (''0'',''1'',''6'',''8'') ) ' + --(Wan01)       
                              --               N' OR ( aab.[Status] IN (''0'',''1'') ) ) ) ' +                                                               
                              N' GROUP BY ORDERS.OrderKey '  + CHAR(13) +
                              CASE WHEN ISNULL(@c_Sort,'') <> '' THEN ', ' + RTRIM(REPLACE(@c_Sort,' DESC', '')) ELSE ' ' END + CHAR(13) +   --NJOW02
                              ISNULL(@cMax_SKU_Per_Order, '') + CHAR(13) +
                              CASE WHEN ISNULL(@c_Sort,'') <> '' THEN ' ORDER BY ' + RTRIM(@c_Sort) ELSE '' END  --NJOW02
            END  
            ELSE  
            BEGIN  
               SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' OR ( ORDERS.OpenQty > 1 AND ORDERS.Status = ''1'' ) ) ' + CHAR(13) +   
                              CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +   
                              CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +                        
                              N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) + --NJOW01    
                              N' WHERE aabd.OrderKey = ORDERS.OrderKey) ' + CHAR(13) +  
                              --N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +    
                              --N' JOIN AutoAllocBatch AS aab WITH (NOLOCK) ON aab.AllocBatchNo = aabd.AllocBatchNo ' + CHAR(13) +    
                              --N' WHERE aabd.OrderKey = ORDERS.OrderKey ' + CHAR(13) +  
                              --N' AND ( ( aabd.[Status] IN (''0'',''1'',''6'',''8'') ) ' +                --(Wan01)       
                              --N' OR ( aab.[Status] IN (''0'',''1'') ) ) ) ' +                                                 
                              N' GROUP BY ORDERS.OrderKey '  + CHAR(13) +   
                              CASE WHEN ISNULL(@c_Sort,'') <> '' THEN ', ' + RTRIM(REPLACE(@c_Sort,' DESC', '')) ELSE ' ' END + CHAR(13) +   --NJOW02
                              ISNULL(@cMax_SKU_Per_Order, '') + CHAR(13) +              
                              CASE WHEN ISNULL(@c_Sort,'') <> '' THEN ' ORDER BY ' + RTRIM(@c_Sort) ELSE '' END  --NJOW02
            END             
                                                                                   
            SET @cSQLParms  = N'@nAllocBatchNo INT'  
  
            IF @bDebug = 1  
            BEGIN  
               PRINT  N'2.1 Alloc Batch No: ' + CAST(@nAllocBatchNo AS VARCHAR(10))  
                 
               PRINT  N'3. @cSQLSelect: ' + @cSQLSelect    
            END       
  
            BEGIN TRY  
               EXEC sp_executesql @cSQLSelect, @cSQLParms, @nAllocBatchNo    
            END TRY  
            BEGIN CATCH  
               PRINT '>>>> Execute @cSQLSelect Error'  
                                
               SELECT @cErrMsg = ERROR_MESSAGE(),   
                      @nErr    = ERROR_NUMBER()    
  
               IF @@TRANCOUNT > 0  
               BEGIN  
                  ROLLBACK TRAN  
               END                    
            END CATCH                    
  
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END                                       
              
            DECLARE @n_RowRef bigint, @c_OrderKey nvarchar(10)  
              
            DECLARE CUR_AABD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT RowRef, OrderKey  
            FROM AutoAllocBatchDetail WITH (NOLOCK)   
            WHERE AllocBatchNo = @nAllocBatchNo   
            AND TotalSKU = 0   
              
            OPEN CUR_AABD  
              
            FETCH FROM CUR_AABD INTO @n_RowRef, @c_OrderKey  
              
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               SET @n_TotalSKU = 0   
               SET @n_AllocatedSKU = 0   
                 
               SELECT @n_TotalSKU = COUNT(DISTINCT SKU),    
                      @n_AllocatedSKU = SUM(CASE WHEN (OD.QtyAllocated + OD.QtyPicked) > 0 THEN 1 ELSE 0 END)   
               FROM ORDERDETAIL AS OD WITH (NOLOCK)  
               WHERE OD.OrderKey = @c_OrderKey   
                 
               BEGIN TRAN;   
     
               UPDATE AutoAllocBatchDetail WITH (ROWLOCK)  
                  SET TotalSKU = @n_TotalSKU, SKUAllocated = @n_AllocatedSKU  
               WHERE RowRef = @n_RowRef  
               IF @@ERROR = 0  
               BEGIN  
                COMMIT TRAN;  
               END              
               ELSE   
               BEGIN  
                  IF @@TRANCOUNT > 0  
                  BEGIN  
                     ROLLBACK TRAN  
                  END                  
               END                        
     
               FETCH FROM CUR_AABD INTO @n_RowRef, @c_OrderKey  
            END  
              
            CLOSE CUR_AABD  
            DEALLOCATE CUR_AABD  
  
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
              
            BEGIN TRAN;              
            --(Wan01) - Move Up from Botton part - START  
            DECLARE CUR_BATCH_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT AAB.AllocBatchNo ,AAB.Priority     ,OH.Facility  
                     ,AAB.Storerkey    ,AAB.StrategyKey  ,OD.Sku  
                     ,COUNT(DISTINCT OH.OrderKey) AS OrdersCtn   
                     ,SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)   
                     ,0  
               FROM AutoAllocBatch AAB WITH (NOLOCK)   
               JOIN #AllocBatch AB ON AB.AllocBatchNo = AAB.AllocBatchNo    
               JOIN AutoAllocBatchDetail AS AABD WITH (NOLOCK) ON AABD.AllocBatchNo = AAB.AllocBatchNo  
               JOIN ORDERS AS OH WITH (NOLOCK) ON OH.OrderKey = AABD.OrderKey   
               JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = AABD.OrderKey      
               WHERE AAB.[Status] = '0'     
               AND  AB.AllocBatchNo = @nAllocBatchNo              
               GROUP BY AAB.AllocBatchNo, AAB.Priority ,OH.Facility ,AAB.Storerkey ,AAB.StrategyKey, OD.Sku  
               HAVING SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked) > 0       --(Wan01)  
               ORDER BY OrdersCtn   
                       
            OPEN CUR_BATCH_JOB  
        
            FETCH FROM CUR_BATCH_JOB INTO @nNextAllocBatchNo, @nPriority, @cFacility, @cStorerKey, @cStrategyKey,   
                                          @cSKU, @nOrderCnt, @nTotalQty, @nTaskSeqNo   
        
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               IF NOT EXISTS (SELECT 1 FROM [dbo].[AutoAllocBatchJob] WITH (NOLOCK)  
                              WHERE AllocBatchNo = @nNextAllocBatchNo   
                              AND   Storerkey = @cStorerKey   
                              AND   Facility = @cFacility  
                              AND   SKU = @cSKU   
                              AND   [Status] IN ('0','1','6'))  
               BEGIN  
                  INSERT INTO [dbo].[AutoAllocBatchJob]  
                     (  
                        AllocBatchNo,     Priority,      Facility,  
                        Storerkey,        StrategyKey,   SKU,  
                        [Status],         TotalOrders,   TotalQty,   
                        TaskSeqNo   
                     ) VALUES  
                     ( @nNextAllocBatchNo, @nPriority,    @cFacility,   
                       @cStorerKey,        @cStrategyKey, @cSKU,   
                       '0',                @nOrderCnt,    @nTotalQty,   
                       @nTaskSeqNo )  
                                         
               END  
               IF EXISTS(SELECT 1 FROM AutoAllocBatch WITH (NOLOCK)   
                         WHERE AllocBatchNo = @nNextAllocBatchNo   
                         AND   [Status] = '0')  
               BEGIN  
                  UPDATE AutoAllocBatch WITH (ROWLOCK)  
                     SET [Status] = '1'  
                  WHERE AllocBatchNo = @nNextAllocBatchNo              
               END                       
        
               FETCH FROM CUR_BATCH_JOB INTO @nNextAllocBatchNo, @nPriority, @cFacility, @cStorerKey, @cStrategyKey,   
                                             @cSKU, @nOrderCnt, @nTotalQty, @nTaskSeqNo   
            END        
            CLOSE CUR_BATCH_JOB  
            DEALLOCATE CUR_BATCH_JOB   
   
            WHILE @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
           --(Wan01) - Move Up from Botton part - END    
         END TRY  
         BEGIN CATCH  
            --(Wan01) - START  
            IF @@TRANCOUNT > 0  
            BEGIN  
               ROLLBACK TRAN  
            END  
            --(Wan01) - END  
  
            IF @bDebug = 1  
            BEGIN                     
               SELECT @cErrMsg = ERROR_MESSAGE(),   
                      @nErr    = ERROR_NUMBER()  
  
               PRINT 'Catct Error, ErroNo: ' + CAST( @nErr AS VARCHAR(10) ) + ', Error Message: ' +  @cErrMsg                         
            END  
         END CATCH                  
  
         --------------------------------------------------------  
         -- Post Build Strategy (Start)  
         --------------------------------------------------------  
         DECLARE CUR_AUTO_ALLOC_STRATEGY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT ISNULL(Notes, '')  
            FROM   CODELKUP WITH (NOLOCK)  
            WHERE  ListName  = @cBL_ParameterCode  
            AND    Short     = 'STRATEGY'  
            ORDER BY Code   
            
  OPEN CUR_AUTO_ALLOC_STRATEGY  
            
         FETCH NEXT FROM CUR_AUTO_ALLOC_STRATEGY INTO @c_ExecSPSQL  
            
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF @c_ExecSPSQL <> ''  
            BEGIN  
               SET @c_ExecSPSQL = RTRIM(@c_ExecSPSQL) +                                                                                                                  
                                  CASE WHEN CHARINDEX('@',@c_ExecSPSQL, 1) > 0  THEN ',' ELSE '' END +   
                                  ' @nAllocBatchNo = @nAllocBatchNo, ' +   
                                  ' @cBL_ParameterCode = @cBL_ParameterCode, ' +   
                                  ' @nErr = @nErr OUTPUT, ' +   
                                  ' @cErrMsg = @cErrMsg OUTPUT, ' +  
                                  ' @bDebug = @bDebug '   
  
               BEGIN TRY  
                  IF @bDebug=1  
                  BEGIN  
                     PRINT @c_ExecSPSQL   
                  END  
                    
                  EXEC sp_ExecuteSQL @c_ExecSPSQL   
                       , N'@nAllocBatchNo BIGINT, @cBL_ParameterCode NVARCHAR(30), @nErr INT OUTPUT, @cErrMsg NVARCHAR(250) OUTPUT, @bDebug INT'  
                       , @nAllocBatchNo  
                       , @cBL_ParameterCode   
                       , @nErr    OUTPUT  
                       , @cErrMsg OUTPUT  
                       , @bDebug   
                 
               END TRY  
               BEGIN CATCH  
                  SET @cErrMsg = 'ERROR Executing Stored Procedure: ' + RTRIM(@c_ExecSPSQL)   
                        + '. (isp_AutoBackendAllocation) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))  
                    
                  IF @bDebug=1  
                  BEGIN  
                     PRINT @cErrMsg  
                  END  
                    
                  GOTO QUIT                 
               END CATCH           
            END  
      
            FETCH NEXT FROM CUR_AUTO_ALLOC_STRATEGY INTO @c_ExecSPSQL  
         END         
         CLOSE CUR_AUTO_ALLOC_STRATEGY                                                                                                                                    
         DEALLOCATE CUR_AUTO_ALLOC_STRATEGY    
         --------------------------------------------------------  
         -- Post Build Strategy (End)  
         --------------------------------------------------------                     
      END -- IF @nOrderCnt > 0   
      BEGIN  
         IF @bDebug = 1  
         BEGIN  
            PRINT '>>>   No Record Found! '  
         END  
      END  
  
      FETCH_NEXT:  
     
      FETCH FROM C_BuiLoadParameters INTO @cStorerKey, @cFacility, @cBL_ParamGroup,  
                                @cBL_ParameterCode, @cBL_ParmDesc, @nBL_Priority,  
                                @cBL_AllocStrategy, @cBL_BatchSize   
   END                
   CLOSE C_BuiLoadParameters  
   DEALLOCATE C_BuiLoadParameters  
     
   SET @nAllocBatchNo = 0   
   SET @nPrevAllocBatchNo = 0      
              
   START_PRIORITY:     
   /*--Wan01 - START  
   DECLARE @nPriority    INT = 9  
          ,@cStrategyKey NVARCHAR(20) = ''  
          ,@nTotalQty    INT = 0   
        
                
   IF EXISTS(SELECT 1 FROM #AllocBatch AS ab WITH(NOLOCK))  
   BEGIN      
      DECLARE CUR_BATCH_JOB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT AAB.AllocBatchNo ,AAB.Priority     ,OH.Facility  
               ,AAB.Storerkey    ,AAB.StrategyKey  ,OD.Sku  
               ,COUNT(DISTINCT OH.OrderKey) AS OrdersCtn   
               ,SUM(OD.OpenQty - OD.QtyAllocated - OD.QtyPicked)   
               ,0  
         FROM AutoAllocBatch AAB WITH (NOLOCK)   
         JOIN #AllocBatch AB ON AB.AllocBatchNo = AAB.AllocBatchNo    
         JOIN AutoAllocBatchDetail AS AABD WITH (NOLOCK) ON AABD.AllocBatchNo = AAB.AllocBatchNo  
         JOIN ORDERS AS OH WITH (NOLOCK) ON OH.OrderKey = AABD.OrderKey   
         JOIN ORDERDETAIL AS OD WITH (NOLOCK) ON OD.OrderKey = AABD.OrderKey      
         WHERE AAB.[Status] = '0'                
         GROUP BY AAB.AllocBatchNo, AAB.Priority ,OH.Facility ,AAB.Storerkey ,AAB.StrategyKey, OD.Sku  
         ORDER BY OrdersCtn   
                       
      OPEN CUR_BATCH_JOB  
        
      FETCH FROM CUR_BATCH_JOB INTO @nNextAllocBatchNo, @nPriority, @cFacility, @cStorerKey, @cStrategyKey,   
                                    @cSKU, @nOrderCnt, @nTotalQty, @nTaskSeqNo   
        
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF NOT EXISTS (SELECT 1 FROM [dbo].[AutoAllocBatchJob] WITH (NOLOCK)  
                        WHERE AllocBatchNo = @nNextAllocBatchNo   
                        AND   Storerkey = @cStorerKey   
                        AND   Facility = @cFacility  
                        AND   SKU = @cSKU   
                        AND   [Status] IN ('0','1','6'))  
         BEGIN  
            INSERT INTO [dbo].[AutoAllocBatchJob]  
               (  
                  AllocBatchNo,     Priority,      Facility,  
                  Storerkey,        StrategyKey,   SKU,  
                  [Status],         TotalOrders,   TotalQty,   
                  TaskSeqNo   
               ) VALUES  
               ( @nNextAllocBatchNo, @nPriority,    @cFacility,   
                 @cStorerKey,        @cStrategyKey, @cSKU,   
                 '0',                @nOrderCnt,    @nTotalQty,   
                 @nTaskSeqNo )  
                                         
         END  
         IF EXISTS(SELECT 1 FROM AutoAllocBatch WITH (NOLOCK)   
                   WHERE AllocBatchNo = @nNextAllocBatchNo   
                   AND   [Status] = '0')  
         BEGIN  
            UPDATE AutoAllocBatch WITH (ROWLOCK)  
               SET [Status] = '1'  
            WHERE AllocBatchNo = @nNextAllocBatchNo              
         END                       
        
         FETCH FROM CUR_BATCH_JOB INTO @nNextAllocBatchNo, @nPriority, @cFacility, @cStorerKey, @cStrategyKey,   
                                       @cSKU, @nOrderCnt, @nTotalQty, @nTaskSeqNo   
      END        
      CLOSE CUR_BATCH_JOB  
      DEALLOCATE CUR_BATCH_JOB        
        
   END  
   ELSE   
   BEGIN  
      IF @bDebug = 1  
      BEGIN  
         PRINT '>>> Failed: No Record Found in #AllocBatch'  
      END  
   END  
   --Wan01 - END*/  
   QUIT:  
   --(Wan01) - START  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   --(Wan01) - END  
END -- Procedure  

GO