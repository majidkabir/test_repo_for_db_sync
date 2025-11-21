SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : isp_SA_Login_AlertNotification                            */
/* Creation Date:  21th May 2009                                           */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: SA Login Alert Notification - Email                            */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: Back-end job                                                 */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/*  5-May-2011 KHLim       1.1   correct the SP version                    */
/*  6-May-2011 KHLim       1.2   SET ANSI_NULLS ON                         */
/***************************************************************************/
CREATE PROC [dbo].[isp_SA_Login_AlertNotification] 
  @cRecipientList NVARCHAR(max), 
  @cServer        NVARCHAR(60) = ''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS ON 
   SET ANSI_WARNINGS ON 

   DECLARE @tableHTML  NVARCHAR(MAX) ;
   DECLARE @emailSubject NVARCHAR(MAX) ;
   DECLARE @Mailitem_id  int 

   DECLARE @cStartDate nvarchar(20), 
           @cEndDate   nvarchar(20)

   SET @cStartDate = Convert(nvarchar(20), GetDate(), 112)
   SET @cEndDate   = Convert(nvarchar(20), GetDate(), 112) + ' 23:59:59'

   DECLARE @t_Result Table (
      LoginId  NVARCHAR(20),
      UserName NVARCHAR(60),
      sdb_name NVARCHAR(40),
      sdb_server NVARCHAR(60),
      sdb_database NVARCHAR(60)
      )
      
   DECLARE @c_SQL NVARCHAR(max)

   SET  @c_SQL = ' select u.usr_login, u.usr_name, db.db_name, db.db_server, db.db_database ' + 
                 ' from ' + @cServer + '.Tsecure.dbo.pl_db db (nolock) ' + 
                 ' join ' + @cServer + '.Tsecure.dbo.pl_usr_db ud (nolock) on db.db_key = ud.db_key ' + 
			  	     ' join ' + @cServer + '.Tsecure.dbo.pl_usr u (nolock) on u.usr_key = ud.usr_key ' +
	       		  ' where db_logid = ''sa'' and u.usr_login <> ''sa'' '

   INSERT INTO @t_Result
   EXEC (@c_SQL)

   IF EXISTS(SELECT 1 FROM @t_Result)
   BEGIN
      SET @tableHTML = 
          N'<H3>The following WMS users still using SA to connect to WMS databases, </H3>' + 
          N'<H3>please help to create a specified connection for this user.</H3>' +
          N'<table border="1">' +
          N'<tr><th>Login ID</th><th>Name</th>' +
          N'<th>Connection Name</th><th>Server Name</th>' +
          N'<th>Database Name</th></tr>' +
          CAST ( ( SELECT td = A.LoginID, '', 
                          td = A.USerName, '', 
                          td = A.sdb_name, '', 
                          td = A.sdb_server, '', 
                          td = A.sdb_database   
                   FROM @t_Result A --WITH (NOLOCK)
                   ORDER BY sdb_database
            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>' + 
          N'<H3>From WMS Global Team.</H3>' ;


      -- SELECT @tableHTML
         
      SET @emailSubject = 'SA Login Alert Notification for Server : ' + @cServer


      EXEC msdb.dbo.sp_send_dbmail 
          @recipients=@cRecipientList,
          @subject = @emailSubject ,
          @body = @tableHTML,
          @body_format = 'HTML',
          @mailitem_id = @Mailitem_id OUTPUT;

      SELECT @Mailitem_id 
   END -- Records Exists
END -- Procedure

GO