SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_long_run_kill                                  */
/* Creation Date: 2012-May-08                                           */
/* Copyright: IDS                                                       */
/* Written by: KHLim                                                    */
/*                                                                      */
/* Purpose: Kill long-running process & send email                      */
/*                                                                      */
/* Called By: ALT - WMS Performance Trace Alert                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2013-Aug-15  KHLim         add a parameter as threshold value (KH01) */
/* 2014-Jul-11  KHLim         add a parameter as threshold value (KH02) */
/* 2016-Oct-11  JayLim       add SET ROWCOUNT pattern                  */
/*                            increase spid nvarchar(3) to (9) (Jay01)  */
/* 2018-Aug-01  TLTING        hyperion user filter                      */
/* 2019-Arp-08  TLTING        multiple kill                             */
/* 2023-Feb-10  TLTING01      avoid leading space                       */
/************************************************************************/
CREATE   PROC [dbo].[isp_long_run_kill] (
   @cCountry   NVARCHAR(5),
   @cListTo    NVARCHAR(max),
   @cListCc    NVARCHAR(max) = '',
   @nLast      int          = 3   -- minute (follow longest frequency of the SQL scheduled job)
  ,@nDuration  int          = 120 -- minute (minimum duration of a process    to be killed) KH01
  ,@nDuration2 int          = 60  -- minute (minimum duration of SQLAgent job to be killed) KH02
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE  @cBody      NVARCHAR(max),
            @cSubject   NVARCHAR(255),
            @cImpt      NVARCHAR(6),
            @cPattern   NVARCHAR(800),
            @cPattern2  NVARCHAR(800),
            @cPattern3  NVARCHAR(800), -- (Jay01)
            @cEventInfo nvarchar(4000);
   DECLARE  @SPID       smallint,
            @sql        NVARCHAR(150),
            @cDBCCInfo  nvarchar(4000)

   SET @cImpt     = 'Normal'
   SET @cPattern  = 'SELECT %'   -- SQL pattern of EventInfo
   SET @cPattern3 = 'SET ROWCOUNT %' -- (Jay01)
   SET @cPattern2  = '%sp_updatestats%'   -- AND LEFT(program_name,8)='SQLAgent' (only job that invoked by SQLAgent schedule)

   Create TABLE #WMS_LongQuery
      ( spid   smallint,
        Eventinfo   nvarchar(4000) NULL
      )

   Create TABLE #WMS_Trace
      ( EventType   nvarchar(60) NULL,
      parameters   int NULL,
      Eventinfo   nvarchar(4000) NULL
      )

   INSERT INTO #WMS_LongQuery (spid,  Eventinfo)
   SELECT TOP 5 spid, Eventinfo
   FROM WMS_sysProcess WITH (nolock)
   WHERE DATEDIFF(minute, currenttime, GETDATE()) <= @nLast
   AND ( ( Duration > @nDuration AND LTRIM(Eventinfo) LIKE @cPattern )     -- TLTING01
      OR ( Duration > @nDuration AND LTRIM(Eventinfo) LIKE @cPattern3 )    -- TLTING01 -- (Jay01)
      OR ( Duration > @nDuration2 AND LTRIM(Eventinfo) LIKE @cPattern2  AND LEFT(program_name,8)='SQLAgent') )   -- TLTING01
   GROUP BY spid, Eventinfo, hostname, program_name, net_address, last_batch
   ORDER BY MAX(Duration) DESC

   IF EXISTS ( SELECT 1 FROM #WMS_LongQuery )
   BEGIN
      DECLARE Items_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	      Select spid,
            Eventinfo
      FROM #WMS_LongQuery
      Order by spid

      OPEN Items_cur
      FETCH NEXT FROM Items_cur INTO @SPID, @cEventInfo
      WHILE @@FETCH_STATUS = 0
      BEGIN

         Delete from #WMS_Trace


         SELECT @sql = 'DBCC INPUTBUFFER (' + CAST(@SPID as NVARCHAR(9)) + ')'
         INSERT INTO  #WMS_Trace (EventType, Parameters, EventInfo)
         EXEC (@sql)

         SELECT @cDBCCInfo = Eventinfo
         FROM #WMS_Trace


         IF @cEventInfo = @cDBCCInfo
         BEGIN
            SELECT @sql = 'KILL ' + CAST(@SPID as NVARCHAR(9)) + ''
            EXEC (@sql)

            SET @cImpt = 'High'

            SET @cSubject = 'Performance Trace - WMS - ' + @cCountry + '- Process Killed'
            SET @cBody = '<style type="text/css">
               table {  font-family: Arial Narrow; border-collapse:collapse; }
               table, td, th { border:1px solid #686868; padding:3px; }
               tr.g  {  background-color: #D3D3D3 }
               th    {  font-size: 13px; }
               td    {  font-size: 12px; }
               .c    {  text-align: center; }
               span.warn { color:#FF0000; }
               </style>'

            SET @cBody = @cBody + 'Server Name: '+ @@ServerName + '<table><tr class=g>
                  <th><span class=warn>Spid KILLED</span></th>
                  <th>EventInfo</th>
                  <th>MM-dd<br>HH:mm</th>
                  <th>Dura-<br>tion (>'+CAST(@nDuration AS NVARCHAR(9))+''')<br>&dArr;</th>
                  <th>HostName<br><em>Net_Address</em><br>LogiName<br><em>Program_Name</em></th></tr>' +
                        CAST ( ( SELECT TOP 1
                        td = spid, '',
                        td = Eventinfo, '',
                        'td/@class' = 'c',
                        td = CASE WHEN last_batch = MAX(currenttime)
                                 THEN RIGHT(CONVERT(varchar(16),last_batch,120),11)
                                 WHEN CONVERT(varchar(8),last_batch,2) = CONVERT(varchar(8),MAX(currenttime),2)
                                 THEN RIGHT(CONVERT(varchar(16),last_batch,120),11) + '<br>to<br>'
                                       + RIGHT(CONVERT(varchar(16),MAX(currenttime),120),5)
                                 ELSE  RIGHT(CONVERT(varchar(16),last_batch,120),11) + '<br>to<br>'
                                       + RIGHT(CONVERT(varchar(16),MAX(currenttime),120),11)
                                 END, '',
                        'td/@class' = 'c',
                        td = '<strong>' + CASE WHEN MAX(Duration) > 60
                                       THEN '<span class=warn>' + CAST(MAX(Duration)/60 AS NVARCHAR(9)) + ' h</span><br>' + CAST(MAX(Duration)%60 AS NVARCHAR(9))
                                       ELSE CAST(MAX(Duration) AS NVARCHAR(9)) END + ' min', '',
                        td = hostname+'<br><em>'+net_address+'</em><br>'+MAX(loginame)+'<br><em>'+program_name+'</em>'
               FROM  WMS_sysProcess WITH (nolock)
               WHERE DATEDIFF(minute, currenttime, GETDATE()) <= @nLast
               AND ( ( Duration > @nDuration AND Eventinfo LIKE @cPattern )
                  OR ( Duration > @nDuration AND Eventinfo LIKE @cPattern3 )
                  OR ( Duration > @nDuration2 AND Eventinfo LIKE @cPattern2  AND LEFT(program_name,8)='SQLAgent') )
               GROUP BY spid, Eventinfo, hostname, program_name, net_address, last_batch
               ORDER BY MAX(Duration) DESC
               FOR XML PATH('tr'), TYPE
               ) AS NVARCHAR(MAX) ) + '</table>'

            SET @cBody = REPLACE(REPLACE(@cBody,'&lt;','<'),'&gt;','>')

            EXEC msdb.dbo.sp_send_dbmail
               @recipients      = @cListTo,
               @copy_recipients = @cListCc,
               @subject         = @cSubject,
               @importance      = @cImpt,
               @body            = @cBody,
               @body_format     = 'HTML' ;
         END

		   FETCH NEXT FROM Items_cur INTO @SPID, @cEventInfo
	   END
	   CLOSE Items_cur
	   DEALLOCATE Items_cur
   END
END

GO