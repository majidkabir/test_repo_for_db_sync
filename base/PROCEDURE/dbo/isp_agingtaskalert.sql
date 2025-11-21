SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_AgingTaskAlert                                 */
/* Creation Date: 27-May-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: LIM KAH HWEE                                             */
/*                                                                      */
/* Purpose: send email alert for outstanding tasks                      */
/*                                                                      */
/*                                                                      */
/* Called By: SQL Server Agent -> ALT - Aging Task Alert                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 19-Oct-2011  KHLim01    SOS#216772 additional column - Load Ref      */
/************************************************************************/

CREATE PROC [dbo].[isp_AgingTaskAlert]  
(
  @nHour       int,
  @cStorer     NVARCHAR(200),
  @cListTo     NVARCHAR(MAX),
  @cListCc     NVARCHAR(MAX)
)
AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE  @cBody    nvarchar(MAX),  
            @cSubject nvarchar(MAX),
            @cSQL     NVARCHAR(MAX),
            @cDate    NVARCHAR(20)
   SET @cDate = CONVERT(char(10), getdate(), 103)
   SET @cSubject = 'Aging Task Alert - ' + @cDate

   CREATE TABLE #TaskDet
   (  TaskDetailKey NVARCHAR(10), 
      TaskType NVARCHAR(10),
      Status   NVARCHAR(10),
      AddDate  datetime,
      SKU      NVARCHAR(20),
      FromLoc  NVARCHAR(10),
      ToLoc    NVARCHAR(10),
      Qty      int,
      LoadKey  NVARCHAR(10) )


   SET @cSQL = 'INSERT INTO #TaskDet' + master.dbo.fnc_GetCharASCII(13)
             + 'SELECT TaskDetailKey, TaskType, Status, AddDate, SKU, FromLoc, ToLoc, Qty, LoadKey' + master.dbo.fnc_GetCharASCII(13)
             + 'FROM TaskDetail (nolock)' + master.dbo.fnc_GetCharASCII(13)
             + 'WHERE Status NOT IN (''9'',''X'')' + master.dbo.fnc_GetCharASCII(13)
             + 'AND StorerKey IN (N''' + REPLACE(@cStorer,',',''',''') + ''')' + master.dbo.fnc_GetCharASCII(13)
             + 'AND DateDiff(hour, AddDate, getdate()) > ' + CAST(@nHour AS NVARCHAR(9)) + master.dbo.fnc_GetCharASCII(13)
             + 'ORDER BY AddDate DESC'
--   PRINT @cSQL
   EXEC(@cSQL)

   IF EXISTS (SELECT 1 FROM #TaskDet)
   BEGIN
      SET @cBody = '<b>Outstanding Tasks over ' + CAST(@nHour AS NVARCHAR(9)) + ' hours for Storer: ' + @cStorer + master.dbo.fnc_GetCharASCII(13)
      -- KHLim01 start
      SET @cBody = @cBody + '</b><table border="1" cellspacing="0" cellpadding="5">' +
          '<tr bgcolor=silver><th>Task ID</th><th>Task Type</th><th>Status</th><th>Add Date</th>
                              <th>SKU</th><th>From Loc</th><th>To Loc</th><th>Qty</th><th>Load Ref</th></tr>' + master.dbo.fnc_GetCharASCII(13) +
          CAST ( ( SELECT td = ISNULL(CAST(TaskDetailKey AS NVARCHAR(10)),''), '',
                          td = ISNULL(CAST(TaskType AS NVARCHAR(10)),''), '',
                          td = ISNULL(CAST(Status AS NVARCHAR(10)),''), '',
                          td = ISNULL(CAST(AddDate AS nvarchar(30)),''), '',
                          td = ISNULL(CAST(SKU AS NVARCHAR(20)),''), '',
                          td = ISNULL(CAST(FromLoc AS NVARCHAR(10)),''), '',
                          td = ISNULL(CAST(ToLoc AS NVARCHAR(10)),''), '',  
                          'td/@align' = 'right',
                          td = ISNULL(CAST(Qty AS NVARCHAR(10)),''), '',
                          td = ISNULL(CAST(LoadKey AS NVARCHAR(10)),'')
                   FROM #TaskDet
              FOR XML PATH('tr'), TYPE   
          ) AS nvarchar(MAX) ) + '</table>' ;  
      -- KHLim01 end
      EXEC msdb.dbo.sp_send_dbmail 
         @recipients      = @cListTo,
         @copy_recipients = @cListCc,
         @subject         = @cSubject,
         @body            = @cBody,
         @body_format     = 'HTML' ;
   END

   DROP TABLE #TaskDet;

END /* main procedure */


GO