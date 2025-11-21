SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WebAPI_CallMyFullName                           */              
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
/* Version: 1.1                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes
2023-08-16              Remove fnc_JSON2XML                             */
/************************************************************************/    
CREATE PROC [dbo].[isp_WebAPI_CallMyFullName](
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
         , @c_FirstName                   NVARCHAR(100)
         , @c_LastName                    NVARCHAR(100)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   SET @c_XMLRequestString                = ''
   
   SET @c_FirstName                       = ''
   SET @c_LastName                        = ''

   IF ISNULL(RTRIM(@c_RequestString), '') = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 98991
      SET @c_ErrMsg = 'Content Body cannot be blank.'
      GOTO QUIT
   END

   IF @c_Format = 'json'
   BEGIN

      SET @c_XMLRequestString = (
      SELECT * FROM OPENJSON(@c_RequestString,'$.Request')
      WITH (
         [FirstName]             NVARCHAR(100),
         [LastName]              NVARCHAR(100)
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

   STEP_1:
   IF @n_Continue = 1
   BEGIN
      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml
      
      --Read data from XML
      SELECT @c_FirstName        = ISNULL(RTRIM([FirstName]), '')
            ,@c_LastName         = ISNULL(RTRIM([LastName]), '')
      FROM OPENXML (@n_doc, 'Request', 1)
      WITH (
         [FirstName]             NVARCHAR(100)        'FirstName',
         [LastName]              NVARCHAR(100)        'LastName'
      )
      
      EXEC sp_xml_removedocument @n_doc

      IF @c_FirstName = ''
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 98992
         SET @c_ErrMsg = 'FirstName cannot be blank.'
         GOTO QUIT
      END

      IF @c_LastName = ''
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 98993
         SET @c_ErrMsg = 'LastName cannot be blank.'
         GOTO QUIT
      END

   END

   STEP_2:
   IF @n_Continue = 1 
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT '>>>>>>>>>> Request Data' + CHAR(13) 
             + 'FirstName: ' + @c_FirstName + ' , LastName: ' + @c_LastName 
      END

      SET @c_ResponseString = ISNULL(RTRIM(
                              ( 
                                 SELECT ('Your full name is ' + @c_FirstName + " " + @c_LastName) AS [Message] 
                                 FOR XML PATH ('Response') 
                              ) ), '')
   END

   IF @c_Format = 'json'
   BEGIN

      SET @c_ResponseString = ISNULL(RTRIM(
                              ( 
                                 SELECT JSON_QUERY(
                                 (SELECT ('Your full name is ' + @c_FirstName + " " + @c_LastName) AS [Message] 
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS 'Response' 
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                              ) ), '') 
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