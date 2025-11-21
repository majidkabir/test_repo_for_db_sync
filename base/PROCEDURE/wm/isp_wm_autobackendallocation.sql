SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_WM_AutoBackendAllocation                       */  
/* Creation Date:                                                       */  
/* Copyright: LFL                                                       */  
/* Written by: Shong                                                    */  
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
/* 11-Mar-2021  Shong   1.0   Migrate from isp_WM_AutoBackendAllocation */  
/************************************************************************/  
CREATE PROC [WM].[isp_WM_AutoBackendAllocation] (   
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
  
   DECLARE @c_APP_DB_Name           NVARCHAR(20)  
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

   DECLARE @c_Restriction01          NVARCHAR(30) = ''
          ,@c_Restriction02          NVARCHAR(30) = ''
          ,@c_Restriction03          NVARCHAR(30) = ''
          ,@c_Restriction04          NVARCHAR(30) = ''
          ,@c_Restriction05          NVARCHAR(30) = ''
          ,@c_Restriction            NVARCHAR(30) = ''
          ,@c_RestrictionValue       NVARCHAR(10) = ''
          ,@c_RestrictionValue01     NVARCHAR(10) = ''
          ,@c_RestrictionValue02     NVARCHAR(10) = ''
          ,@c_RestrictionValue03     NVARCHAR(10) = ''
          ,@c_RestrictionValue04     NVARCHAR(10) = ''
          ,@c_RestrictionValue05     NVARCHAR(10) = ''
          ,@n_NoOfSKUInOrder         INT          = 0
          ,@c_Operator               NVARCHAR(60) = ''  
                      
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
   AND   aabd.[Status] IN ('0','1')  
   GROUP BY o.StorerKey, o.Facility   
  
   IF @cParameterCode = ''  
   BEGIN  
      DECLARE C_BuiLoadParameters CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
         SELECT bpc.Storerkey
               ,bpc.Facility
               ,bpc.ParmGroup
               ,bp.BuildParmKey
               ,bp.[Description]
               ,CASE 
                     WHEN ISNUMERIC(bp.[Priority]) = 1 THEN CAST(bp.[Priority] AS INT)
                     ELSE 99
                END AS [Priority]
               ,bp.Strategy
               ,bp.[BatchSize]
               ,ISNULL(bp.Restriction01,'')
               ,ISNULL(bp.Restriction02,'')
               ,ISNULL(bp.Restriction03,'')
               ,ISNULL(bp.Restriction04,'')
               ,ISNULL(bp.Restriction05,'')
               ,ISNULL(bp.RestrictionValue01,'')
               ,ISNULL(bp.RestrictionValue02,'')
               ,ISNULL(bp.RestrictionValue03,'')
               ,ISNULL(bp.RestrictionValue04,'')
               ,ISNULL(bp.RestrictionValue05,'')
         FROM   BUILDPARMGROUPCFG  AS bpc WITH(NOLOCK)
         JOIN BUILDPARM AS bp WITH(NOLOCK) ON  bp.ParmGroup = bpc.ParmGroup
         WHERE bpc.[Type] = 'BackEndAlloc'
           AND bpc.Facility <> ''
           AND bp.[Active] = '1'
         ORDER BY
                CASE 
                     WHEN ISNUMERIC(bp.[Priority]) = 1 THEN CAST(bp.[Priority] AS INT)
                     ELSE 99
                END
               ,bpc.ParmGroup
               ,bp.BuildParmKey  
      
   END    
   ELSE   
   BEGIN  
      DECLARE C_BuiLoadParameters CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
         SELECT bpc.Storerkey
               ,bpc.Facility
               ,bpc.ParmGroup
               ,bp.BuildParmKey
               ,bp.[Description]
               ,CASE 
                     WHEN ISNUMERIC(bp.[Priority]) = 1 THEN CAST(bp.[Priority] AS INT)
                     ELSE 99
                END AS [Priority]
               ,bp.Strategy
               ,bp.[BatchSize]
               ,ISNULL(bp.Restriction01, '')
               ,ISNULL(bp.Restriction02, '')
               ,ISNULL(bp.Restriction03, '')
               ,ISNULL(bp.Restriction04, '')
               ,ISNULL(bp.Restriction05, '')
               ,ISNULL(bp.RestrictionValue01, '')
               ,ISNULL(bp.RestrictionValue02, '')
               ,ISNULL(bp.RestrictionValue03, '')
               ,ISNULL(bp.RestrictionValue04, '')
               ,ISNULL(bp.RestrictionValue05, '') 
         FROM BUILDPARMGROUPCFG AS bpc WITH(NOLOCK)
         JOIN BUILDPARM AS bp WITH(NOLOCK) ON bp.ParmGroup = bpc.ParmGroup           
         WHERE bpc.[Type] = 'BackEndAlloc'
         AND bpc.Facility <> ''
         AND bp.[Active] = '1'
         AND bp.BuildParmKey = @cParameterCode
         ORDER BY CASE WHEN ISNUMERIC(bp.[Priority]) = 1 THEN CAST(bp.[Priority] AS INT) ELSE 99 END, bpc.ParmGroup, bp.BuildParmKey  
     
   END  
       
   OPEN C_BuiLoadParameters  
  
   FETCH FROM C_BuiLoadParameters INTO @cStorerKey, @cFacility, @cBL_ParamGroup,  
              @cBL_ParameterCode,    @cBL_ParmDesc, @nBL_Priority,  
              @cBL_AllocStrategy,    @cBL_BatchSize,
              @c_Restriction01,      @c_Restriction02, @c_Restriction03,
              @c_Restriction04,      @c_Restriction05,
              @c_RestrictionValue01, @c_RestrictionValue02,
              @c_RestrictionValue03, @c_RestrictionValue04,
              @c_RestrictionValue05   
  
   WHILE @@FETCH_STATUS = 0  
   BEGIN   
      IF @bDebug=1
      BEGIN
         PRINT 'Executing  Parameter Group: ' + @cBL_ParamGroup 
         PRINT '           Parameter code: ' + @cBL_ParameterCode
      END
      
      SET @n_SafetyAllocateOrderCtn = 5000   
      SET @n_TaskPriorityByStorer = 99  
        
      SELECT @n_SafetyAllocateOrderCtn = CASE WHEN ISNUMERIC(c.Short) = 1 THEN CAST(c.Short AS INT) ELSE 5000 END   
      FROM CODELKUP AS c WITH(NOLOCK)  
      WHERE c.LISTNAME = 'AUTOALLOC'  
      AND c.Storerkey = @cStorerKey  
      AND c.Notes = @cFacility  
      
      IF @bDebug=1
      BEGIN
         PRINT '  >> Safety Allocate Order Ctn: ' + CAST(@n_SafetyAllocateOrderCtn AS VARCHAR) 
      END
        
      IF EXISTS(SELECT 1 FROM #StorerWIP  
                WHERE StorerKey = @cStorerKey   
                AND   Facility = @cFacility   
                AND   NoOfOrders > @n_SafetyAllocateOrderCtn)  
      BEGIN  
         IF @bDebug=1
         BEGIN
            PRINT '  >> Go to Next, No Of Orders > Safety AllocationOrderCtn '  
            SELECT * FROM #StorerWIP  
            WHERE StorerKey = @cStorerKey   
            AND   Facility = @cFacility   
            AND   NoOfOrders > @n_SafetyAllocateOrderCtn 
         END
               
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
      BEGIN
         IF @bDebug=1
         BEGIN
            PRINT '>> @nBatchCount >= @nMaxBatchCount  ' + CAST(@nBatchCount AS VARCHAR)
         END 
         GOTO FETCH_NEXT         
      END
           
      EXEC [WM].[isp_WM_Gen_BuildOrderSelect]   
           @cParmCode  = @cBL_ParameterCode,   
           @cFacility  = @cFacility,   
           @cStorerKey = @cStorerKey,  
           @nSuccess   = @nSuccess OUTPUT,   
           @cErrorMsg  = @cErrMsg OUTPUT,   
           @bDebug     = @bDebug,   
           @cSQLSelect = @cSQLSelect OUTPUT,      
           @cBatchNo   = @cBatchNo   
     
      IF @bDebug=1
      BEGIN
         PRINT '>> Execute [isp_WM_Gen_BuildOrderSelect] : ' + @cBL_ParameterCode
         PRINT @cSQLSelect          
      END
      SET @nWherePosition =  CHARINDEX(' FROM ', @cSQLSelect, 1)  
      SET @nGroupByPosition = CHARINDEX('GROUP BY',  @cSQLSelect, 1)  
     
      IF @nGroupByPosition = 0   
         SET @nGroupByPosition = LEN(@cSQLSelect)   
     
      SET @cSQLCondition = SUBSTRING( @cSQLSelect,  
                                       @nWherePosition,   
                                       @nGroupByPosition - @nWherePosition)   
     
      SET @cMax_SKU_Per_Order = ''                                        

      SET  @cMax_SKU_Per_Order = '' 

      SET @n_Idx = 1  
      WHILE @n_Idx <= 5  
      BEGIN  
         SET @c_Restriction = CASE WHEN @n_Idx = 1 THEN @c_Restriction01  
                                   WHEN @n_Idx = 2 THEN @c_Restriction02  
                                   WHEN @n_Idx = 3 THEN @c_Restriction03  
                                   WHEN @n_Idx = 4 THEN @c_Restriction04  
                                   WHEN @n_Idx = 5 THEN @c_Restriction05  
                                   END  
         SET @c_RestrictionValue = CASE WHEN @n_Idx = 1 THEN @c_RestrictionValue01  
                                        WHEN @n_Idx = 2 THEN @c_RestrictionValue02  
                                        WHEN @n_Idx = 3 THEN @c_RestrictionValue03  
                                        WHEN @n_Idx = 4 THEN @c_RestrictionValue04  
                                        WHEN @n_Idx = 5 THEN @c_RestrictionValue05  
                                        END  
  
         IF @c_Restriction Like '%_NoOfSkuInOrder'  
         BEGIN  
            SET @c_Operator = ''                                   
            SELECT @c_Operator = CL.Short  
            FROM CODELKUP CL WITH (NOLOCK)  
            WHERE CL.ListName = 'BLDPRMREST'  
            AND   CL.Code = @c_Restriction  
  
            SET @n_NoOfSKUInOrder = @c_RestrictionValue      
            IF ISNULL(@c_Operator,'') = ''  
            BEGIN  
               SET @c_Operator = '='  
            END  
           
            SET  @cMax_SKU_Per_Order = ' HAVING COUNT(DISTINCT ORDERDETAIL.SKU) ' 
                            + RTRIM(@c_Operator)   
                            + ' '   
                            + CAST(@n_NoOfSKUInOrder AS NVARCHAR)  
         END
         ELSE IF @c_Restriction Like '%_MaxOrderPerBuild'
         BEGIN
            SET @cBL_BatchSize = @c_RestrictionValue01
         END
            
         SET @n_Idx = @n_Idx + 1  
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
                                       
          EXEC [dbo].[nsp_LogError] @n_err = @nErr, @c_errmsg = @cErrMsg, @c_module = 'isp_WM_AutoBackendAllocation'  
                     
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
                                 + '. (isp_WM_AutoBackendAllocation) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))      
                                   
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
                              N' GROUP BY ORDERS.OrderKey '  + CHAR(13) +   
               ISNULL(@cMax_SKU_Per_Order, '')                
            END  
            ELSE  
            BEGIN  
               SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' OR ( ORDERS.OpenQty > 1 AND ORDERS.Status = ''1'' ) ) ' + CHAR(13) +   
                              CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +   
                              CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +                        
                              N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) + --NJOW01    
                              N' WHERE aabd.OrderKey = ORDERS.OrderKey) ' + CHAR(13) +  
                              N' GROUP BY ORDERS.OrderKey '  + CHAR(13) +   
               ISNULL(@cMax_SKU_Per_Order, '')                
            END             
                                                                                   
            SET @cSQLParms  = N'@nAllocBatchNo INT'  
  
            IF @bDebug = 1  
            BEGIN  
               PRINT  N'2.1 Alloc Batch No: ' + CAST(@nAllocBatchNo AS VARCHAR(10))  
                 
               PRINT  N'3. @cSQLSelect: ' + @cSQLSelect    
            END       
  
            BEGIN TRY  
               EXEC sp_executesql @cSQLSelect, @cSQLParms, @nAllocBatchNo  
               
               IF @bDebug=1
               BEGIN
                  PRINT  N'3.1 Select Count from AutoAllocBatchDetail'
                  
                  SELECT COUNT(*)
                  FROM AutoAllocBatchDetail AS aabd WITH(NOLOCK)
                  WHERE aabd.AllocBatchNo = @nAllocBatchNo
                   
               END  
            END TRY  
            BEGIN CATCH  
               PRINT @cSQLSelect
               
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
               IF @bDebug=1
               BEGIN
                  PRINT '>> Alloc Batch No: ' + CAST(@nNextAllocBatchNo AS VARCHAR) + ' SKU: ' + @cSKU
               END
               
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
           
            IF @bDebug=1
            BEGIN
               SELECT * FROM  [AutoAllocBatchJob] (NOLOCK)
               WHERE AllocBatchNo = @nNextAllocBatchNo  
            END
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
                        + '. (isp_WM_AutoBackendAllocation) ErrorCode:' + CAST(@@ERROR AS NVARCHAR(5))  
                    
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
                 @cBL_ParameterCode,    @cBL_ParmDesc, @nBL_Priority,  
                 @cBL_AllocStrategy,    @cBL_BatchSize,
                 @c_Restriction01,      @c_Restriction02, @c_Restriction03,
                 @c_Restriction04,      @c_Restriction05,
                 @c_RestrictionValue01, @c_RestrictionValue02,
                 @c_RestrictionValue03, @c_RestrictionValue04,
                 @c_RestrictionValue05                                     
   END                
   CLOSE C_BuiLoadParameters  
   DEALLOCATE C_BuiLoadParameters  
     
   SET @nAllocBatchNo = 0   
   SET @nPrevAllocBatchNo = 0      
              
   START_PRIORITY:     

   QUIT:  
   --(Wan01) - START  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   --(Wan01) - END  
END -- Procedure  

GO