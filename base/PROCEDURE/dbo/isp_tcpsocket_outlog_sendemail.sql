SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_TCPSocket_Outlog_SendEmail                     */
/* Creation Date: 23-FEB-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Reprocess and send email alert for aging and error messages */
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
/* 17-05-2012   Chee       Bug Fix (Chee01)                             */
/************************************************************************/

CREATE PROC [dbo].[isp_TCPSocket_Outlog_SendEmail]  
(
  @nMinute       INT
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
            @c_ErrMsg      NVARCHAR(400)

   SET @cDate = CONVERT(CHAR(10), getdate(), 103)
   SET @cSubject = 'TCPSocket Message Alert - ' + @cDate

   CREATE TABLE #OutLog_MessageTemp
   ( SerialNo     INT, 
     MessageName  NVARCHAR(15), 
     MessageNum   NVARCHAR(8),
     Status       NVARCHAR(1),
     AddDate      DATETIME,
     Recipient1   NVARCHAR(125) NULL,
     Recipient2   NVARCHAR(125) NULL,
     Recipient3   NVARCHAR(125) NULL,
     Recipient4   NVARCHAR(125) NULL,
     Recipient5   NVARCHAR(125) NULL,
     BatchNo      NVARCHAR(50)  NULL
   )

   --Reprocess outstanding message in TCPSocket_OutLog 
   EXEC isp_TCPSocket_OutLog_Reprocess_Message @nMinute

   SET @n_Err = @@ERROR
   IF @n_Err <> 0
   BEGIN
      SELECT @n_Err = 70000
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing isp_Reprocess_TCPSocket_OutLog_Message. (isp_TCPSocket_Outlog_SendEmail)'
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )' 
      GOTO QUIT
   END

   IF EXISTS (SELECT 1 FROM #OutLog_MessageTemp)
   BEGIN
      -- Create temp table to store all possible user.
      CREATE TABLE #RecipientTemp
      ( Recipient NVARCHAR(125))

      -- Get all possible recipient and insert into #RecipientTemp
      DECLARE cur_Get_Recipient CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT MessageName
      FROM #OutLog_MessageTemp WITH (NOLOCK)

      -- Open Cursor
      OPEN cur_Get_Recipient 

      FETCH NEXT FROM cur_Get_Recipient INTO @c_MessageName

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         INSERT INTO #RecipientTemp
         select recipient1 FROM TCPSOCKET_PROCESS WITH (NOLOCK) 
         WHERE MessageName = @c_MessageName 
         --AND recipient1 IS NOT NULL (Chee01)
         AND ISNULL(recipient1, '') <> '' 
         AND recipient1 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))
         UNION
         select recipient2 FROM TCPSOCKET_PROCESS WITH (NOLOCK) 
         WHERE MessageName = @c_MessageName
         --AND recipient2 IS NOT NULL (Chee01)
         AND ISNULL(recipient2, '') <> ''
         AND recipient2 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))
         UNION
         select recipient3 FROM TCPSOCKET_PROCESS WITH (NOLOCK) 
         WHERE MessageName = @c_MessageName 
         --AND recipient3 IS NOT NULL (Chee01)
         AND ISNULL(recipient3, '') <> '' 
         AND recipient3 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))
         UNION
         select recipient4 FROM TCPSOCKET_PROCESS WITH (NOLOCK) 
         WHERE MessageName = @c_MessageName 
         --AND recipient4 IS NOT NULL (Chee01)
         AND ISNULL(recipient4, '') <> '' 
         AND recipient4 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))
         UNION
         select recipient5 FROM TCPSOCKET_PROCESS WITH (NOLOCK) 
         WHERE MessageName = @c_MessageName 
         --AND recipient5 IS NOT NULL (Chee01)
         AND ISNULL(recipient5, '') <> '' 
         AND recipient5 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70001
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Insert into #RecipientTemp Table. (isp_TCPSocket_Outlog_SendEmail)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO Quit
         END

         -- Fetch Next From Cursor
         FETCH NEXT FROM cur_Get_Recipient INTO @c_MessageName

      END -- WHILE @@FETCH_STATUS <> -1

      -- Close Cursor
      CLOSE cur_Get_Recipient 
      DEALLOCATE cur_Get_Recipient

      -- Send email by user
      WHILE EXISTS (SELECT 1 FROM #RecipientTemp WITH (NOLOCK))
      BEGIN
         SELECT TOP 1 @n_Recipient = Recipient 
         FROM #RecipientTemp WITH (NOLOCK)

         SET @cBody = '<b>The following message over ' + CAST(@nMinute AS NVARCHAR(9)) + ' minutes in TCPSocket_OutLog has been re-processed:</b>'
         
         IF EXISTS (SELECT 1 FROM #OutLog_MessageTemp WITH (NOLOCK) WHERE Status = '0')
         BEGIN
            SET @cBody = @cBody + '<br /><i>Reprocess Aging Message (Status = 0):</i>'
            SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +
                '<tr bgcolor=silver><th>SerialNo</th><th>Message Name</th><th>Message Number</th><th>Add Date</th></tr>' + master.dbo.fnc_GetCharASCII(13) +
                CAST ( ( SELECT td = ISNULL(CAST(SerialNo AS NVARCHAR(9)),''), '',
                                td = ISNULL(CAST(MessageName AS NVARCHAR(15)),''), '',  
                                td = ISNULL(CAST(MessageNum AS NVARCHAR(8)),''), '', 
                                td = ISNULL(CAST(AddDate AS NVARCHAR(30)),'')
                         FROM #OutLog_MessageTemp WITH (NOLOCK)
                         WHERE (Recipient1 = @n_Recipient
                         OR Recipient2 = @n_Recipient
                         OR Recipient3 = @n_Recipient
                         OR Recipient4 = @n_Recipient
                         OR Recipient5 = @n_Recipient)
                         AND Status = '0'
                    FOR XML PATH('tr'), TYPE   
                ) AS NVARCHAR(MAX) ) + '</table>' ;  
         END

         IF EXISTS (SELECT 1 FROM #OutLog_MessageTemp WITH (NOLOCK) WHERE Status = '5')
         BEGIN
            SET @cBody = @cBody + '<br /><i>Reprocess Error Message (Status = 5):</i>'
            SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +
                '<tr bgcolor=silver><th>SerialNo</th><th>Message Name</th><th>Message Number</th><th>Add Date</th></tr>' + master.dbo.fnc_GetCharASCII(13) +
                CAST ( ( SELECT td = ISNULL(CAST(SerialNo AS NVARCHAR(9)),''), '',
                                td = ISNULL(CAST(MessageName AS NVARCHAR(15)),''), '',  
                                td = ISNULL(CAST(MessageNum AS NVARCHAR(8)),''), '', 
                                td = ISNULL(CAST(AddDate AS NVARCHAR(30)),'')
                         FROM #OutLog_MessageTemp WITH (NOLOCK)
                         WHERE (Recipient1 = @n_Recipient
                         OR Recipient2 = @n_Recipient
                         OR Recipient3 = @n_Recipient
                         OR Recipient4 = @n_Recipient
                         OR Recipient5 = @n_Recipient)
                         AND Status = '5'
                    FOR XML PATH('tr'), TYPE   
                ) AS NVARCHAR(MAX) ) + '</table>' ;  
         END

         IF EXISTS (SELECT 1 FROM #OutLog_MessageTemp WITH (NOLOCK) WHERE Status = '9')
         BEGIN
            SET @cBody = @cBody + '<br /><i>Reprocess message that Receive NAK message:</i>'
            SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +
                '<tr bgcolor=silver><th>SerialNo</th><th>Message Name</th><th>Message Number</th><th>Add Date</th></tr>' + master.dbo.fnc_GetCharASCII(13) +
                CAST ( ( SELECT td = ISNULL(CAST(SerialNo AS NVARCHAR(9)),''), '',
                                td = ISNULL(CAST(MessageName AS NVARCHAR(15)),''), '',  
                                td = ISNULL(CAST(MessageNum AS NVARCHAR(8)),''), '', 
                                td = ISNULL(CAST(AddDate AS NVARCHAR(30)),'')
                         FROM #OutLog_MessageTemp WITH (NOLOCK)
                         WHERE (Recipient1 = @n_Recipient
                         OR Recipient2 = @n_Recipient
                         OR Recipient3 = @n_Recipient
                         OR Recipient4 = @n_Recipient
                         OR Recipient5 = @n_Recipient)
                         AND Status = '9'
                    FOR XML PATH('tr'), TYPE   
                ) AS NVARCHAR(MAX) ) + '</table>' ;  
         END

         EXEC msdb.dbo.sp_send_dbmail 
            @recipients      = @n_Recipient,
            @copy_recipients = NULL,
            @subject         = @cSubject,
            @body            = @cBody,
            @body_format     = 'HTML' ;
            
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70002
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing sp_send_dbmail. (isp_TCPSocket_Outlog_SendEmail)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO QUIT
         END

         DELETE FROM #RecipientTemp
         WHERE Recipient = @n_Recipient
         
         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Err = 70003
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error delete from #RecipientTemp Table. (isp_TCPSocket_Outlog_SendEmail)'
                             + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
            GOTO QUIT
         END
      END -- WHILE EXISTS (SELECT 1 FROM #RecipientTemp WITH (NOLOCK))

      -- UPDATE EmailSent to 1
      UPDATE TCPSocket_OutLog WITH (ROWLOCK)
      SET EmailSent = '1'
      FROM TCPSocket_OutLog o 
      JOIN #OutLog_MessageTemp t ON (o.SerialNo = t.SerialNo)

      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Err = 70004
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error updating TCPSocket_OutLog Table. (isp_TCPSocket_Outlog_SendEmail)'
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'
         GOTO QUIT
      END
   END -- IF EXISTS (SELECT 1 FROM #OutLog_MessageTemp)  

Quit:         
   IF @n_Err <> 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCPSocket_Outlog_SendEmail'   

   IF (SELECT CURSOR_STATUS('local','cur_Get_Recipient')) >=0 
   BEGIN
      CLOSE cur_Get_Recipient           
      DEALLOCATE cur_Get_Recipient      
   END  

   IF OBJECT_ID('tempdb..#OutLog_MessageTemp','u') IS NOT NULL
      DROP TABLE #OutLog_MessageTemp;

   IF OBJECT_ID('tempdb..#RecipientTemp','u') IS NOT NULL
      DROP TABLE #RecipientTemp

END -- Procedure

GO