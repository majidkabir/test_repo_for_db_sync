SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                
/* Store procedure: isp_WebAPI_LCHART_WarehouseActCBMnSHP               */                
/* Creation Date: 02-FEB-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AlexKeoh                                                 */  
/*                                                                      */  
/* Purpose: Pass Incoming Request String For Interface                  */  
/*                                                                      */  
/* Input Parameters:  @b_Debug            - 0                           */  
/*                    @c_Format           - 'XML/JSON'                  */  
/*                    @c_UserID           - 'UserName'                  */  
/*                    @c_OperationType    - 'Operation'                 */  
/*                    @c_RequestString    - ''                          */  
/*                    @b_Debug            - 0                           */  
/*                                                                      */  
/* Output Parameters: @b_Success          - Success Flag    = 0         */  
/*                    @c_ErrNo            - Error No        = 0         */  
/*                    @c_ErrMsg           - Error Message   = ''        */  
/*                    @c_ResponseString   - ResponseString  = ''        */  
/*                                                                      */  
/* Called By: LeafAPIServer - isp_Generic_WebAPI_Request                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.1                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Purposes
2023-08-16              Remove fnc_JSON2XML                             */
/************************************************************************/      
CREATE PROC [dbo].[isp_WebAPI_LCHART_WarehouseActCBMnSHP](  
     @b_Debug           INT            = 0  
   , @c_Format          VARCHAR(10)    = ''  
   , @c_UserID          NVARCHAR(256)  = ''  
   , @c_OperationType   NVARCHAR(60)   = ''  
   , @c_RequestString   NVARCHAR(MAX)  = ''  
   , @b_Success         INT            = 0   OUTPUT  
   , @n_ErrNo           INT            = 0   OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT  
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                    INT  
         , @n_StartCnt                    INT  
         , @c_ExecStatements              NVARCHAR(MAX)  
         , @c_ExecArguments               NVARCHAR(2000)  
         , @x_xml                         XML  
         , @n_doc                         INT  
         , @c_XMLRequestString            NVARCHAR(MAX)  
         , @c_Request_XMLNodes            NVARCHAR(60)  
         , @b_IsFirstCondition            INT  
         , @c_FullCondition               NVARCHAR(2000)  
         , @c_ColumnName                  NVARCHAR(60)  
         , @c_ColumnValue                 NVARCHAR(60)  
         , @c_ColumnOperationType         NVARCHAR(15)  
           
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''   
   SET @c_XMLRequestString                = ''  
  
   SET @b_IsFirstCondition                = 0  
   SET @c_FullCondition                   = ''  
   SET @c_ColumnName                      = ''  
   SET @c_ColumnValue                     = ''  
   SET @c_OperationType                   = ''  
        
   IF OBJECT_ID('tempdb..#LCHART_FILTER') IS NOT NULL  
   DROP TABLE #LCHART_FILTER  
  
   CREATE TABLE #LCHART_FILTER(  
      [ColumnName] NVARCHAR(60) NULL,  
      [ColumnValue] NVARCHAR(60) NULL,  
      [OperationType] NVARCHAR(15) NULL  
   )  
  
   --Prepare TempTable   
   IF OBJECT_ID('tempdb..#LCHART_WAREHOUSEACTIVITIES') IS NOT NULL  
   DROP TABLE #LCHART_WAREHOUSEACTIVITIES  
  
   CREATE TABLE #LCHART_WAREHOUSEACTIVITIES(  
      [Date]               DATETIME       NULL,  
      [CBM_Received]       BIGINT         NULL,  
      [CBM_Shipped]        BIGINT         NULL,  
      [Received_Shipment]  BIGINT         NULL,  
      [Shipped_Shipment]   BIGINT         NULL  
   )  
  
   INSERT INTO #LCHART_WAREHOUSEACTIVITIES ( [Date], [CBM_Received], [CBM_Shipped], [Received_Shipment], [Shipped_Shipment] )  
   SELECT '2018-01-16', 1221, 1188, 26, 16   
   UNION ALL SELECT '2018-01-17', 790  , 853  , 44, 12   
   UNION ALL SELECT '2018-01-18', 155  , 231  , 17, 18   
   UNION ALL SELECT '2018-01-19', 1322 , 1819 , 18, 21   
   UNION ALL SELECT '2018-01-22', 1000 , 7017 , 47, 26   
   UNION ALL SELECT '2018-01-23', 1235 , 1903 , 34, 51   
   UNION ALL SELECT '2018-01-24', 16   , 402  , 50, 28   
   UNION ALL SELECT '2018-01-25', 2216 , 2704 , 0 , 19   
   UNION ALL SELECT '2018-01-26', 16   , 339  , 28, 16   
   UNION ALL SELECT '2018-01-29', 906  , 1187 , 43, 17   
   UNION ALL SELECT '2018-01-30', 6    , 201  , 43, 10   
   UNION ALL SELECT '2018-01-31', 6    , 121  , 12, 15   
   UNION ALL SELECT '2018-02-01', 3    , 9    , 11, 3   
   UNION ALL SELECT '2018-02-02', 889  , 1211 , 14, 26   
   UNION ALL SELECT '2018-02-03', 0    , 0    , 28, 0   
   UNION ALL SELECT '2018-02-05', 2123 , 4052 , 66, 19   
   UNION ALL SELECT '2018-02-06', 2561 , 3891 , 43, 31   
   UNION ALL SELECT '2018-02-07', 100  , 133  , 25, 4   
   UNION ALL SELECT '2018-02-08', 412  , 508  , 2 , 32   
   UNION ALL SELECT '2018-02-09', 512  , 709  , 2 , 13   
   UNION ALL SELECT '2018-02-12', 1231 , 2019 , 40, 24   
   UNION ALL SELECT '2018-02-13', 0    , 0    , 37, 1   
  
   IF @c_Format = 'json'  
   BEGIN  

      SET @c_XMLRequestString = (
         SELECT * FROM OPENJSON(@c_RequestString,'$.Request.Data')
         WITH (
            [ColumnName]          NVARCHAR(60),
            [ColumnValue]         NVARCHAR(60),
            [OperationType]       NVARCHAR(15)
         )
         FOR XML PATH('Data'), ROOT('Request')
      )  
        
      -- Convert special HTML character to normal character   
      IF CHARINDEX(N'&#', @c_XMLRequestString, 1) > 0   
      BEGIN  
         SELECT @c_XMLRequestString = CAST(@c_XMLRequestString as XML).value('text()[1]','nvarchar(max)')            
      END  
  
      SET @x_xml = CONVERT(XML, @c_XMLRequestString)  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '>>>>>>>>>> JSONCONVERTTOXML' + CHAR(13) + @c_XMLRequestString  
      END  
   END  
   ELSE  
   BEGIN  
      SET @x_xml = CONVERT(XML, @c_RequestString)  
   END  
  
   IF @n_Continue = 1  
   BEGIN  
      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml  
        
      --Read data from XML  
      INSERT INTO #LCHART_FILTER ([ColumnName], [ColumnValue], [OperationType])   
      SELECT [ColumnName], [ColumnValue], [OperationType]  
      FROM OPENXML (@n_doc, 'Request/Data', 2)  
      WITH (  
         [ColumnName]          NVARCHAR(60)         'ColumnName',  
         [ColumnValue]         NVARCHAR(60)         'ColumnValue',  
         [OperationType]       NVARCHAR(15)         'OperationType'  
      )  
        
      EXEC sp_xml_removedocument @n_doc  
  
      IF @b_debug = 1  
      BEGIN  
         SELECT * FROM #LCHART_FILTER  
      END  
  
      IF EXISTS ( SELECT 1 FROM #LCHART_FILTER )  
      BEGIN  
         SET @c_FullCondition = N' WHERE '  
         SET @b_IsFirstCondition = 1  
  
         DECLARE CUR_LCHART_FILTERING CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT [CSD].[ColumnName], [CSD].[ColumnValue], [CSD].[OperationType]   
         FROM #LCHART_FILTER CSD WITH (NOLOCK)  
  
         OPEN CUR_LCHART_FILTERING  
         FETCH NEXT FROM CUR_LCHART_FILTERING INTO @c_ColumnName, @c_ColumnValue, @c_ColumnOperationType  
     
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT @b_IsFirstCondition = 1  
            BEGIN  
               SET @c_FullCondition = @c_FullCondition + 'AND ' + @c_ColumnName + @c_ColumnOperationType + '''' + @c_ColumnValue + ''' '  
            END  
            ELSE  
            BEGIN  
               SET @b_IsFirstCondition = 0  
               SET @c_FullCondition = @c_FullCondition + @c_ColumnName + @c_ColumnOperationType + '''' + @c_ColumnValue + ''' '  
            END  
  
            FETCH NEXT FROM CUR_LCHART_FILTERING INTO @c_ColumnName, @c_ColumnValue, @c_ColumnOperationType  
         END  
         CLOSE CUR_LCHART_FILTERING  
         DEALLOCATE CUR_LCHART_FILTERING  
      END  
  
      IF @c_Format = 'json'  
      BEGIN  
         SET @c_ExecStatements = --N';WITH XMLNAMESPACES (''http://james.newtonking.com/projects/json'' as json)'
                               N' SELECT @c_ResponseString = ISNULL(RTRIM(( '
                               + ' SELECT  '
                               --+ ' CONVERT(VARCHAR(8), [Date], 3) AS [Date], [CBM_Received], '
                               + ' [Date], CONVERT(NVARCHAR(20),[CBM_Received]) AS CBM_Received, '
                               + '     CONVERT(NVARCHAR(20),[CBM_Shipped]) AS CBM_Shipped, '
                               + '     CONVERT(NVARCHAR(20),[Received_Shipment]) AS Received_Shipment, '
                               + '     CONVERT(NVARCHAR(20),[Shipped_Shipment]) AS Shipped_Shipment  '
                               + ' FROM #LCHART_WAREHOUSEACTIVITIES '
                               + ISNULL(RTRIM(@c_FullCondition), '')
                               + ' FOR JSON PATH, ROOT(''Event'') '
                               --+ ' FOR XML PATH (''Event''), ROOT(''Events'') '
                               + ' )), '''')'  
  
         SET @c_ExecArguments = N'@c_ResponseString NVARCHAR(MAX) OUTPUT'  
  
         IF @b_Debug = 1  
         BEGIN  
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
         END  
  
         EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_ResponseString OUTPUT  

      END  
      ELSE   
      BEGIN  
         --SET @c_ExecStatements = N'SET @c_ResponseString = ISNULL(RTRIM(('  
         --                      + ' SELECT [StorerKey], [TotalPayment], [AddDate]'  
         --                      + ' FROM #LCHART_SAMPLEDATA WITH (NOLOCK)'  
         --                      + ISNULL(RTRIM(@c_FullCondition), '')  
         --                      + ' FOR XML PATH (''Event''), ROOT(''Events''))), '''')'  
           
         SET @c_ExecStatements = --N'SET @c_ResponseString = ISNULL(RTRIM(( '
                               N' SELECT @c_ResponseString = ISNULL(RTRIM(( '
                               + ' SELECT [Date], [CBM_Received], '
                               + '     [CBM_Shipped], [Received_Shipment], [Shipped_Shipment] '
                               + ' FROM #LCHART_WAREHOUSEACTIVITIES '
                               + ISNULL(RTRIM(@c_FullCondition), '')
                               + ' FOR XML PATH (''Event''), ROOT(''Events'') '
                               + ' )), '''')'
  
         SET @c_ExecArguments = N'@c_ResponseString NVARCHAR(MAX) OUTPUT'  
  
         IF @b_Debug = 1  
         BEGIN  
            PRINT '@c_ExecStatements = ' + @c_ExecStatements  
         END  
  
         EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_ResponseString OUTPUT  
      END  
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '>>>>>>>>>> ResponseString' + CHAR(13) + @c_ResponseString  
      END  
  
   END  
  
   QUIT:  
   IF @n_Continue= 3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1   
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartCnt        
         BEGIN        
            COMMIT TRAN        
         END        
 END     
      RETURN        
   END        
   ELSE        
   BEGIN        
      SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END  
END -- Procedure    

GO