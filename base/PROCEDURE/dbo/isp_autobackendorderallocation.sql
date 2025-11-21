SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Procedure: isp_AutoBackendOrderAllocation                     */  
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
/* 13-Nov-2020  Shong   1.0   Creaed for WMS-15662                      */  
/* 11-May-2022  Shong   1.1   Add Debug Message                         */  
/* 16-May-2022  Shong   1.2   Log Error when Submit Q task fail (SWT01) */
/* 19-May-2022  Shong   1.3   Do not take Order status = 0              */
/* 23-May-2022  Shong   1.4   Prevent Orders send for allocation before */
/*                            all lines finish added  (SWT02)           */
/************************************************************************/  
CREATE   PROC [dbo].[isp_AutoBackendOrderAllocation] (  
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
         , @dCutOffDate             DATETIME -- (SWT02)
  
   DECLARE @n_SafetyAllocateOrderCtn INT = 0  
         , @n_TaskPriorityByStorer   INT = 0  
         
  
   --(Wan01) - START  
   DECLARE @n_Priority    INT = 9  
          ,@cStrategyKey NVARCHAR(20) = ''  
          ,@nTotalQty    INT = 0  
         , @n_StartTCnt  INT = @@TRANCOUNT  
   --(Wan01) - END  
  
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
  
   -- (SWT02)
   SET @dCutOffDate = DATEADD(MINUTE, -5, GETDATE())

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
          AND   VH.[BL_BuildType] = 'BackendSOAlloc'  
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
          AND   VH.[BL_BuildType] = 'BackendSOAlloc'  
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
          IF @bDebug = 1  
          BEGIN  
             PRINT  'DEBUG:  Storer: ' + @cStorerKey + '. Facility: ' + @cFacility + ' No of WIP Orders grater than '   
             + Cast(@n_SafetyAllocateOrderCtn AS VARCHAR(5))  
             PRINT 'DEBUG:  Try Next Storer and Facility'  
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
         IF @bDebug = 1  
         BEGIN  
            PRINT 'DEBUG:  BuildParmGroup ' + @cBL_ParamGroup + ', BuildParmCode ' + @cBL_ParameterCode  
            PRINT 'DEBUG:  Total Batch work in progress is more than '  + Cast(@nMaxBatchCount AS VARCHAR(10)) + ', go to next batch'  
            PRINT 'DEBUG:  Try Next Storer and Facility'  
         END  
         GOTO FETCH_NEXT  
      END  
  
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
  
  
      SET @nOrderCnt  = 0  
      SET @cSQLSelect = N'SELECT @nOrderCnt = COUNT(DISTINCT ORDERS.OrderKey) ' +  
                        N', @dOrderAddDate = MIN(ORDERS.AddDate) ' + @cSQLCondition  
  
      --NJOW01  
      -- (SWT02)
      SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' AND ORDERS.AddDate <= ''' + CONVERT(varchar(20), @dCutOffDate, 120) + ''') ' + CHAR(13) +  
                     CASE WHEN ISNULL(@cStartOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey >= ''' +  @cStartOrderKey + ''' ' ELSE '' END +  
                     CASE WHEN ISNULL(@cEndOrderKey,'') <> '' THEN ' AND ORDERS.OrderKey <= ''' +  @cEndOrderKey + ''' ' ELSE '' END +  
                     N' AND NOT EXISTS(SELECT 1 FROM AutoAllocBatchDetail AS aabd WITH (NOLOCK) ' + CHAR(13) +  
                     N' WHERE aabd.OrderKey = ORDERS.OrderKey ) '  
  
      SET @cSQLParms  = N'@nOrderCnt NVARCHAR(10) OUTPUT, @dOrderAddDate DATETIME OUTPUT '  
  
      IF @bDebug = 1  
      BEGIN  
         PRINT ''  
         PRINT 'DEBUG:  Paramater Code: ' + @cBL_ParameterCode  + ', Storer: ' + @cStorerKey + ', Facility: ' + @cFacility  
         PRINT  N'-----------------------------------------------------------------------'  
         PRINT  'DEBUG:  ' + @cSQLSelect  
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
             PRINT  'DEBUG:  @cErrorMsg: ' + @cErrMsg  
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
                  PRINT 'DEBUG:  Stored Procedure: ' + @c_ExecSPSQL  
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
                     PRINT 'DEBUG:   Error: ' + @cErrMsg  
                  END  
  
                  GOTO QUIT  
               END CATCH  
            END  
            FETCH NEXT FROM CUR_BUILD_LOAD_SP INTO @c_ExecSPSQL  
         END  
         CLOSE CUR_BUILD_LOAD_SP  
         DEALLOCATE CUR_BUILD_LOAD_SP  
  
  
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
            PRINT 'DEBUG:  @n_TempOrderCount: ' + CAST(@n_TempOrderCount AS VARCHAR(10))  
         END  
  
         IF @n_TempOrderCount > 0  
         BEGIN  
            -- (SWT02)
            SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' AND ORDERS.AddDate <= ''' + CONVERT(varchar(20), @dCutOffDate, 120) + ''') ' + CHAR(13) +  
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
            -- (SWT02)
            SET @cSQLSelect = @cSQLSelect + N' AND ( ORDERS.Status = ''0'' AND ORDERS.AddDate <= ''' + CONVERT(varchar(20), @dCutOffDate, 120) + ''') ' + CHAR(13) +  
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
         FROM dbo.AutoAllocBatchDetail WITH (NOLOCK)  
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
  
            UPDATE dbo.AutoAllocBatchDetail WITH (ROWLOCK)  
               SET TotalSKU = @n_TotalSKU  
                 , SKUAllocated = @n_AllocatedSKU  
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
  
            IF EXISTS(SELECT 1  
                        FROM dbo.ORDERDETAIL OD WITH (NOLOCK)  
                        JOIN dbo.ORDERS OH WITH (NOLOCK) ON OH.OrderKey = OD.OrderKey  
                        JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON OD.StorerKey = SL.StorerKey  
                                                      AND SL.Sku = OD.SKU  
                        JOIN  dbo.LOC AS L WITH (NOLOCK) ON l.Loc = SL.Loc  
                     WHERE OD.OrderKey = @c_OrderKey  
                     AND OH.OrderKey = @c_OrderKey  
                     AND   l.Facility = OH.Facility  
                     AND   l.[Status] <> 'HOLD'  
                     AND   l.LocationFlag NOT IN ('HOLD','DAMAGE')  
                     GROUP BY SL.StorerKey, SL.Sku  
                     HAVING  SUM(SL.QTY - SL.QtyAllocated - SL.QTYPicked ) > 0)  
            BEGIN  
               SET @cCommand = N'EXEC [dbo].[nsp_OrderProcessing_Wrapper]' +  
                                 N'  @c_OrderKey = ''' + @c_OrderKey + ''' ' +  
                                 N', @c_oskey = ''''' +  
                                 N', @c_docarton = ''N'' ' +  
                                 N', @c_doroute = ''N'' ' +  
                                 N', @c_tblprefix = '''' ' +  
                                 N', @c_extendparms = '''' '  
  
               IF @bDebug = 1  
               BEGIN  
                  PRINT '  > @cCommand : ' + @cCommand  
               END  
  
               BEGIN TRY  
               EXEC dbo.isp_QCmd_SubmitTaskToQCommander  
                     @cTaskType         = 'O' -- D=By Datastream, T=Transmitlog, O=Others  
                     , @cStorerKey        = @cStorerKey  
                     , @cDataStream       = 'BckEndAllo'  
                     , @cCmdType          = 'SQL'  
                     , @cCommand          = @cCommand  
                     , @cTransmitlogKey   = @n_RowRef  -- (SWT01)
                     , @nThreadPerAcct    = @n_ThreadPerAcct  
                     , @nThreadPerStream  = @n_ThreadPerStream  
                     , @nMilisecondDelay  = @n_MilisecondDelay  
                     , @nSeq              = 1  
                     , @cIP               = @c_IP  
                     , @cPORT             = @c_PORT  
                     , @cIniFilePath      = @c_IniFilePath  
                     , @cAPPDBName        = @c_APP_DB_Name  
                     , @bSuccess          = @bSuccess OUTPUT  
                     , @nErr              = @nErr OUTPUT  
                     , @cErrMsg           = @cErrMsg OUTPUT  
                     , @nPriority         = @n_Priority  
  
               IF @nErr <> 0 AND ISNULL(@cErrMsg,'') <> ''  
               BEGIN  
                  PRINT @cErrMsg 

                  SET @cErrMsg = 'Submit Q Task Fail: ' + ISNULL(@cErrMsg,'')

                  UPDATE dbo.AutoAllocBatchDetail WITH (ROWLOCK)  
                     SET Status='5', EditDate=GETDATE()  
                  WHERE RowRef = @n_RowRef                    
  
                  EXECUTE dbo.nsp_Logerror @n_err = 900001, @c_errmsg= @cErrMsg, @c_module='isp_AutoBackendOrderAllocation'

                  -- Do not exit, proceed with next record
                  -- GOTO QUIT  
               END  
               ELSE  
               BEGIN  
                  BEGIN TRAN;  
  
                  UPDATE dbo.AutoAllocBatchDetail WITH (ROWLOCK)  
                     SET Status='1', EditDate=GETDATE()  
                  WHERE RowRef = @n_RowRef  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     ROLLBACK TRAN;  
                     GOTO QUIT  
                  END  
                  ELSE  
                     COMMIT TRAN;  
  
               END  
               END TRY  
               BEGIN CATCH  
                  SET @cErrMsg = ERROR_MESSAGE()  
                  PRINT @cErrMsg  
  
                  GOTO QUIT  
               END CATCH  
            END -- IF Stock Available  
  
            FETCH FROM CUR_AABD INTO @n_RowRef, @c_OrderKey  
         END  
  
         CLOSE CUR_AABD  
         DEALLOCATE CUR_AABD  
  
         WHILE @@TRANCOUNT > 0  
         BEGIN  
           COMMIT TRAN  
         END  
  
      END -- IF @nOrderCnt > 0  
      --ELSE  
      --BEGIN  
      --   IF @bDebug = 1  
      --   BEGIN  
      --      PRINT '>>>   No Record Found! '  
      --   END  
      --END  
  
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
  
   QUIT:  
   --(Wan01) - START  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
   --(Wan01) - END  
END -- Procedure  

GO