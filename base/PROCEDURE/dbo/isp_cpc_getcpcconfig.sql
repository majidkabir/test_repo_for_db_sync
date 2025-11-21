SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CPC_GetCPCConfig                               */
/* Creation Date: 13-May-2023                                           */
/* Copyright: Maersk FbM WMS                                            */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To Retrieve Cloud Printing Client Config                    */
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
/* 15-Aug-2023  TKLIM      Respond required fields only                 */
/************************************************************************/
CREATE PROC [dbo].[isp_CPC_GetCPCConfig](  
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
         , @c_JSON                        NVARCHAR(MAX)  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 0  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
   SET @c_PrintClientID                   = ''  
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
   FROM OPENJSON (@c_RequestString)  
   WITH (   
         PrintClientID   VARCHAR(200)   '$.Request.PrintClientID'
   )
   IF @c_PrintClientID = ''
   BEGIN
      SET @n_Continue = 3   
      SET @n_ErrNo = 98994  
      SET @c_ErrMsg = 'Invalid PrintClientID'  
      GOTO QUIT  
   END
   --Proceed Select from CloudPrintConfig table
   SELECT @c_JSON = (
      SELECT PrintClientID, Region, Country, State, WarehouseID, Descr, CloudPrintAPI, ActiveFlag, LogLevel
           , UpdatePIDIntv, TaskPendingDuration, PriorityMode, CPCProcTimeOut, CPCKillTimeoutProc, CPCAutoReprocess
           , EmailSMTPServer, EmailSMTPPort, EmailLogin, EmailPassword, EmailSubject, EmailFrom, EmailTo, EmailCC
           , EmailMaxPerMin, CurrVersion, LastRunIP
      FROM dbo.CloudPrintConfig (NOLOCK)
      WHERE PrintClientID = @c_PrintClientID
      AND ActiveFlag = '1'
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
   )
   --Finalize Response String
   IF ISNULL(@c_JSON,'') <> ''
   BEGIN
      DECLARE  @c_SubThreadInfoJSON     NVARCHAR(1000)       
      SET      @c_SubThreadInfoJSON     = ''  
      SELECT @c_SubThreadInfoJSON =  
            N'[{"Priority":"0", "ThreadCount":"' + ISNULL(RTRIM(ThreadCount),'0') + '"}'
         +  N',{"Priority":"1", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP1),'0') + '"}'
         +  N',{"Priority":"2", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP2),'0') + '"}'
         +  N',{"Priority":"3", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP3),'0') + '"}'
         +  N',{"Priority":"4", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP4),'0') + '"}'
         +  N',{"Priority":"5", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP5),'0') + '"}'
         +  N',{"Priority":"6", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP6),'0') + '"}'
         +  N',{"Priority":"7", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP7),'0') + '"}'
         +  N',{"Priority":"8", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP8),'0') + '"}'
         +  N',{"Priority":"9", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP9),'0') + '"}'
         +  N',{"Priority":"10", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP10),'0') + '"}'
         +  N',{"Priority":"11", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP11),'0') + '"}'
         +  N',{"Priority":"12", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP12),'0') + '"}'
         +  N',{"Priority":"13", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP13),'0') + '"}'
         +  N',{"Priority":"14", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP14),'0') + '"}'
         +  N',{"Priority":"15", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP15),'0') + '"}'
         +  N',{"Priority":"16", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP16),'0') + '"}'
         +  N',{"Priority":"17", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP17),'0') + '"}'
         +  N',{"Priority":"18", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP18),'0') + '"}'
         +  N',{"Priority":"19", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP19),'0') + '"}'
         +  N',{"Priority":"20", "ThreadCount":"' + ISNULL(RTRIM(ThreadCountP20),'0') + '"}]'
      FROM dbo.CloudPrintConfig (NOLOCK)
      WHERE PrintClientID = @c_PrintClientID
      AND ActiveFlag = '1'
      SELECT @c_ResponseString = JSON_MODIFY(@c_JSON, '$.ThreadInfo', JSON_QUERY(@c_SubThreadInfoJSON,'$'));
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