SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************************/  
/* Stored Procedure: isp_long_run_trace                                                 */  
/* Copyright: IDS                                                                       */  
/* Written by: KHLim                                                                    */  
/* Purpose: send performance trace email                                                */  
/*                                                                                      */  
/* Called By: 00-ALT - WMS Performance Trace Alert                                      */  
/* Updates:                                                                             */  
/* Date         Author        Purposes                                                  */  
/* 2013-May-30  KHLim         extra parameters, esp for LIT   (KH01)                    */  
/* 2013-June-06 CSCHONG       Add in show DB Name in the email (CS01)                   */  
/* 2015-Jun-05  KHLim         remove , TYPE                    (KH02)                   */  
/* 2017-05-11   KHLim    Enhancement & exclude BRKR EVENT HNDLR (KH03)                  */ 
/* 2019-07-22   kocy     Exclude sent email alert for EventType                         */
/*                        = 'NoEvent' AND EventInfo = 'NULL'                            */
/*2019-10-23    kocy02   Exclude sent email alert for Eventifo sys.sp_MScdc_capture_job */
/****************************************************************************************/  
CREATE PROC [dbo].[isp_long_run_trace] (  
   @cCountry   NVARCHAR(255),       --KH03  
   @cListTo    NVARCHAR(max),  
   @cListCc    NVARCHAR(max)  = '',  
   @nLast      int            = 4,  --KH01  
   @nDuration  int            = 20, --KH01  
   @cCategory  NVARCHAR(20)   = ''  --KH01  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_WARNINGS OFF  
  
   DECLARE  @cBody      NVARCHAR(max),  
            @cSubject   NVARCHAR(255),  
            @cImpt      NVARCHAR(6)  
  
   IF EXISTS ( SELECT 1 FROM WMS_sysProcess WITH (nolock)  
                  WHERE DATEDIFF(minute, currenttime, GETDATE()) < @nLast  
                  AND   lastwaittype <> 'BROKER_EVENTHANDLER             ' --KH03  
                  AND   Duration > @nDuration 
                  AND   Eventinfo NOT IN ('', 'sys.sp_MScdc_capture_job'))      --kocy02
   BEGIN  
  
      SET @cImpt = 'Normal'  
      IF EXISTS ( SELECT 1 FROM WMS_sysProcess WITH (nolock)  
                  WHERE DATEDIFF(minute, currenttime, GETDATE()) < @nLast  
                  AND   Duration > 60 )  
      BEGIN  
         SET @cImpt = 'High'  
      END  
  
      SET @cSubject = 'Performance Trace - WMS - ' + @cCountry  
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
            <th>Spid</th>  
            <th>EventInfo</th>  
            <th>MM-dd<br>HH:mm</th>  
            <th>Dura-<br>tion (>'+CAST(@nDuration AS NVARCHAR(9))+''')<br>&dArr;</th>  
             <th>HostName<br><em>DBName</em><br><em>Net_Address</em><br>LogiName<br><em>Program_Name</em></th></tr>'   --(CS01)  
        
      IF @cCategory = 'LIT'  
      BEGIN  
         SET @cBody = @cBody + CAST ( ( SELECT   
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
               td = hostname+'<br><em>'+DB_Name+'</em><br><em>'+net_address+'</em><br>'+MAX(loginame)+'<br><em>'+program_name+'</em>'  --(CS01)  
         FROM  WMS_sysProcess WITH (nolock)  
         WHERE DATEDIFF(minute, currenttime, GETDATE()) < @nLast  
         AND   Duration > @nDuration  
         AND   lastwaittype <> 'BROKER_EVENTHANDLER             ' --KH03  
         AND   RTRIM(program_name) NOT IN ('.Net SqlClient Data Provider','DTS Designer','Exceed 6.0','jTDS','Microsoft SQL Server') AND program_name NOT LIKE 'SQLAgent - TSQL JobStep%'   -- exclude these for LIT  
		   AND   Eventinfo NOT IN ('', 'sys.sp_MScdc_capture_job')  -- kocy02
         GROUP BY spid, Eventinfo, hostname,DB_NAME, program_name, net_address, last_batch    --(CS01)  
         ORDER BY MAX(Duration) DESC  
        FOR XML PATH('tr')    --KH02  
       ) AS NVARCHAR(MAX) ) + '</table>'  
      END  
      ELSE  
      BEGIN  
         SET @cBody = @cBody + CAST ( ( SELECT   
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
                td = hostname+'<br><em>'+DB_Name+'</em><br><em>'+net_address+'</em><br>'+MAX(loginame)+'<br><em>'+program_name+'</em>'  --(CS01)  
         FROM  WMS_sysProcess WITH (nolock)  
         WHERE DATEDIFF(minute, currenttime, GETDATE()) < @nLast  
         AND   Duration > @nDuration  
         AND   lastwaittype <> 'BROKER_EVENTHANDLER             ' --KH03  
         -- only this line varies from query above 
		   AND Eventinfo NOT IN ('', 'sys.sp_MScdc_capture_job')  -- kocy02 
         GROUP BY spid, Eventinfo, hostname,DB_NAME, program_name, net_address, last_batch  --(CS01)  
         ORDER BY MAX(Duration) DESC  
        FOR XML PATH('tr')    --KH02  
       ) AS NVARCHAR(MAX) ) + '</table>'  
      END  
  
      SET @cBody = REPLACE(REPLACE(@cBody,'&lt;','<'),'&gt;','>')  
  

       EXEC msdb.dbo.sp_send_dbmail  
        @recipients      = @cListTo,  
        @copy_recipients = @cListCc,  
        @subject         = @cSubject,  
        @importance      = @cImpt,  
        @body            = @cBody,  
        @body_format     = 'HTML' ;  

   END  
END  

GO