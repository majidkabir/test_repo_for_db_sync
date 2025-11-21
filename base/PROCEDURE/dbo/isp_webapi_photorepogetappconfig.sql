SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/              
/* Store procedure: isp_WebAPI_PhotoRepoGetAppConfig                    */              
/* Creation Date: 05-JAN-2018                                           */
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
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2018-01-15  Alex     #CR WMS-5241 - v2.0 (Alex02)                    */
/************************************************************************/    
CREATE PROC [dbo].[isp_WebAPI_PhotoRepoGetAppConfig](
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
         
         , @c_SearchType                  NVARCHAR(10)

         , @c_WhereClauseCondi            NVARCHAR(500)

         , @c_SKUStsSuspended             NVARCHAR(15)      --(Alex01)
         , @c_ListNamePhotoRConf          NVARCHAR(10)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   SET @c_XMLRequestString                = ''

   SET @c_SearchType                      = ''

   SET @c_WhereClauseCondi                = ''

   SET @c_ListNamePhotoRConf              = 'PhotoRConf'

   IF ISNULL(RTRIM(@c_RequestString), '') = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 97011
      SET @c_ErrMsg = 'Content Body cannot be blank.'
      GOTO QUIT
   END

   SET @x_xml = CONVERT(XML, @c_RequestString)

   STEP_1:
   IF @n_Continue = 1
   BEGIN
      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml
      
      --Read data from XML
      SELECT @c_SearchType = ISNULL(RTRIM(SearchType), '')   
      FROM OPENXML (@n_doc, 'Request/Data', 1)
      WITH (
         SearchType        NVARCHAR(10)   'SearchType'
      )
      
      EXEC sp_xml_removedocument @n_doc

      IF @c_SearchType NOT IN ('SKU')
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 97012
         SET @c_ErrMsg = 'Invalid SearchType[' + @c_SearchType + ']..'
         GOTO QUIT
      END

      IF @c_SearchType = 'SKU'
      BEGIN
         SET @c_ExecStatements = N'SELECT @c_ResponseString = ISNULL(RTRIM(( ' + CHAR(13)
                               + N' SELECT ( ' + CHAR(13)
                               + N'    SELECT ISNULL(RTRIM(Code), '''') As ''Code'', '
                               + N'       ISNULL(RTRIM(Code2), '''') AS ''Code2'', '
                               + N'       ISNULL(RTRIM(StorerKey), '''') As ''StorerKey'' '  + CHAR(13)
                               + N'    FROM dbo.CODELKUP WITH (NOLOCK) ' + CHAR(13)
                               + N'    WHERE ListName = @c_ListNamePhotoRConf '
                               + N'    FOR XML PATH (''Data''), TYPE ) ' --, ROOT(''Response'') '
                               + N' FOR XML PATH(''Response'')'
                               + N')), '''') '
         SET @c_ExecArguments = N'@c_ListNamePhotoRConf NVARCHAR(10), @c_ResponseString NVARCHAR(MAX) OUTPUT'

         IF @b_Debug = 1
         BEGIN
            PRINT '>>>>>> Generate RESPONSE XML QUERY'
            PRINT @c_ExecStatements
         END

         EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_ListNamePhotoRConf, @c_ResponseString OUTPUT
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