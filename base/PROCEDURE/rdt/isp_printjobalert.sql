SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PrintJobAlert                                  */
/* Creation Date:  5-Jul-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: KHLim #SOS220297                                         */
/*                                                                      */
/* Purpose: send email alert for outstanding tasks                      */
/*                                                                      */
/*                                                                      */
/* Called By: SQL Server Agent -> ALT - RDT Print Spooler               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROC [RDT].[isp_PrintJobAlert]  
(
  @nMinute     int            = 5,
  @cListTo     NVarChar(MAX),
  @cListCc     NVarChar(MAX)   = NULL
)
AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE  @cBody    nvarchar(MAX),  
            @cSubject nvarchar(MAX),
            @cSQL     NVarChar(MAX)
   
   SET @cSubject = 'RDT Print Spooler Alert' 

   CREATE TABLE #PrintJob
   (  JobId    int, 
      JobName  NVarChar(50),
      Printer  NVarChar(50),
      Mobile   int,
      TargetDB NVarChar(20),
      AddWho   NVarChar(18),
      AddDate  datetime )


   SET @cSQL = 'INSERT INTO #PrintJob' + CHAR(13)
             + 'SELECT JobId, JobName, Printer, Mobile, TargetDB, AddWho, AddDate' + CHAR(13)
             + 'FROM RDT.RDTPrintJob (nolock)' + CHAR(13)
             + 'WHERE Printer IS NOT NULL AND Printer <> '''' AND JobStatus = ''0''' + CHAR(13)
             + 'AND DateDiff(minute, AddDate, GETDATE()) > ' + CAST(@nMinute AS NVarChar(10)) + CHAR(13)
             + 'ORDER BY AddDate DESC'
--   PRINT @cSQL
   EXEC(@cSQL)

   IF EXISTS (SELECT 1 FROM #PrintJob)
   BEGIN
      SET @cBody = '<b>Outstanding RDT Print Spooler over ' + CAST(@nMinute AS NVarChar(10)) + ' minutes old' + CHAR(13)

      SET @cBody = @cBody + '</b><table border="1" cellspacing="0" cellpadding="5">' +
         '<tr bgcolor=silver>
            <th>JobId</th>
            <th>JobName</th>
            <th>Printer</th>
            <th>Mobile</th>
            <th>TargetDB</th>
            <th>AddWho</th>
            <th>AddDate &dArr;</th></tr>' + CHAR(13) +
         CAST ( ( SELECT td = ISNULL(CAST(JobId AS char(10)),''), '',
            td = ISNULL(CAST(JobName AS NVarChar(50)),''), '',
            td = ISNULL(CAST(Printer AS NVarChar(50)),''), '',
            td = ISNULL(CAST(Mobile AS char(10)),''), '',
            td = ISNULL(CAST(TargetDB AS NVarChar(20)),''), '',
            td = ISNULL(CAST(AddWho AS NVarChar(18)),''), '',  
            td = ISNULL(CAST(AddDate AS NVarChar(30)),'')
         FROM #PrintJob
            FOR XML PATH('tr'), TYPE   
         ) AS nvarchar(MAX) ) + '</table>' ;  

      EXEC msdb.dbo.sp_send_dbmail 
         @recipients      = @cListTo,
         @copy_recipients = @cListCc,
         @subject         = @cSubject,
         @body            = @cBody,
         @body_format     = 'HTML' ;
   END

   DROP TABLE #PrintJob;

END /* main procedure */


GO