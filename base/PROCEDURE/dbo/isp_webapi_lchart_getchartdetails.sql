SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                
/* Store procedure: isp_WebAPI_LCHART_GetChartDetails                   */                
/* Creation Date: 05-SEP-2017                                           */  
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
/* Version: 1.1                                                        */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Purposes
2023-08-16              Remove fnc_JSON2XML                             */
/************************************************************************/      
CREATE PROC [dbo].[isp_WebAPI_LCHART_GetChartDetails](  
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
           
         , @c_HostKey                     NVARCHAR(40)  
         , @c_StorerKey                   NVARCHAR(15)  
  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''   
   SET @c_XMLRequestString                = ''  
     
   SET @c_HostKey                         = ''  
   SET @c_StorerKey                       = ''  
  
   IF @c_Format = 'json'  
   BEGIN  

      SET @c_XMLRequestString = (
         SELECT * FROM OPENJSON(@c_RequestString,'$.Request')
         WITH (
            [StorerKey]          NVARCHAR(15)
         )
         FOR XML PATH('Request')
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
      SELECT @c_StorerKey        = ISNULL(RTRIM([StorerKey]), '')  
      FROM OPENXML (@n_doc, 'Request', 1)  
      WITH (  
         [StorerKey]          NVARCHAR(15)         'StorerKey'  
      )  
        
      EXEC sp_xml_removedocument @n_doc  
  
      --IF @c_StorerKey = ''  
      --BEGIN  
      --   SET @n_Continue = 3  
      --   SET @n_ErrNo = 50300  
      --   SET @c_ErrMsg = CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --                 + ': HostKey/StorerKey cannot be blank. '  
      --   GOTO QUIT  
      --END  
  
      --IF NOT EXISTS ( SELECT 1 FROM [dbo].[LRPT_Host] WITH (NOLOCK)  
      --                WHERE [HostKey] = @c_HostKey )  
      --BEGIN  
      --   SET @n_Continue = 3  
      --   SET @n_ErrNo = 50301  
      --   SET @c_ErrMsg = CONVERT(NVARCHAR(5),ISNULL(@n_ErrNo,0))   
      --                 + ': Invalid HostKey. '  
      --   GOTO QUIT  
      --END  
  
      IF @c_Format = 'json'  
      BEGIN  
         --;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' as json)
         --SELECT @c_ResponseString = ISNULL(RTRIM(CONVERT(NVARCHAR(MAX),(
         --                        SELECT 'true' AS [@json:Array], [Name], [StorerKey], [RDLCFileName]
         --                        FROM [dbo].[LCHART_Chart_DET] WITH (NOLOCK)
         --                        FOR XML PATH ('Chart'), ROOT('Charts')))), '')
         SELECT @c_ResponseString = ISNULL(RTRIM(CONVERT(NVARCHAR(MAX),(
                                       SELECT ChartName, RDLC, URL,
                                       (
                                          SELECT DET.[Param], DET.DataType
                                                , DET.Label, DET.OperationType
                                          FROM [dbo].[LEAF_Chart_DET] DET WITH (NOLOCK)
                                          WHERE DET.ChartName = HDR.ChartName
                                          FOR JSON PATH, INCLUDE_NULL_VALUES
                                       ) Params
                                       FROM [dbo].[LEAF_Chart_HDR] HDR WITH (NOLOCK)
                                       FOR JSON PATH, ROOT('Charts')
                                    ))), '')
         
         --remove escaped character
         SET @c_ResponseString = REPLACE(@c_ResponseString,'\/','/')

      END  
      ELSE   
      BEGIN  
         SET @c_ResponseString = ISNULL(RTRIM(CONVERT(NVARCHAR(MAX),(  
                                    SELECT ChartName, RDLC, URL,  
                                    (  
                                       SELECT DET.[Param], DET.DataType  
                                            , DET.Label, DET.OperationType  
                                       FROM [dbo].[LEAF_Chart_DET] DET WITH (NOLOCK)  
                                       WHERE DET.ChartName = HDR.ChartName  
                                       FOR XML PATH('Params'), TYPE  
                                    )   
                                    FROM [dbo].[LEAF_Chart_HDR] HDR WITH (NOLOCK)  
                                    FOR XML PATH ('Chart'), type, ROOT('Charts')  
                                 ))), '')  
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