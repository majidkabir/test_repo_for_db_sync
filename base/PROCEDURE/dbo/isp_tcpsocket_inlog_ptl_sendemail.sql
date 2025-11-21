SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_TCPSocket_Inlog_PTL_SendEmail                  */  
/* Creation Date: 14-Mar-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: ChewKP                                                   */  
/*                                                                      */  
/* Purpose: Send email alert for aging and error messages               */  
/*          in TCPSocket_OutLog                                         */  
/*                                                                      */  
/*                                                                      */  
/* Called By: ??                                                        */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_TCPSocket_Inlog_PTL_SendEmail]    
(  
    @cStorerKey         NVARCHAR(15)  
  , @cMessageName       NVARCHAR(50)  
)  
AS  
BEGIN  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
   DECLARE  @cBody         NVARCHAR(MAX),  
            @cSubject      NVARCHAR(255),  
            @cDate         NVARCHAR(20),           
            @c_MessageName NVARCHAR(15) ,  
            @n_Recipient   NVARCHAR(125),  
            @n_Err         INT ,     
            @c_ErrMsg      NVARCHAR(400),  
            @cRecipient1   NVARCHAR(125),  
            @cRecipient2   NVARCHAR(125),  
            @cRecipient3   NVARCHAR(125),  
            @cRecipient4   NVARCHAR(125),  
            @cRecipient5   NVARCHAR(125),  
            @cSocketErrMsg NVARCHAR(400),  
            @cRecipientList NVARCHAR(4000),  
            @cRecipient    NVARCHAR(125),  
            @nCounter      INT,  
            @nSerialNo     INT,  
            @cLocalEndPoint NVARCHAR(50),  
            @cRemoteEndPoint NVARCHAR(50),
            @bData          INT
  
   SET @cDate = CONVERT(CHAR(10), getdate(), 103)  
   SET @cSubject = 'TCPSocket Message Alert - ' + @cDate  
     
   SET @cBody = '<b>The following TCPSocket Message are having errors:</b>'  
   SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">'   
   SET @cBody = @cBody + '<tr bgcolor=silver><th>SerialNo</th><th>Error Message</th><th>LocalEndPoint</th><th>RemoteEndPoint</th></tr>'  
  
   SET @cRecipient1 = ''     
   SET @cRecipient2 = ''     
   SET @cRecipient3 = ''     
   SET @cRecipient4 = ''     
   SET @cRecipient5 = ''    
   SET @cRecipientList = ''  
   SET @nCounter = 1  
   SET @n_Err = 0
   SET @bData = 0
  
  
   -- Get Recipient List  
   SELECT  @cRecipient1 = ISNULL(Recipient1,'')  
         , @cRecipient2 = ISNULL(Recipient2,'')  
         , @cRecipient3 = ISNULL(Recipient3,'')  
         , @cRecipient4 = ISNULL(Recipient4,'')  
         , @cRecipient5 = ISNULL(Recipient5,'')  
   FROM dbo.TCPSocket_Process WITH (NOLOCK)  
   WHERE MessageName = @cMessageName  
     
   DECLARE @tRecipientList TABLE    
   (  
      [Recipient] [nvarchar](125)  
   )  
   
     
   -- Not Recipient Set Goto QUIT  
   IF @cRecipient1 = '' AND @cRecipient2 = '' AND @cRecipient3 = '' AND @cRecipient4 = '' AND @cRecipient5 = ''   
   BEGIN  
      GOTO QUIT  
   END  
   ELSE  
   BEGIN  
      IF @cRecipient1 <> ''  
      BEGIN  
         INSERT INTO @tRecipientList (Recipient)  
         VALUES ( @cRecipient1 )   
      END  
        
      IF @cRecipient2 <> ''  
      BEGIN  
         INSERT INTO @tRecipientList (Recipient)  
         VALUES ( @cRecipient2 )   
      END  
        
      IF @cRecipient3 <> ''  
      BEGIN  
         INSERT INTO @tRecipientList (Recipient)  
         VALUES ( @cRecipient3 )   
      END  
        
      IF @cRecipient4 <> ''  
      BEGIN  
         INSERT INTO @tRecipientList (Recipient)  
         VALUES ( @cRecipient4 )   
      END  
        
      IF @cRecipient5 <> ''  
      BEGIN  
         INSERT INTO @tRecipientList (Recipient)  
         VALUES ( @cRecipient5 )   
      END  
        
        
      DECLARE CursorRecipient CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
         
      SELECT Recipient FROM @tRecipientList  
        
      OPEN CursorRecipient              
        
      FETCH NEXT FROM CursorRecipient INTO @cRecipient  
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN  
           
         IF @nCounter = '1'  
         BEGIN  
            SET @cRecipientList = @cRecipient  
         END     
         ELSE  
         BEGIN  
            SET @cRecipientList = @cRecipientList + ';' + @cRecipient  
         END  
           
         SET @nCounter = @nCounter + 1  
           
         FETCH NEXT FROM CursorRecipient INTO @cRecipient     
           
      END  
      CLOSE CursorRecipient              
      DEALLOCATE CursorRecipient   
   END  
     
   IF ISNULL(@cRecipientList,'')  = ''
   GOTO QUIT
   
   DECLARE CursorOutLog CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
         
   SELECT SerialNo, ErrMsg, LocalEndPoint, RemoteEndPoint  
   FROM dbo.TCPSocket_InLog WITH (NOLOCK)  
   WHERE Status = '5'   
   AND EmailSent = '0'  
   AND StorerKey = @cStorerKey  
     
   OPEN CursorOutLog              
     
   FETCH NEXT FROM CursorOutLog INTO @nSerialNo, @cSocketErrMsg, @cLocalEndPoint, @cRemoteEndPoint   
     
   WHILE @@FETCH_STATUS <> -1       
   BEGIN  
      
      SET @bData = 1
        
      SET @cBody = @cBody + '<tr><td>' + CAST(@nSerialNo AS NVARCHAR(5)) + '</td>'  
      SET @cBody = @cBody + '<td>' + @cSocketErrMsg + '</td>'  
      SET @cBody = @cBody + '<td>' + @cLocalEndPoint + '</td>'  
      SET @cBody = @cBody + '<td>' + @cRemoteEndPoint + '</td>'  
      SET @cBody = @cBody + '</tr>'  
        
        
      UPDATE dbo.TCPSocket_OutLog  
      SET EmailSent = '1'  
      WHERE SerialNo = @nSerialNo     
        
      SET @n_Err = @@ERROR  
      IF @n_Err <> 0  
      BEGIN  
            SELECT @n_Err = 70001  
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Updating TCPSocket_OutLog. (isp_TCPSocket_Inlog_PTL_SendEmail)'  
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
            GOTO QUIT  
      END  
        
      FETCH NEXT FROM CursorOutLog INTO @nSerialNo, @cSocketErrMsg, @cLocalEndPoint, @cRemoteEndPoint   
        
   END  
   CLOSE CursorOutLog              
   DEALLOCATE CursorOutLog   
     
     
   SET @cBody = @cBody + '</table>'  
   
   IF @bData = 0
      GOTO QUIT
   
        
   EXEC msdb.dbo.sp_send_dbmail   
         @recipients      = @cRecipientList,  
         @copy_recipients = NULL,  
         @subject         = @cSubject,  
         @body            = @cBody,  
         @body_format     = 'HTML' ;  
           
   SET @n_Err = @@ERROR  
   IF @n_Err <> 0  
   BEGIN  
         SELECT @n_Err = 70000  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing sp_send_dbmail. (isp_TCPSocket_Inlog_PTL_SendEmail)'  
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
         GOTO QUIT  
   END  
   
  
  
Quit:           
   IF @n_Err <> 0  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCPSocket_Inlog_PTL_SendEmail'     
  
     
  
END -- Procedure  

GO