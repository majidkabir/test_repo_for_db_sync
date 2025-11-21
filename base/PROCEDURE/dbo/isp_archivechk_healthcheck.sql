SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************************/            
/* Creation Date: 2-Apr-2010                                                                       */            
/* Written by: KHLim                                                                               */            
/* Purpose: combine isp_archivechk, isp_healthcheck in an email                                    */            
/* Called BY: ALT - WMS AutoCheck Email Alert                                                      */ 
/*                                                                                                 */ 
/* Date         Author        Ver Purposes                                                         */            
/* 11 May 2010  TLTING        1.1 Blcoking infor                                                   */            
/* 2 June 2010  KHLim         1.2 fix condition of blocking last 24 hr                             */            
/* 12-Nov-2010  TLTING        1.3 Cast Qty                                                         */            
/* 11-Apr-2011  KHLim         1.4 add anchor tag, increase 1.5m &improve layout                    */            
/*  9-Mar-2012  KHLim         1.5 add AlertCnt, improve SQL & HTML standard (KH01)                 */            
/* 15-May-2012  KHLim         1.6 add TOP 50 to limit the result            (KH02)                 */            
/* 21-May-2013  KHLim         1.7 upgrade psuptime to PsInfo                (KH03)                 */            
/* 18-Jan-2017  KHLim         1.8 update the path of PsInfo                 (KH04)                 */            
/* 26-Sep-2018  CJKhor        1.9 Sort the BlockDate Descending (CJ01)                             */            
/* 02-Oct-2018  KHLim         2.0 Make table row limit as variable (KH05)                          */            
/* 13-feb-2020  kelvinongcy   2.1 Change Server Uptime to 14 days then alert (kocy01)              */            
/* 01-Apr-2020  kelvinongcy   2.2 Change Server Uptime to 21 days then alert due to some           */            
/*                                of month consist 5 weeks (kocy02)                                */          
/* 04-May-2021  kelvinongcy   2.3 try alternative way to replace xp_cmdshell ( kocy03)             */           
/* 28-Sep-2021  kelvinongcy   2.4 revise Server Uptime alert to 30 days for CN (kocy04)            */        
/* 10-Oct-2021  kelvinongcy   2.4 revise Server Uptime alert to 60 days for CN (kocy05)            */         
/* 20-Jan-2022  kelvinongcy   2.5 added WMS-18569 UCC integrity check (kocy06)                     */        
/* 25-Jan-2022  kelvinongcy   2.6 some enhancement for exclude countries not perform UCC integrity */        
/*                                check (add storerconfig.Option1 = 'DailyIntegrity') (kocy07)     */        
/* 09-Feb-2022  kelvinongcy   2.7 WMS-18569 FBR 1.2 added Storerkey in compare Pickdetail          */      
/*                                and OrderDetail  (kocy08) for PH                                 */    
/* 16-Feb-2022  kelvinongcy   2.8 WMS-18569 FBR 1.3 added Storerkey in entire health check part    */    
/*                               if missing any  (kocy09) for PH                                   */    
/* 17-Feb-2022  kelvinongcy   2.9 WMS-18569 FBR 1.4 change health check UCC Status to 1,2,3        */          
/*                                from status 1,3,5 (kocy10) for PH                                */   
/* 17-Nov-2022  kelvinongcy   3.0 WMS-21201  skip healthcheck for both order/pick detail           */
/*                                according to the storerconfig set in KR (kocy11)                 */   
/* 23-Oct-2023  TLTING        3.1 Add TNTLog                                                       */
/***************************************************************************************************/            
CREATE     PROC [dbo].[isp_archivechk_HealthCheck]            
(            
   @cCountry   NVARCHAR(5),            
   @cListTo    NVARCHAR(max),            
   @cListCc    NVARCHAR(max) = ''            
  ,@nTableRow  INT = 1500000  --KH05            
)            
AS            
BEGIN            
            
   SET NOCOUNT ON            
   SET QUOTED_IDENTIFIER OFF            
   SET ANSI_NULLS OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
            
   DECLARE @cBody       nvarchar(max),            
           @cBodyHead   nvarchar(max),            
           @cSubject    nvarchar(255),            
           @nIssueCnt   int,            
           @nAlertCnt   int,           -- KH01            
           @cImpt       NVARCHAR(6),    -- KH01            
           @cTable      NVARCHAR(257),  -- KH01            
           @nRow        int,           -- KH01            
           @dMin        datetime,      -- KH01            
           @dMax        datetime,      -- KH01            
           @nJ          int            -- KH01            
            
   SET @cSubject = 'WMS AutoCheck Email Alert - ' + @cCountry  -- KH01            
   SET @nIssueCnt = 0            
   SET @nAlertCnt = 0            
   SET @cImpt = 'Low'            
            
   SET @cBodyHead = N'<style type="text/css">            
      p.a1  {  font-family: Arial; font-size: 15px; color: #686868;  }            
      table {  font-family: Arial Narrow; bORDER-collapse:collapse; }            
      table, td, th { bORDER:1px solid #686868; padding:5px; }            
      tr.g  {  background-color: #D3D3D3 }           
      tr.l  {  background-color: #F0F0F0 }            
      th    {  font-size: 15px; }            
      td    {  font-size: 15px; }            
      .s    {  font-size: 13px; }            
      .c    {  text-align: center; }            
      .r    {  text-align: right; }            
      </style>'            
   SET @cBody = ''            
            
-- Server Uptime            
   IF OBJECT_ID('tempdb..#cmdOutput') IS NOT NULL            
   BEGIN            
      DROP TABLE #cmdOutput            
   END            
            
   CREATE TABLE #cmdOutput(Line NVARCHAR(200) null) ;            
   INSERT INTO #cmdOutput  --EXEC master.dbo.xp_cmdshell 'D:\GTCMD\PsInfo.exe | Find /I "Uptime" ';  --KH03 KH04   --kocy03          
          
          
      select right('00'+ cast (isnull((s.time / 3600 /24), 0 )as varchar(2)),2) + ' day ' +  --kocy03          
      right('00'+ cast (isnull((s.time / 3600 % 24), 0 )as varchar(2)),2) + ' hours '+          
      right('00'+ cast (isnull((s.time /60 % 60), 0 )as varchar(2)),2) + ' minutes ' +          
      right('00'+ cast (isnull((s.time % 3600 % 60), 0 )as varchar(2)),2) + ' seconds '          
      from (          
               select datediff (ss,sqlserver_start_time, getdate()) as [time], *          
               from sys.dm_os_sys_info           
           ) as s          
          
   DECLARE @nDay int            
          
   --SELECT @nDay = CAST(SUBSTRING(LTRIM(RIGHT(Line,40)),0,CHARINDEX('day',LTRIM(RIGHT(Line,40)))-1) AS int)          
   --FROM #cmdOutput            
   --WHERE Line LIKE '%Uptime%'           
          
   SELECT @nDay = CAST(SUBSTRING(LTRIM(RIGHT(Line,40)),0,CHARINDEX('day',LTRIM(RIGHT(Line,40)))-1) AS int)    --kocy03          
   FROM #cmdOutput           
            
   SET @cBodyHead = @cBodyHead + '<ol><li><strong>Server Uptime (' + @@serverName + ')</strong> - This server has been up for '            
   IF LEFT (DB_NAME(), 2) in ('CN')      --kocy04          
   BEGIN           
      IF @nDay >= 60    --kocy05        
      BEGIN            
         SET @nAlertCnt = @nAlertCnt + 1            
         SET @cBodyHead = @cBodyHead + '<strong><span style="color:#FF0000">'            
      END            
   END            
   ELSE            
   BEGIN           
      IF @nDay >= 21   --kocy01 kocy02            
      BEGIN            
         SET @nAlertCnt = @nAlertCnt + 1            
         SET @cBodyHead = @cBodyHead + '<strong><span style="color:#FF0000">'            
      END          
   END            
          
   --SELECT @cBodyHead = @cBodyHead + LTRIM(RIGHT(Line,40))            
   --FROM #cmdOutput            
   --WHERE Line LIKE '%Uptime%'            
          
   SELECT @cBodyHead = @cBodyHead + LTRIM(RIGHT(Line,40))   --kocy03          
   FROM #cmdOutput              
           
            
   SET @cBodyHead = @cBodyHead             
      + CASE WHEN LEFT (DB_NAME(), 2 ) in ('CN') AND @nDay >= 60 THEN '<br>Please restart the server as it is running more than 60 days</span></strong>'  --kocy04   --kocy05        
             WHEN LEFT (DB_NAME(), 2 ) not in ('CN') AND @nDay >= 21 THEN '<br>Please restart the server as it is running more than 21 days</span></strong>' END   --kocy01 kocy02            
      + '</li>'            
            
   DROP TABLE #cmdOutput;            
            
-- Archive Report            
   IF OBJECT_ID('tempdb..#tempreccnt') IS NOT NULL            
   BEGIN            
      DROP TABLE #tempreccnt            
   END            
            
   CREATE TABLE #tempreccnt         
   (  rowref int identity (1,1) not null,  
      tablename NVARCHAR(257),            
      rec_count int NULL,            
      min_date  datetime NULL,            
      max_date  datetime NULL   
   )            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PO',            
          rec_count = COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM PO (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PODetail',            
          rec_count = COUNT(a.Pokey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM PODetail a (nolock)            
   JOIN PO b (nolock) ON a.POkey = b.POkey            
            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'Receipt',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM receipt (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ReceiptDetail',            
          rec_count =  CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.3) ELSE COUNT(1) END,            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM receiptdetail a (nolock)            
   JOIN receipt b (nolock) ON a.receiptkey = b.receiptkey            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ORDERs',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM ORDERs (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ORDERDetail',            
          rec_count =  CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.45) ELSE COUNT(1) END, --COUNT(a.ORDERkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM ORDERDetail a (nolock)            
   JOIN ORDERs b (nolock) ON a.ORDERkey = b.ORDERkey            
            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'LoadPlan',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM LoadPlan (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'LoadPlanDetail',            
          rec_count =  COUNT(a.loadkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM LoadPlanDetail a (nolock)            
   JOIN LoadPlan b (nolock) ON a.Loadkey = b.Loadkey            
            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'MBOL',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM MBOL (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'MBOLDetail',            
          rec_count =  COUNT(a.mbolkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM MBOLDetail a (nolock)            
   JOIN Mbol b (nolock) ON a.Mbolkey = b.Mbolkey            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PickDetail',            
          rec_count = CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.5) ELSE COUNT(1) END, --COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM PickDetail (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PickHeader',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM PickHeader (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PickingInfo',            
          rec_count =  COUNT(1),            
          min_date = MIN(scanoutdate), max_date = MAX(scanoutdate)            
   FROM  PickingInfo (nolock)            
   WHERE ScanOutdate IS NOT NULL            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PackHeader',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM PackHeader (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'PackDetail',            
          rec_count =  CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.51) ELSE COUNT(1) END, --COUNT(a.PickSlipNo),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM PackDetail a (nolock)            
   JOIN PackHeader b (nolock) ON a.PickSlipNo = b.PickSlipNo            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ITRN',            
          rec_count =  CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.95) ELSE COUNT(1) END, --COUNT(1),            
    min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM ITRN (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'POD',            
          rec_count =  CASE WHEN COUNT(1) - @nTableRow > 0 THEN FLOOR(COUNT(1)*0.8) ELSE COUNT(1) END, --COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM POD (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'KIT',            
          rec_count = COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM KIT (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'KITDETAIL',            
          rec_count =  COUNT(a.kitkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM KITDETAIL a (nolock)            
   JOIN Kit b (nolock) ON a.Kitkey = b.kitkey            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'TRANSFER',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM TRANSFER (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'TRANSFERDETAIL',            
          rec_count =  COUNT(a.transferkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM TRANSFERDETAIL a (nolock)            
   JOIN Transfer b (nolock) ON a.Transferkey = b.Transferkey            
            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ADJUSTMENT',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM ADJUSTMENT (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'ADJUSTMENTDETAIL',            
          rec_count =  COUNT(a.adjustmentkey),            
          min_date = MIN(b.EditDate), max_date = MAX(b.EditDate)            
   FROM ADJUSTMENTDETAIL a (nolock)            
   JOIN Adjustment b (nolock) ON a.Adjustmentkey = b.Adjustmentkey            
            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'CCDETAIL',            
          rec_count =  COUNT(1),            
          min_date   = MIN(EditDate), max_date = MAX(EditDate)            
   FROM CCDETAIL (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'TRANSMITLOG',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM TRANSMITLOG (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'TRANSMITLOG2',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM TRANSMITLOG2 (nolock)            
            
   INSERT INTO #tempreccnt            
   SELECT tablename = 'TNTLog',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM TNTLog (nolock)            
 
    INSERT INTO #tempreccnt            
   SELECT tablename = 'TRANSMITLOG3',            
          rec_count =  COUNT(1),            
          min_date = MIN(EditDate), max_date = MAX(EditDate)            
   FROM TRANSMITLOG3 (nolock)      
            
   SELECT @nIssueCnt = COUNT(1)            
   FROM  #tempreccnt (nolock)            
   WHERE rec_count > @nTableRow            
            
   SET @cBodyHead = @cBodyHead + '<li><strong>Archive Report</strong> - '            
   IF @nIssueCnt > 0            
   BEGIN            
      SET @nAlertCnt = @nAlertCnt + 1            
      SET @cBodyHead = @cBodyHead + '<strong><a href="#Arc"><font color=red>' + CAST(@nIssueCnt AS nvarchar(10)) +            
                       ' table' + CASE WHEN @nIssueCnt > 1 THEN 's' END + ' with > '+CAST(CAST(@nTableRow*1.0/1000000 as decimal(9,1)) AS varchar(10))+' million records found!</font></a></strong></li>'            
   END            
   ELSE            
   BEGIN            
      SET @cBodyHead = @cBodyHead + 'All tables are < '+CAST(CAST(@nTableRow*1.0/1000000 as decimal(9,1)) AS varchar(10))+' million records</li>'            
   END            
            
   SET @cBody = @cBody + '<hr><p class=a1><a name="Arc"><strong>Archive Report</strong></a> - ' +            
         '<em>Show total number of records and oldest date created in the transaction table</em></p>' +            
         '<table><tr class=g>            
            <th>Table &uArr;</th>            
            <th>Count</th>            
            <th>Min Date</th>            
            <th>Max Date</th></tr>'            
            
--   SET @cBody = @cBody + CAST ( ( SELECT td = tablename, '',            
--           'td/@class' = 'r',            
--                       td = CASE WHEN rec_count > @nTableRow            
--                              THEN '<span style="color:#FF0000"><strong>' + CAST(rec_count AS NVARCHAR(10)) + '</strong></span>'            
--                              ELSE rec_count END, '',            
--                       td = CONVERT(char(10),ISNULL(min_date,''),126), '',            
--                       td = CONVERT(char(10),ISNULL(max_date,''),126)            
--                FROM #tempreccnt            
--                ORDER BY tablename            
--              FOR XML PATH('tr'), TYPE            
--          ) AS NVARCHAR(MAX) ) +            
--          N'</table>' ;            
            
   SET @nJ = 1            
            
   DECLARE CUR_Arc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT tablename, rec_count, min_date, max_date  FROM #tempreccnt            
   ORDER BY tablename            
            
   OPEN CUR_Arc            
   FETCH NEXT FROM CUR_Arc INTO @cTable, @nRow, @dMin, @dMax            
            
   WHILE @@FETCH_STATUS <> -1            
   BEGIN            
      IF @nJ % 2 = 1            
      BEGIN            
         SET @cBody = @cBody + '<tr>'            
      END            
      ELSE            
      BEGIN            
         SET @cBody = @cBody + '<tr class=l>'            
      END            
            
      SET @cBody = @cBody + '<td>' + @cTable + '</td>'            
      SET @cBody = @cBody + '<td class=r>' +            
               CASE WHEN @nRow > @nTableRow            
                     THEN '<span style="color:#FF0000"><strong>' + CAST(@nRow AS NVARCHAR(10)) + '</strong></span>'            
                     ELSE CAST(@nRow AS NVARCHAR(10)) END + '</td>'            
      SET @cBody = @cBody + '<td>' + CONVERT(char(10),ISNULL(@dMin,''),126) + '</td>'            
      SET @cBody = @cBody + '<td>' + CONVERT(char(10),ISNULL(@dMax,''),126) + '</td>'            
            
      SET @cBody = @cBody + '</tr>'            
      SET @nJ = @nJ + 1            
      FETCH NEXT FROM CUR_Arc INTO @cTable, @nRow, @dMin, @dMax            
   END            
            
   CLOSE CUR_Arc            
   DEALLOCATE CUR_Arc            
   DROP TABLE #tempreccnt            
            
   SET @cBody = REPLACE(@cBody,'1900-01-01',' ') + '</table>'            
            
-- Blocking Analysis            
   SELECT CONVERT(char(10), currenttime, 126) as BlockDate,            
          DATEPART(hour, currenttime) as BlockHour,            
          COUNT(1) As NoOfBlock,            
          MAX((waittime/1000) / 60) as MaxWaitTime            
   INTO #tempPerfTrace            
   FROM v_wms_perftrace            
   WHERE DATEDIFF(day, currenttime, getdate()) <= 7            
   AND   Blocked_ID <> Blocking_ID            
   GROUP BY convert(char(10), currenttime, 126), datepart(hour, currenttime)            
   ORDER BY convert(char(10), currenttime, 126), datepart(hour, currenttime)            
            
   SELECT convert(char(10), currenttime, 126), datepart(hour, currenttime)            
   FROM v_wms_perftrace            
   WHERE DATEDIFF(hour, currenttime, getdate()) < 24            
   AND   Blocked_ID <> Blocking_ID            
   GROUP BY convert(char(10), currenttime, 126), datepart(hour, currenttime)            
   SELECT @nIssueCnt = @@ROWCOUNT            
            
   SET @cBodyHead = @cBodyHead + '<li><strong>Blocking Analysis</strong> - '            
   IF @nIssueCnt > 0            
   BEGIN            
      SET @nAlertCnt = @nAlertCnt + 1            
      SET @cBodyHead = @cBodyHead + '<strong><a href="#Blo"><font color=red>' + CAST(@nIssueCnt AS nvarchar(10)) +            
             ' blocking issue' + CASE WHEN @nIssueCnt > 1 THEN 's' END + ' found for last 24 hours!</font></a></strong></li>'            
   END            
   ELSE            
   BEGIN            
      SET @cBodyHead = @cBodyHead + 'No blocking issues for last 24 hours</li>'            
   END            
            
   SET @cBody = @cBody + '<hr><p class=a1><a name="Blo"><strong>Blocking Analysis</strong></a> - ' +            
         '<em>Show all the blocked transactions and transactions causing blocking</em></p>' +            
         '<table><tr class=g>            
            <th>BlockDate</th>            
            <th>Hour</th>            
            <th>NoOfBlock</th>            
            <th>MaxWaitTime</th></tr>'            
   -- TLTING 2010/05/11            
   IF EXISTS ( SELECT 1 FROM #tempPerfTrace )            
   BEGIN            
      SET @cBody = @cBody +            
          CAST ( ( SELECT td = BlockDate, '',            
                         'td/@class' = 'c',            
                          td = RIGHT('0'+CAST(BlockHour AS NVARCHAR(2)),2), '',            
                         'td/@class' = 'r',            
                          td = NoOfBlock, '',            
                         'td/@class' = 'r',            
                         td = CAST(MaxWaitTime AS NVARCHAR(10)) + ' min'            
                   FROM #tempPerfTrace ss            
                   ORDER BY BlockDate DESC, BlockHour DESC   --CJ01            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) +            
          N'</table>' ;            
   END            
   ELSE            
   BEGIN            
            
         SET @cBody = @cBody + N'<tr><th colspan=4>No Data Found</th></tr></table></td></tr></table>' ;            
            
   END            
            
-- Health Check            
   SET @cBody = @cBody + '<hr><p class=a1><a name="Hea"><strong>Health Check</strong></a> - ' +            
    '<em>List top 50 records for each data integrity problem</em></p><ol>'  -- KH02            
            
    SET @nIssueCnt = 0            
--1.            
            
   SELECT sku, storerkey, qty = sum(cast(qty as BigInt))            
   into #temp_sum1            
   FROM skuxloc (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey,sku            
            
   SELECT sku, storerkey, qty = sum(cast(qty as BigInt))            
   into #temp_sum11            
   FROM lotxlocxid (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey,sku            
            
   SELECT  TOP 50     -- KH02            
      a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_skuxloc =a.qty, sum_lotxlocxid = b.qty            
   into #info1            
   FROM #temp_sum1 a FULL OUTER JOIN #temp_sum11 b on a.sku = b.sku AND a.storerkey = b.storerkey            
   WHERE  a.qty <> b.qty            
    or a.sku is null or b.sku is null            
    or a.storerkey is null or b.storerkey is null            
            
   IF EXISTS (SELECT 1 FROM #info1)            
   BEGIN            
      SET @cBody = @cBody + '<li>Comparison of SKUxLOC and LOTxLOCxID (Qty)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>SKU x LOC</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                  FROM #info1            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info1            
   DROP TABLE #temp_sum1            
   DROP TABLE #temp_sum11            
            
--2.            
    -- add storerkey kocy09         
   SELECT storerkey, loc, qty = sum(cast(qty as BigInt))            
   into #temp_sum2            
   FROM skuxloc (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey, loc            
            
   SELECT storerkey, loc, qty = sum(cast(qty as BigInt))            
   into #temp_sum21            
   FROM lotxlocxid (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey, loc            
            
   SELECT TOP 50     -- KH02            
      a_storerkey = a.storerkey, b_storerkey = b.storerkey, a_loc = a.loc, b_loc = b.loc,     
      sum_skuxloc = a.qty, sum_lotxlocxid = b.qty     
   into #info2            
   FROM #temp_sum2 a FULL OUTER JOIN #temp_sum21 b ON a.loc = b.loc and a.storerkey = b.storerkey          
   WHERE a.qty <> b.qty            
    or a.loc is null or b.loc is null            
            
   IF EXISTS (SELECT 1 FROM #info2)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of SKUxLOC and LOTxLOCxID (Qty)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>SKU x LOC</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr><th>StorerKey</th><th>LOC</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>LOC</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_loc,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),''), '',     
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_loc,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                   FROM #info2            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info2            
   DROP TABLE #temp_sum2            
   DROP TABLE #temp_sum21            
            
--3.            
            
   SELECT sku, storerkey, qty = sum(cast(qty as BigInt))            
   into #temp_sum3            
   FROM lot (nolock)            
  WHERE qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT sku, storerkey, qty = sum(cast(qty as BigInt))            
   into #temp_sum31            
   FROM skuxloc (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey,sku            
            
   SELECT  TOP 50     -- KH02            
      a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_lot = a.qty, sum_skuxloc = b.qty     
   into #info3            
   FROM #temp_sum3 a FULL OUTER JOIN #temp_sum31 b ON a.sku = b.sku AND a.storerkey = b.storerkey            
   WHERE a.qty <> b.qty            
   or a.sku is null or b.sku is null or a.storerkey is null or b.storerkey is null            
            
   IF EXISTS (SELECT 1 FROM #info3)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT and SKUxLOC (Qty)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT</th><th colspan=3>SKU x LOC</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>SKU</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lot AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info3            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info3            
   DROP TABLE #temp_sum3            
   DROP TABLE #temp_sum31            
            
--4.            
    -- add storerkey kocy09              
   SELECT storerkey, lot, qty = sum(qty)            
   into #temp_sum4            
   FROM lotxlocxid (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey, lot            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, b_storerkey = b.storerkey, a_lot = b.lot, b_lot = a.lot,  lot_qty =  b.qty , sum_lotxlocxid = a.qty            
   into #info4            
   FROM #temp_sum4 a     
   FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot and a.storerkey = b.storerkey           
   WHERE b.qty > 0 AND ( a.qty <> b.qty            
   or a.lot is null or b.lot is null)            
            
   IF EXISTS (SELECT 1 FROM #info4)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT and LOTxLOCxID (Qty)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>LOT</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>LOT</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',    
                          td = ISNULL(a_lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(lot_qty,''), '',    
                          td = ISNULL(b_storerkey,''), '',    
                          td = ISNULL(b_lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                   FROM #info4            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info4            
   DROP TABLE #temp_sum4            
            
                    
--6.            
   -- add storerkey kocy09         
   SELECT storerkey, lot, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum6            
   FROM lotxlocxid (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, lot            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, b_storerkey =b.storerkey, a_lot = b.lot, b_lot = a.lot,      
       lot_QtyAllocated = b.QtyAllocated,  sum_lotxlocxid = a.QtyAllocated            
   into #info6            
   FROM #temp_sum6 a     
   FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot and a.storerkey = b.storerkey           
   WHERE b.QtyAllocated > 0     
   AND (a.QtyAllocated <> b.QtyAllocated or a.lot is null or b.lot is null)            
            
   IF EXISTS (SELECT 1 FROM #info6)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT and LOTxLOCxID (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>LOT</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>LOT</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',    
                          td = ISNULL(a_lot,''), '',            
                         'td/@class' = 'r',            
                          td = ISNULL(lot_QtyAllocated,''), '',     
                          td = ISNULL(b_storerkey,''), '',    
                          td = ISNULL(b_lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
      FROM #info6            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info6            
   DROP TABLE #temp_sum6            
            
--7.            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum7            
   FROM lot (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum71            
   FROM skuxloc (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_lot = a.QtyAllocated,  sum_skuxloc = b.QtyAllocated            
   into #info7            
   FROM #temp_sum7 a FULL OUTER JOIN #temp_sum71 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyAllocated <> b.QtyAllocated            
    or a.storerkey is null or b.storerkey is null            
    or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info7)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT and SKUxLOC (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT</th><th colspan=3>SKU x LOC</th></tr>' +            
       N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lot AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info7            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info7            
   DROP TABLE #temp_sum7            
   DROP TABLE #temp_sum71            
            
--8.            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum8            
   FROM lotxlocxid (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum81            
   FROM skuxloc (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_lotxlocxid = a.QtyAllocated, sum_skuxloc = b.QtyAllocated            
   into #info8            
   FROM #temp_sum8 a FULL OUTER JOIN #temp_sum81 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyAllocated <> b.QtyAllocated            
   or a.storerkey is null or b.storerkey is null            
   or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info8)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOTxLOCxID and SKUxLOC (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT x LOC x ID</th><th colspan=3>SKU x LOC</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                 td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info8            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info8            
   DROP TABLE #temp_sum8            
   DROP TABLE #temp_sum81            
            
--9.            
   -- add storerkey kocy09         
   SELECT storerkey, lot, QtyPicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum9            
   FROM lotxlocxid (nolock)            
   WHERE QtyPicked > 0            
   GROUP BY storerkey, lot            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, b_storerkey = b.storerkey, a_lot = b.lot, b_lot = a.lot,     
       sum_lot = b.QtyPicked ,  sum_lotxlocxid = a.QtyPicked            
   into #info9            
   FROM #temp_sum9 a     
   FULL OUTER JOIN lot b (nolock) ON a.lot = b.lot and a.storerkey = b.storerkey           
   WHERE b.QtyPicked > 0            
   AND (a.QtyPicked <> b.QtyPicked or a.lot is null or b.lot is null)            
            
   IF EXISTS (SELECT 1 FROM #info9)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT and LOTxLOCxID (QtyPicked)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1          
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT x LOC x ID</th><th colspan=3>LOT</th></tr>' +            
          N'<tr class=g><th>Storerkey</th><th>LOT</th><th>SUM</th>' +            
          N'<th>Storerkey</th><th>LOT</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',    
                          td = ISNULL(a_lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lot AS NVARCHAR(10)),''), '',    
                          td = ISNULL(b_storerkey,''), '',    
                          td = ISNULL(b_lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                   FROM #info9            
              FOR XML PATH('tr'), TYPE            
   ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info9            
   DROP TABLE #temp_sum9            
            
--10.            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum10            
   FROM lotxlocxid (nolock)            
   WHERE QtyPicked > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, Qtypicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum101            
   FROM skuxloc (nolock)            
   WHERE QtyPicked > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
       sum_lotxlocxid = a.QtyPicked , sum_skuxloc = b.QtyPicked            
   into #info10            
   FROM #temp_sum10 a FULL OUTER JOIN #temp_sum101 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyPicked <> b.QtyPicked            
   or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info10)            
   BEGIN           
      SET @cBody = @cBody + '<br><li>Comparison of LOTxLOCxID and SKUxLOC (QtyPicked)</li><br>'            
     SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>LOT x LOC x ID</th><th colspan=3>SKU x LOC</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info10            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info10            
   DROP TABLE #temp_sum10            
   DROP TABLE #temp_sum101            
            
--12.            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(Qty as BigInt))            
   into #temp_sum12            
   FROM pickdetail (nolock)            
   WHERE status in ('0', '1', '2', '3', '4') AND qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum121            
   FROM lotxlocxid (nolock)            
   WHERE QtyAllocated > 0            
GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetail = a.QtyAllocated, sum_lotxlocxid = b.QtyAllocated            
   into #info12            
   FROM #temp_sum12 a FULL OUTER JOIN #temp_sum121 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyAllocated <> b.QtyAllocated            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info12)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 0..4) and LOTxLOCxID (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +     
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                   FROM #info12            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info12            
   DROP TABLE #temp_sum12            
   DROP TABLE #temp_sum121            
            
--13.            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(Qty as BigInt))            
   into #temp_sum13            
   FROM pickdetail (nolock)            
   WHERE status in ('0', '1', '2', '3', '4') AND qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum131            
   FROM skuxloc (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetail = a.QtyAllocated, sum_skuxloc = b.QtyAllocated            
   into #info13            
   FROM #temp_sum13 a FULL OUTER JOIN #temp_sum131 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyAllocated <> b.QtyAllocated            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info13)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 0..4) and SKUxLOC (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>SKU x LOC</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info13            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info13            
   DROP TABLE #temp_sum13            
   DROP TABLE #temp_sum131            
            
--14.            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(Qty as BigInt))            
   into #temp_sum14            
   FROM pickdetail (nolock)            
   WHERE status in ('0', '1', '2', '3', '4') AND qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyAllocated = sum(cast(QtyAllocated as BigInt))            
   into #temp_sum141            
   FROM lot (nolock)            
   WHERE QtyAllocated > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetial =  a.QtyAllocated ,sum_lot = b.QtyAllocated            
   into #info14            
   FROM #temp_sum14 a FULL OUTER JOIN #temp_sum141 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyAllocated <> b.QtyAllocated            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info14)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 0..4) and LOT (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>LOT</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetial AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lot AS NVARCHAR(10)),'')            
               FROM #info14            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info14            
   DROP TABLE #temp_sum14            
   DROP TABLE #temp_sum141            
            
--15.            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(Qty as BigInt))            
   into #temp_sum15            
   FROM pickdetail (nolock)            
   WHERE status in ('5', '6', '7', '8') AND qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum151            
   FROM lotxlocxid (nolock)            
   WHERE QtyPicked > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetail = a.QtyPicked, sum_lotxlocxid = b.QtyPicked            
   into #info15            
   FROM #temp_sum15 a FULL OUTER JOIN #temp_sum151 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyPicked <> b.QtyPicked            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info15)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 5..8) and LOTxLOCxID (QtyPicked)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>LOT x LOC x ID</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lotxlocxid AS NVARCHAR(10)),'')            
                   FROM #info15            
              FOR XML PATH('tr'), TYPE            
  ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info15            
   DROP TABLE #temp_sum15            
   DROP TABLE #temp_sum151            
            
--16.            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(Qty as BigInt))            
   into #temp_sum16            
   FROM pickdetail (nolock)            
   WHERE status in ('5', '6', '7', '8') AND qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum161            
   FROM skuxloc (nolock)            
   WHERE QtyPicked > 0            
  GROUP BY storerkey, sku            
            
 SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetail_picked = a.QtyPicked,  sum_skuxloc = b.QtyPicked            
   into #info16            
   FROM #temp_sum16 a FULL OUTER JOIN #temp_sum161 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
WHERE a.QtyPicked <> b.QtyPicked            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info16)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 5..8) and SKUxLOC (QtyPicked)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>SKU x LOC</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail_picked AS NVARCHAR(10)),''), '',            
                        td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_skuxloc AS NVARCHAR(10)),'')            
                   FROM #info16            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info16            
   DROP TABLE #temp_sum16            
   DROP TABLE #temp_sum161            
            
--17.            
         
   SELECT storerkey, sku, QtyPicked = sum(cast(Qty as BigInt))            
   into #temp_sum17            
   FROM pickdetail (nolock)            
   WHERE status in ('5', '6', '7', '8') AND Qty > 0            
   GROUP BY storerkey, sku            
            
   SELECT storerkey, sku, QtyPicked = sum(cast(QtyPicked as BigInt))            
   into #temp_sum171            
   FROM lot (nolock)            
   WHERE QtyPicked > 0            
   GROUP BY storerkey, sku            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_sku = a.sku, b_storerkey = b.storerkey, b_sku = b.sku,            
      sum_pickdetail_picked = a.QtyPicked, sum_lot = b.QtyPicked            
   into #info17            
   FROM #temp_sum17 a FULL OUTER JOIN #temp_sum171 b ON a.storerkey = b.storerkey AND a.sku = b.sku            
   WHERE a.QtyPicked <> b.QtyPicked            
    or a.storerkey is null or b.storerkey is null or a.sku is null or b.sku is null            
            
   IF EXISTS (SELECT 1 FROM #info17)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 5..8) and LOT (QtyPicked)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>LOT</th></tr>' +            
          N'<tr class=g><th>Storer Key</th><th>SKU</th><th>SUM</th>' +            
          N'<th>Storer Key</th><th>SKU</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',            
                          td = ISNULL(a_sku,''), '',            
                      'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail_picked AS NVARCHAR(10)),''), '',            
                          td = ISNULL(b_storerkey,''), '',            
                          td = ISNULL(b_sku,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_lot AS NVARCHAR(10)),'')            
                   FROM #info17            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info17            
   DROP TABLE #temp_sum17            
   DROP TABLE #temp_sum171            
            
--18.            
    /* kocy08  add storerkey compare pickdetail and orderdetail  (S)   */      
   SELECT pd.Storerkey, pd.ORDERkey, QtyAllocated = sum(cast(pd.Qty as BigInt))            
   into #temp_sum18            
   FROM pickdetail pd (nolock)            
   WHERE pd.status in ('0', '1', '2', '3', '4') AND pd.Qty > 0   
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = pd.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY pd.Storerkey, pd.ORDERkey            
            
   SELECT od.Storerkey, od.ORDERkey, QtyAllocated = sum(cast(od.QtyAllocated as BigInt))    
   INTO #temp_sum181  
   FROM ORDERdetail  od (nolock)   
   WHERE od.QtyAllocated > 0  
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = od.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY od.Storerkey, od.ORDERkey            
            
   SELECT TOP 50 -- KH02            
       a_StorerKey = a.Storerkey, a_ORDERkey = a.ORDERkey, b_Storerkey = b.Storerkey, b_ORDERkey = b.ORDERkey,            
       sum_pickdetail_allocated = a.Qtyallocated , sum_ORDERdetail = b.Qtyallocated            
   into #info18            
   FROM #temp_sum18 a FULL OUTER JOIN #temp_sum181 b ON a.ORDERkey = b.ORDERkey AND a.Storerkey = b.Storerkey          
   WHERE a.Qtyallocated <> b.Qtyallocated            
    or a.ORDERkey is null or b.ORDERkey is null            
            
   IF EXISTS (SELECT 1 FROM #info18)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 0..4) and ORDERDETAIL (QtyAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>ORDER DETAIL</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>ORDER Key</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>ORDER Key</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT  td = ISNULL(a_StorerKey,''), '',            
                            'td/@class' = 'r',        
                           td = ISNULL(a_ORDERkey,''), '',            
                            'td/@class' = 'r',            
                           td = ISNULL(CAST(sum_pickdetail_allocated AS NVARCHAR(10)),''), '',        
                           td = ISNULL(b_StorerKey,''), '',            
                            'td/@class' = 'r',        
                           td = ISNULL(b_ORDERkey,''), '',            
                            'td/@class' = 'r',            
                           td = ISNULL(CAST(sum_ORDERdetail AS NVARCHAR(10)),'')            
                   FROM #info18            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info18            
   DROP TABLE #temp_sum18            
   DROP TABLE #temp_sum181            
            
--19.            
   SELECT pd.Storerkey, pd.ORDERkey, qtypicked = sum(cast(pd.Qty as BigInt))            
   into #temp_sum19            
   FROM pickdetail pd (nolock)            
   WHERE pd.status in ('5', '6', '7', '8') AND pd.qty > 0  
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = pd.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY pd.Storerkey, pd.ORDERkey            
            
   SELECT od.Storerkey, od.ORDERkey, qtypicked = sum(cast(od.qtypicked as BigInt))            
   into #temp_sum191            
   FROM ORDERdetail od (nolock)            
   WHERE od.QtyPicked > 0   
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = od.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY od.Storerkey, od.ORDERkey            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_ORDERkey = a.ORDERkey, b_storerkey = b.storerkey, b_ORDERkey = b.ORDERkey,            
      sum_pickdetail_picked = a.qtypicked, sum_ORDERdetail = b.qtypicked            
   into #info19            
   FROM #temp_sum19 a FULL OUTER JOIN #temp_sum191 b ON a.ORDERkey = b.ORDERkey and a.storerkey = b.storerkey          
   WHERE a.qtypicked <> b.qtypicked            
    or a.ORDERkey is null or b.ORDERkey is null            
            
   IF EXISTS (SELECT 1 FROM #info19)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 5..8) and ORDERDETAIL (QtyPicked)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>ORDER DETAIL</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>ORDER Key</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>ORDER Key</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_StorerKey,''), '',            
  'td/@class' = 'r',        
                          td = ISNULL(a_ORDERkey,''), '',            
                           'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail_picked AS NVARCHAR(10)),''), '',          
                          td = ISNULL(b_StorerKey,''), '',            
                           'td/@class' = 'r',        
                          td = ISNULL(b_ORDERkey,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_ORDERdetail AS NVARCHAR(10)),'')            
                   FROM #info19            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info19            
   DROP TABLE #temp_sum19            
   DROP TABLE #temp_sum191            
            
--20.            
            
   SELECT pd.StorerKey, pd.ORDERkey, QtyShipped = sum(cast(pd.Qty as BigInt))            
   into #temp_sum20            
   FROM pickdetail pd (nolock)            
   WHERE pd.status ='9' AND pd.Qty > 0   
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = pd.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY pd.StorerKey, pd.ORDERkey            
            
   SELECT od.StorerKey, od.ORDERkey, QtyShipped = sum(cast(od.ShippedQty as BigInt))            
   into #temp_sum201            
   FROM ORDERdetail od (nolock)  
   WHERE ShippedQty > 0    
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = od.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY od.StorerKey, od.ORDERkey            
            
   SELECT TOP 50     -- KH02            
       a_storerkey = a.storerkey, a_ORDERkey = a.ORDERkey, b_storerkey = b.storerkey, b_ORDERkey = b.ORDERkey,            
       sum_pickdetail_shipped = a.qtyShipped, sum_ORDERdetail = b.qtyShipped            
   into #info20            
   FROM #temp_sum20 a FULL OUTER JOIN #temp_sum201 b ON a.ORDERkey = b.ORDERkey and a.storerkey = b.storerkey            
   WHERE a.QtyShipped <> b.QtyShipped            
    or a.ORDERkey is null or b.ORDERkey is null            
            
   IF EXISTS (SELECT 1 FROM #info20)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PICKDETAIL (Qty) (status = 9) and in ORDERDETAIL (ShippedQty)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PICK DETAIL</th><th colspan=3>ORDER DETAIL</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>ORDER Key</th><th>SUM</th>' +            
          N'<th>StorerKey</th><th>ORDER Key</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_StorerKey,''), '',            
                           'td/@class' = 'r',        
                          td = ISNULL(a_ORDERkey,''), '',            
                           'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_pickdetail_shipped AS NVARCHAR(10)),''), '',        
                          td = ISNULL(b_StorerKey,''), '',            
                           'td/@class' = 'r',        
                          td = ISNULL(b_ORDERkey,''), '',            
                           'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_ORDERdetail AS NVARCHAR(10)),'')            
                   FROM #info20            
              FOR XML PATH('tr'), TYPE       
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info20            
   DROP TABLE #temp_sum20            
   DROP TABLE #temp_sum201            
   /* kocy08  add storerkey compare pickdetail and orderdetail  (E)   */      
         
--21.            
   -- add storerkey kocy09        
   SELECT ppd.storerkey, ppd.ORDERkey, qtypreallocated = sum(cast(ppd.Qty as BigInt))            
   into #temp_sum212            
   FROM preallocatepickdetail ppd (nolock)            
   WHERE ppd.Qty > 0   
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = ppd.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY ppd.storerkey, ppd.ORDERkey            
            
   SELECT od.storerkey, od.ORDERkey, qtypreallocated = sum(cast(od.qtypreallocated as BigInt))            
   into #temp_sum211            
   FROM ORDERdetail od (nolock)            
   WHERE qtypreallocated > 0   
   AND NOT EXISTS (SELECT 1 FROM StorerConfig sc (nolock) WHERE sc.StorerKey = od.Storerkey AND sc.ConfigKey = 'SKIPHealthCheck' )  --kocy11  
   GROUP BY od.storerkey, od.ORDERkey            
            
   SELECT  TOP 50     -- KH02            
      a_storerkey = a.storerkey, b_storerkey = b.storerkey, a_ORDERkey = a.ORDERkey, b_ORDERkey = b.ORDERkey,            
      sum_preallocatepickdetail = a.qtypreallocated, sum_ORDERdetail = b.qtypreallocated            
   into #info21            
   FROM #temp_sum212 a FULL OUTER JOIN #temp_sum211 b ON a.ORDERkey = b.ORDERkey and a.Storerkey = b.StorerKey            
   WHERE a.qtypreallocated <> b.qtypreallocated            
    or a.ORDERkey is null or b.ORDERkey is null            
            
   IF EXISTS (SELECT 1 FROM #info21)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of PreAllocatePickDetail (Qty) and ORDERDETAIL (QtyPreAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=3>PreAllocate Pick Detail</th><th colspan=3>ORDER DETAIL</th></tr>' +            
          N'<tr class=g><th>StorerKey</th><th>ORDER Key</th><th>SUM</th>' +            
          N'<th>StorerKey</th<th>ORDER Key</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',    
                          td = ISNULL(a_ORDERkey,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_preallocatepickdetail AS NVARCHAR(10)),''), '',    
                          td = ISNULL(b_storerkey,''), '',    
                          td = ISNULL(b_ORDERkey,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_ORDERdetail AS NVARCHAR(10)),'')            
                   FROM #info21            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info21            
   DROP TABLE #temp_sum212            
   DROP TABLE #temp_sum211            
            
--22.            
   -- add storerkey kocy09         
   SELECT storerkey, lot, qtypreallocated = sum(cast(Qty as BigInt))            
   into #temp_sum22            
   FROM preallocatepickdetail (nolock)            
   WHERE qty > 0            
   GROUP BY storerkey, lot            
            
   SELECT storerkey, lot, qtypreallocated            
   into #temp_sum221            
   FROM lot (nolock)            
   WHERE qtypreallocated > 0            
            
   SELECT  TOP 50     -- KH02            
      a_storerkey = a.storerkey, b_storerkey = b.storerkey, PreallocatePickDetail_Lot = a.lot, LOT_Lot = b.lot,            
      sum_preallocatepickdetail = a.qtypreallocated, lot_qtypreallocated = b.qtypreallocated            
   into #info22            
   FROM #temp_sum22 a     
   FULL OUTER JOIN #temp_sum221 b ON a.lot = b.lot and a.Storerkey = b.StorerKey          
   WHERE a.qtypreallocated <> b.qtypreallocated            
   or a.lot is null or b.lot is null            
            
   IF EXISTS (SELECT 1 FROM #info22)            
   BEGIN            
      SET @cBody = @cBody + '<br><li>Comparison of LOT (Qty) and PreallocatePickdetail (QtyPreAllocated)</li><br>'            
      SET @nIssueCnt = @nIssueCnt + 1            
      SET @cBody = @cBody + N'<table>' +            
 N'<tr class=g><th colspan=3>PreAllocate Pick Detail</th><th colspan=3>LOT</th></tr>' +            
          N'<tr class=g><th>Storerkey</th><th>LOT</th><th>SUM</th>' +            
          N'<th>Storerkey</th><th>LOT</th><th>SUM</th></tr>' +            
          CAST ( ( SELECT td = ISNULL(a_storerkey,''), '',    
                          td = ISNULL(PreallocatePickDetail_Lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(CAST(sum_preallocatepickdetail AS NVARCHAR(10)),''), '',    
                          td = ISNULL(b_storerkey,''), '',    
                          td = ISNULL(LOT_Lot,''), '',            
                          'td/@class' = 'r',            
                          td = ISNULL(lot_qtypreallocated,'')            
                   FROM #info22            
              FOR XML PATH('tr'), TYPE            
          ) AS NVARCHAR(MAX) ) + N'</table>' ;            
   END            
   DROP TABLE #info22            
   DROP TABLE #temp_sum22            
   DROP TABLE #temp_sum221            
            
--23.            
   /* -- SOS45086            
      Note:            
      1. Receipt and itrn can have different archiving settings (archiveparameter)            
         For e.g. Receipt keep for 60 day but itrn only keep for 30 days.            
         So we need to compare receipt with itrn in archive also            
      2. It is possible to have multiple sets of archive setting (for different storer)            
         Each set can have different retain days. So we are taking the min FROM itrn            
         to just check the most recent data (for better performance)            
            
      Assumption:            
      1. Live DB : Archive DB = 1:1            
      2. ArchiveParameters.ArchiveDataBaseName is set correctly            
   */      
   DECLARE @nMinItrnNumberofDaysToRetain int            
   DECLARE @cArchiveDB NVARCHAR( 30)            
            
   SELECT @nMinItrnNumberofDaysToRetain = min( ItrnNumberofDaysToRetain)            
   FROM archiveparameters (nolock)            
            
   SET rowcount 1            
   SELECT @cArchiveDB = ArchiveDataBaseName            
   FROM archiveparameters (nolock)            
   SET rowcount 0            
            
   IF (@cArchiveDB IS NULL OR @cArchiveDB = '') OR            
      (@nMinItrnNumberofDaysToRetain IS NULL OR @nMinItrnNumberofDaysToRetain < 1)            
   BEGIN            
      SET @cBody = @cBody + '- Incorrect archiveparameters setting'            
   END            
   ELSE            
 BEGIN         
      -- add storerkey kocy09    
      SELECT r.receiptkey, r.receiptlinenumber, r.sku, r.qtyreceived, r.beforereceivedqty, r.finalizeflag , r.StorerKey              
      into #temp23            
      FROM receiptdetail r (nolock)            
      left outer JOIN itrn i (nolock) on i.sourcekey = r.receiptkey + r.receiptlinenumber and i.StorerKey = r.StorerKey          
      AND  i.trantype = 'DP' AND i.sourcetype like 'ntrReceiptDetail%'            
      WHERE r.finalizeflag = 'Y' AND QtyReceived > 0            
      AND   i.sourcekey is null            
      AND   datedIFf(day, r.EditDate, getdate() ) < @nMinItrnNumberofDaysToRetain            
      AND   datedIFf(minute, r.EditDate, getdate() ) > 5            
            
      SELECT TOP 50     -- KH02            
          receiptkey, receiptlinenumber, sku, qtyreceived, beforereceivedqty, storerkey         
      into #info23            
      FROM #temp23            
      WHERE 1=2            
            
      DECLARE @cSQL nvarchar( 1024)            
            
      SET @cSQL =            
      ' INSERT INTO #info23 (receiptkey, receiptlinenumber, sku, qtyreceived, beforereceivedqty, storerkey )' +            
       'SELECT ISNULL(r.receiptkey,''''), ISNULL(r.receiptlinenumber,''''), ISNULL(r.sku,''''), ISNULL(r.qtyreceived,''''),      
               ISNULL(r.beforereceivedqty,''''), ISNULL(r.storerkey,'''') ' +           
       'FROM #temp23 r (nolock) ' +            
       'left outer JOIN ' + @cArchiveDB + '..itrn i (nolock) on i.sourcekey = r.receiptkey + r.receiptlinenumber AND i.storerkey = r.storerkey ' +            
       'AND  i.trantype = ''DP'' AND i.sourcetype like ''ntrReceiptDetail%'' ' +            
       'WHERE i.sourcekey is null '            
      EXECUTE sp_executesql @cSQL            
            
      IF EXISTS (SELECT 1 FROM #info23)            
      BEGIN            
         SET @cBody = @cBody + '<br><li>Comparison of RECEIPTDETAIL (live DB) and ITRN (live DB + archive DB) (Check for records not in ITRN but FinalizeFlag = Y)</li><br>'            
         SET @nIssueCnt = @nIssueCnt + 1            
         SET @cBody = @cBody + N'<table>' +            
             N'<tr class=g><th colspan=3>RECEIPT DETAIL</th><th colspan=3>ITRN</th></tr>' +            
             N'<tr class=g><th>StorerKey</th><th>Receipt Key</th><th>Receipt Linenumber</th>' +            
             N'<th>SKU</th><th>Qty Received</th><th>Before Received Qty</th></tr>' +            
             CAST ( ( SELECT td = ISNULL(StorerKey,''), '',    
                             td = ISNULL(receiptkey,''), '',            
                             td = ISNULL(receiptlinenumber,''), '',            
                             td = ISNULL(sku,''), '',            
                             'td/@class' = 'r',            
                             td = ISNULL(qtyreceived,''), '',            
                             'td/@class' = 'r',            
                             td = ISNULL(beforereceivedqty,'')          
                      FROM #info23            
                 FOR XML PATH('tr'), TYPE            
             ) AS NVARCHAR(MAX) ) + N'</table>' ;            
      END                           
      DROP TABLE #info23            
      DROP TABLE #temp23            
   END            
            
--24        
   /* -- 2022-01-21 kocy06 WMS-18569 UCC integrity health check         
      Note:         
      1.storerconfig should configurable, get storerconfig.storerkey         
        if storerconfig.configkey = 'UCC' and SValue = '1' and Option1='DailyIntegrity' --kocy07        
      2.Check UCC.Status between 1,3,5  Changed in FBR 1.4 UCC.Status between 1,2,3        
   */          
      SELECT ROW_NUMBER() OVER (ORDER BY u.LOT, u.Loc, u.ID) As row_num, u.Storerkey, u.LOT, u.LOC, u.ID, u.SKU, (u.Qty) AS Qty, u.UCCNO        
      INTO #temp_24           
      FROM UCC AS u WITH(NOLOCK)        
      JOIN StorerConfig AS sc WITH (NOLOCK) ON ConfigKey = 'UCC' AND SValue = '1' AND Option1='DailyIntegrity' AND sc.StorerKey = u.StorerKey        
      WHERE u.[Status] IN ('1','2','3')    --kocy10     
      AND Qty > '0'        
        
      SELECT lli.StorerKey, lli.LOT, lli.LOC, lli.ID, lli.SKU, (lli.Qty - lli.QtyPicked) AS Qty          
      INTO #temp_241           
      FROM LOTxLOCxID AS lli WITH(NOLOCK)        
      JOIN LOC L WITH (NOLOCK) ON L.Loc = lli.Loc        
      JOIN StorerConfig AS sc WITH (NOLOCK) ON ConfigKey = 'UCC' AND SValue = '1' AND Option1='DailyIntegrity' AND sc.StorerKey = lli.StorerKey        
      WHERE lli.Qty > '0'        
      AND L.LoseUCC <> '1'        
        
      SELECT ucc.Storerkey, ucc.LOT, ucc.LOC, ucc.ID, ucc.SKU, SUM(ucc.Qty)AS Qty        
      INTO #temp_sum24         
      FROM #temp_24 ucc        
      --where Lot in ( '0014390243', '0014390219', '0014390432')        
      GROUP BY ucc.Storerkey, ucc.LOT, ucc.LOC, ucc.ID, ucc.SKU        
        
          
      /* part A - compare sum Qty btwn UCC and LotxLocxID */        
      SELECT ucc.row_num, lli.Storerkey, lli.LOT, lli.LOC, lli.ID, lli.SKU, SUM(lli.Qty)AS Qty        
      INTO #temp_sum241         
      FROM #temp_241 lli        
      CROSS APPLY (        
         SELECT MIN (ucc.row_num) AS row_num        
         FROM #temp_24 ucc WHERE ucc.lOT = lli.lot AND ucc.ID= lli.ID AND ucc.ID = lli.ID        
       ) AS ucc        
      --where Lot in ( '0014390243', '0014390219', '0014390432')         
      GROUP BY ucc.row_num, lli.Storerkey, lli.LOT, lli.LOC, lli.ID, lli.SKU        
        
       SELECT TOP 50        
         ucc_StorerKey = isnull(uccsum.StorerKey, ''), ucc_Lot = isnull(uccsum.Lot, ''), ucc_ID = isnull (uccsum.ID, ''),         
         ucc_Loc = isnull (uccsum.Loc, ''), ucc_SKU = isnull(uccsum.SKU, ''), ucc_Qty = isnull (cast (uccsum.Qty as varchar), ''),        
         lli_Storerkey = isnull(llisum.Storerkey, ''), lli_Lot = isnull(llisum.Lot, ''), lli_ID = isnull(llisum.ID, ''),         
         lli_Loc = isnull(llisum.Loc,''),  lli_SKU = isnull(llisum.SKU, ''), lli_Qty = isnull (cast(llisum.Qty as varchar), '')        
      INTO #info24_A        
      FROM #temp_sum24 uccsum        
      LEFT JOIN #temp_sum241 llisum ON uccsum.Lot = llisum.Lot and uccsum.ID = llisum.ID and uccsum.Loc = llisum.Loc        
      WHERE ( uccsum.Qty <> llisum.Qty OR uccsum.Lot IS NULL OR llisum.Lot IS NULL )        
      --and   ucc.Lot in ( '0014390243', '0014390219', '0014390432')        
           
      IF EXISTS (SELECT 1 FROM  #info24_A)        
      BEGIN        
         SET @cBody = @cBody + '<br><li>Comparison of UCC and LOTxLOCxID (Sum Qty)</li><br>'            
         SET @nIssueCnt = @nIssueCnt + 1            
         SET @cBody = @cBody + N'<table>' +            
                               N'<tr class=g><th colspan=6>UCC</th><th colspan=6>LOTxLOCxID</th></tr>' +            
                               N'<tr class=g><th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th>' +                                        
                               N'<th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th></tr>' +            
                               CAST ( ( SELECT td = ISNULL(ucc_StorerKey,''), '', 'td/@class' = 'r',            
                                               td = ISNULL(ucc_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(ucc_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Qty,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_StorerKey,''), '', 'td/@class' = 'r',            
                                               td = ISNULL(lli_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(lli_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Qty,'')        
                                        FROM #info24_A            
                                        FOR XML PATH('tr'), TYPE            
                                      ) AS NVARCHAR(MAX) ) + N'</table>' ;            
      END         
        
      /* PART B - Compare  Lot,Loc,ID,& SKU of UCC and Lot,Loc,ID & SKU of LotxLocxID  */        
      SELECT TOP 50         
         isnull (cast(ucc.row_num as varchar), '') AS ucc_row_num, ucc_StorerKey = isnull(ucc.StorerKey, ''), ucc_Lot = isnull (ucc.Lot, ''), ucc_ID = isnull (ucc.ID, ''),         
         ucc_Loc = isnull (ucc.Loc, ''), ucc_SKU = isnull (ucc.SKU, ''), ucc_Qty = isnull (cast (ucc.Qty as varchar), ''),        
         isnull (cast(llisum.row_num as varchar), '') AS lli_row_num, lli_Storerkey = isnull(llisum.Storerkey, ''), lli_Lot = isnull(llisum.Lot, ''), lli_ID = isnull(llisum.ID, ''),         
         lli_Loc = isnull(llisum.Loc,''),  lli_SKU = isnull(llisum.SKU, ''), lli_Qty = isnull (cast(llisum.Qty as varchar), '')   
      INTO #info24_B        
      FROM #temp_24 ucc        
      LEFT JOIN #temp_sum241 llisum ON ucc.row_num = llisum.row_num         
      WHERE (ucc.Qty <> llisum.Qty OR ucc.Lot IS NULL OR llisum.Lot IS NULL )        
      --and   ucc.Lot in ( '0014390243', '0014390219', '0014390432')        
      ORDER BY ucc.row_num, ucc.Lot        
              
        
      IF EXISTS (SELECT 1 FROM  #info24_B)        
      BEGIN        
   SET @cBody = @cBody + '<br><li>Comparison of UCC and LotxLocxID (Lot, ID, Loc & SKU) </li><br>'            
         SET @nIssueCnt = @nIssueCnt + 1            
         SET @cBody = @cBody + N'<table>' +            
                               N'<tr class=g><th colspan=6>UCC</th><th colspan=6>LOTxLOCxID</th></tr>' +            
                               N'<tr class=g><th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th>' +                                        
                               N'<th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th></tr>' +            
                               CAST ( ( SELECT td = ISNULL(ucc_StorerKey,''), '', 'td/@class' = 'r',                                                       
                                               td = ISNULL(ucc_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(ucc_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Qty,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_StorerKey,''), '', 'td/@class' = 'r',            
                                               td = ISNULL(lli_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(lli_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Qty,'')        
                                        FROM #info24_B           
                                        ORDER BY ucc_row_num, ucc_Lot        
                                        FOR XML PATH('tr'), TYPE            
                                      ) AS NVARCHAR(MAX) ) + N'</table>' ;            
      END         
              
      /* PART C - Check UCC wit same UCCNO but mutliple location & comparing Lot,Loc, ID & SKU in LotxLocxID */        
      SELECT  DISTINCT TOP 50         
       isnull(cast(ucc.row_num as varchar), '') AS ucc_row_num, ucc_UCCNo = ucc.UCCNO, ucc_StorerKey = isnull(ucc.StorerKey, ''), ucc_Lot = isnull (ucc.Lot, ''), ucc_ID = isnull (ucc.ID, ''),         
       ucc_Loc = isnull(ucc.Loc, ''),  ucc_SKU = isnull (ucc.SKU, ''), ucc_Qty = isnull (cast (ucc.Qty as varchar), ''),        
       lli_Storerkey = isnull(lli.Storerkey, ''), lli_Lot = isnull(lli.Lot, ''), lli_ID = isnull(lli.ID, ''), lli_Loc = isnull(lli.Loc,''),         
       lli_SKU = isnull(lli.SKU, ''), lli_Qty = isnull (cast(lli.Qty as varchar), '')        
      INTO #info24_C        
      FROM #temp_24 ucc        
      JOIN #temp_24 ucc1  ON ucc.UCCNO = ucc1.UCCNO AND ucc.Loc <> ucc1.Loc         
      LEFT JOIN #temp_241 lli ON ucc.Lot = lli.Lot and ucc.ID = lli.ID and ucc.Loc = lli.Loc        
      order by ucc.UccNO        
              
      IF EXISTS (SELECT 1 FROM  #info24_C)        
      BEGIN        
         SET @cBody = @cBody + '<br><li>Comparison of UCC and LotxLocxID (Same UCCNo but mutliple Loc) </li><br>'            
         SET @nIssueCnt = @nIssueCnt + 1            
         SET @cBody = @cBody + N'<table>' +            
          N'<tr class=g><th colspan=7>UCC</th><th colspan=6>LOTxLOCxID</th></tr>' +            
                               N'<tr class=g><th>Storerkey</th><th>UCCNo</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th>' +        
                               N'<th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th></tr>' +            
                               CAST ( ( SELECT td = ISNULL(ucc_StorerKey,''), '', 'td/@class' = 'r',        
     td = ISNULL(ucc_UCCNo,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(ucc_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Qty,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_StorerKey,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Lot,''), '',  'td/@class' = 'r',          
                                               td = ISNULL(lli_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Qty,'')        
                                        FROM #info24_C          
              ORDER BY ucc_UCCNo        
                                        FOR XML PATH('tr'), TYPE            
                                      ) AS NVARCHAR(MAX) ) + N'</table>' ;            
      END         
        
      /* PART D - Check UCC wit same UCCNO but mutliple SKU & comparing Lot, Loc, ID & SKU in LotxLocxID */        
      SELECT DISTINCT TOP 50         
       isnull(cast(ucc.row_num as varchar), '') AS ucc_row_num, ucc_UCCNo = ucc.UCCNO, ucc_StorerKey = isnull(ucc.StorerKey, ''), ucc_Lot = isnull (ucc.Lot, ''), ucc_ID = isnull (ucc.ID, ''),         
       ucc_Loc = isnull(ucc.Loc, ''),  ucc_SKU = isnull (ucc.SKU, ''), ucc_Qty = isnull (cast (ucc.Qty as varchar), ''),        
       lli_Storerkey = isnull(lli.Storerkey, ''), lli_Lot = isnull(lli.Lot, ''), lli_ID = isnull(lli.ID, ''), lli_Loc = isnull(lli.Loc,''),         
       lli_SKU = isnull(lli.SKU, ''), lli_Qty = isnull (cast(lli.Qty as varchar), '')        
      INTO #info24_D        
      FROM #temp_24 ucc        
      JOIN #temp_24 ucc1  ON ucc.UCCNO = ucc1.UCCNO AND ucc.SKU <> ucc1.SKU         
      LEFT JOIN #temp_241 lli ON ucc.Lot = lli.Lot and ucc.ID = lli.ID and ucc.Loc = lli.Loc        
      order by ucc.UccNO        
        
      IF EXISTS (SELECT 1 FROM  #info24_D)        
      BEGIN        
         SET @cBody = @cBody + '<br><li>Comparison of UCC and LotxLocxID (Same UCCNo but mutliple SKU) </li><br>'            
         SET @nIssueCnt = @nIssueCnt + 1            
         SET @cBody = @cBody + N'<table>' +            
                               N'<tr class=g><th colspan=7>UCC</th><th colspan=6>LOTxLOCxID</th></tr>' +             
                               N'<tr class=g><th>Storerkey</th><th>UCCNo</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th>' +        
                               N'<th>Storerkey</th><th>LOT</th><th>ID</th><th>LOC</th><th>SKU</th><th>SUM</th></tr>' +            
                               CAST ( ( SELECT td = ISNULL(ucc_StorerKey,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_UCCNo,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Lot,''), '',  'td/@class' = 'r',          
     td = ISNULL(ucc_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(ucc_Qty,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_StorerKey,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Lot,''), '',  'td/@class' = 'r',       
                                               td = ISNULL(lli_ID,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Loc,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_SKU,''), '', 'td/@class' = 'r',        
                                               td = ISNULL(lli_Qty,'')        
                                        FROM #info24_D          
                                        ORDER BY ucc_UCCNo        
                                        FOR XML PATH('tr'), TYPE            
                                      ) AS NVARCHAR(MAX) ) + N'</table>' ;            
      END         
        
     DROP TABLE #temp_24        
     DROP TABLE #temp_241        
     DROP TABLE #temp_sum24            
     DROP TABLE #temp_sum241           
     DROP TABLE #info24_A        
     DROP TABLE #info24_B         
     DROP TABLE #info24_C        
     DROP TABLE #info24_D        
          
   SET @cBody = @cBody + '</ol>';            
   SET @cBodyHead = @cBodyHead + '<li><strong>Health Check</strong> - '            
   IF @nIssueCnt > 0            
   BEGIN            
      SET @nAlertCnt = @nAlertCnt + 1            
      SET @cBodyHead = @cBodyHead + '<strong><a href="#Hea"><font color=red>' + CAST(@nIssueCnt AS nvarchar(10)) +            
             ' integrity issue' + CASE WHEN @nIssueCnt > 1 THEN 's' END + ' found!</font></a></strong></li></ol>'            
   END            
   ELSE            
   BEGIN            
      SET @cBodyHead = @cBodyHead + 'No integrity issues</li></ol>'            
      SET @cBody = @cBody + 'No integrity issues';            
   END            
            
   IF @nAlertCnt > 0            
   BEGIN            
      SET @cSubject = @cSubject + ' - ALERT!'            
      SET @cImpt = 'High'            
   END            
            
   SET @cBody = @cBodyHead + @cBody            
            
   EXEC msdb.dbo.sp_send_dbmail            
    @recipients      = @cListTo,            
    @copy_recipients = @cListCc,            
    @subject         = @cSubject,            
    @importance      = @cImpt,            
    @body            = @cBody,            
    @body_format     = 'HTML';            
            
   DROP TABLE #tempPerfTrace            
            
   SET NOCOUNT OFF            
END -- procedure 

GO