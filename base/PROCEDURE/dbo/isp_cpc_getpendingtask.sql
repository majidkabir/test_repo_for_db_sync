SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CPC_GetPendingTask                             */
/* Creation Date: 13-May-2023                                           */
/* Copyright: Maersk FbM WMS                                            */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To Retrieve Print Task for Cloud Printing Client.           */
/*          Cloud Printing Client hosted in Spooler Server in Warehouse */
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
/* Called By: IntranetAPIServer - isp_Generic_WebAPI_Request            */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 13-May-2023  TKLIM      Initial                                      */
/* 25-Jul-2023  TKLIM      Add MoveToArchive for archive after print    */
/************************************************************************/
CREATE PROC [dbo].[isp_CPC_GetPendingTask](  
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
         , @c_PrintClientID               NVARCHAR(100)  
         , @c_LastID                      NVARCHAR(20)  
         , @c_JSON                        NVARCHAR(MAX)  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
   SET @c_PrintClientID                   = ''  
   SET @c_LastID                          = ''  
   SET @c_JSON                            = ''  
  --Validations
   IF ISNULL(RTRIM(@c_RequestString), '') = ''  
   BEGIN  
      SET @n_Continue = 3   
      SET @n_ErrNo = 98991  
      SET @c_ErrMsg = 'Content Body cannot be blank.'  
      GOTO QUIT  
   END
   IF ISNULL(RTRIM(UPPER(@c_Format)), '') <> 'JSON' 
   BEGIN
      SET @n_Continue = 3   
      SET @n_ErrNo = 98992  
      SET @c_ErrMsg = 'Content body type must be JSON'  
      GOTO QUIT  
   END
   IF ISJSON(@c_RequestString) = 0
   BEGIN
      SET @n_Continue = 3   
      SET @n_ErrNo = 98993  
      SET @c_ErrMsg = 'Content body is not valid JSON'  
      GOTO QUIT  
   END
   --Get PrintClientID from Request String JSON
   SELECT @c_PrintClientID = ISNULL(RTRIM(PrintClientID),'')
        , @c_LastID = ISNULL(RTRIM(LastID),'0')
   FROM OPENJSON (@c_RequestString)  
   WITH (   
         PrintClientID   NVARCHAR(200)  '$.Request.PrintClientID',
         LastID          NVARCHAR(20)   '$.Request.LastID'
   )
   IF @c_PrintClientID = ''
   BEGIN
      SET @n_Continue = 3   
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid PrintClientID'  
      GOTO QUIT  
   END
   IF ISNUMERIC(@c_LastID) = 0
   BEGIN
      SET @c_LastID = '0'
   END
   --Proceed Select from CloudPrintConfig table
   SELECT @c_JSON = (
      SELECT ID
            ,PrintClientID
            ,CmdType
            ,B64Command
            ,B64FileSrc
            ,IP
            ,Port
            ,Timeout
            ,PrinterName
            ,RefDocType
            ,RefDocID
            ,RefJobID
            ,RefDesc
            ,Priority
            ,PaperSizeWxH
            ,DCropWidth
            ,DCropHeight
            ,IsLandScape
            ,IsColor
            ,IsDuplex
            ,IsCollate
            ,PrintCopy
            ,MoveToArchive
      FROM dbo.CloudPrintTask (NOLOCK)
      WHERE PrintClientID = @c_PrintClientID
      AND Status = '0'
      AND ID > @c_LastID
      ORDER BY ID ASC
      FOR JSON PATH
   )
   --Finalize Response String
   IF ISNULL(@c_JSON,'') <> ''
   BEGIN
      SET @c_ResponseString = @c_JSON
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