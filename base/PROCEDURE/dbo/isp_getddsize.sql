SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetDDSize                                      */
/* Creation Date: 9-Aug-2010                                            */
/* Copyright: IDS                                                       */
/* Written by: LIM KAH HWEE                                             */
/*                                                                      */
/* Purpose: get Disk Drive's space                                      */
/*                                                                      */
/*                                                                      */
/* Called By: ALT - Low Disk Space Notification                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver  Purposes                                    */
/* 2010-08-09  KHLim   1.0  initial revision                            */
/* 2011-11-30  KHLim01 1.1  parameter changes                           */
/************************************************************************/

CREATE PROC [dbo].[isp_GetDDSize]      
(
   @cListTo          NVARCHAR(max),
   @cListCc          NVARCHAR(max),
   @cDriveLetterList NVARCHAR(50),
   @nCriticalMB      int
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Start getting total disk size and free size   
   DECLARE @nDrive   TINYINT,  
           @cBody    NVARCHAR(MAX),  
           @cSubject NVARCHAR(255),
           @SQL      NVARCHAR(4000)

   SET @nDrive = 97  
   SET @cSubject = 'Low Disk Space Notification - ' + @@serverName
   SET @cBody = ''

   -- Setup Staging Area  
   DECLARE @Drives TABLE  
   (
      Drive NVARCHAR(1),
      Info  NVARCHAR(80)
   )

   WHILE @nDrive <= 122
   BEGIN
      SET @SQL = 'EXEC XP_CMDSHELL ''fsutil volume diskfree ' + master.dbo.fnc_GetCharASCII(@nDrive) + ':'''

      INSERT @Drives
      (
         Info
      )
      EXEC (@SQL)

      UPDATE @Drives
      SET Drive = master.dbo.fnc_GetCharASCII(@nDrive)
      WHERE Drive IS NULL

      SET @nDrive = @nDrive + 1  
   END  

   -- Show the expected output  
   SELECT UPPER(DRIVE) + ':' AS DriveLetter,
          Drive,  
          SUM(CASE WHEN Info LIKE 'Total # of bytes             : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS TotalMB,
          SUM(CASE WHEN Info LIKE 'Total # of free bytes        : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS FreeMB,
          SUM(CASE WHEN Info LIKE 'Total # of avail free bytes  : %' THEN CAST(REPLACE(SUBSTRING(Info, 32, 48), master.dbo.fnc_GetCharASCII(13), '') AS BIGINT) ELSE CAST(0 AS BIGINT) END)/ 1024/ 1024 AS AvailFreeMB
   INTO   #dspace  
   FROM  (  
      SELECT Drive,  
             Info  
      FROM   @Drives  
      WHERE  Info LIKE 'Total # of %'  
      ) AS d  
   GROUP BY Drive  
   ORDER BY Drive  
   -- End Get total disk size and free size

   CREATE TABLE #tblDspace
   (
      DriveLetter NVARCHAR(2),
      TotalMB     BIGINT,
      FreeMB      BIGINT,
      [% Free]    NVARCHAR(20)
   )

   SET @SQL = 'INSERT INTO #tblDspace
               SELECT DriveLetter, TotalMB, FreeMB,
                  CAST(CEILING(CAST(REPLACE(FreeMB, '' MB'', '''') AS bigint) 
                   / CAST(REPLACE(TotalMB, '' MB'', '''') AS real) * 100) AS varChar ) + '' %'' AS [% Free]
               FROM #dspace WHERE Drive IN (N''' + REPLACE(@cDriveLetterList,',',''',''') + ''')'
   EXEC (@SQL)
   IF @@ROWCOUNT = 0
   BEGIN
      RAISERROR ('No disk drive found. Please specify valid Drive Letters', 16, 1) WITH SETERROR    -- SQL2012
      --RAISERROR 74321 'No disk drive found. Please specify valid Drive Letters'
      RETURN
   END

   DROP TABLE #dspace

--select * from #tblDspace

   IF EXISTS ( SELECT 1 FROM #tblDspace WHERE FreeMB < @nCriticalMB )
   BEGIN
      SET @cBody = @cBody + N'<table border="1" cellspacing="0" cellpadding="5">' +
          N'<tr bgcolor=silver><th>Drive<br>Letter</th>' +
          N'<th>TotalMB</th><th>FreeMB</th><th>% Free</th></tr>' +  
          CAST ( ( SELECT 'td/@align' = 'center',
                          td = ISNULL(CAST(DriveLetter AS NVARCHAR(2)),''), '',
                          td = ISNULL(CAST(TotalMB AS NVARCHAR(99)),''), '',
                          'td/@bgcolor' = CASE WHEN FreeMB < @nCriticalMB THEN 'red' END,
                          td = ISNULL(CAST(FreeMB AS NVARCHAR(99)),''), '',
                          td = ISNULL(CAST([% Free] AS NVARCHAR(20)),'')
                   FROM #tblDspace
              FOR XML PATH('tr'), TYPE
          ) AS NVARCHAR(MAX) ) + N'</table>' ;

      EXEC msdb.dbo.sp_send_dbmail 
         @recipients      = @cListTo,
         @copy_recipients = @cListCc,
         @subject         = @cSubject,
         @body            = @cBody,
         @body_format     = 'HTML' ;
   END

   DROP TABLE #tblDspace

END -- procedure

GO