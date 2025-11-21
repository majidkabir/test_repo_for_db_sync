SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: dbo.isp_PickDetailAlert                            */
/* Creation Date: 21-Dec-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: KHLim                                                    */
/*                                                                      */
/* Purpose: Send email alert                                            */
/*                                                                      */
/* Called By:  BEJ - PickDetail Integrity                               */ 
/*                                                                      */
/* Parameters: (Input)                                                  */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 21-Sept-2012 SWYep     1.1  Add Inactive SKU check                   */  
/*  2-May-2013  KHLim     1.1  Check active SKU only                    */  
/************************************************************************/
CREATE  PROCEDURE [dbo].[isp_PickDetailAlert]
(
  @cListTo NVARCHAR(max),
  @cListCc NVARCHAR(max)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBody    nvarchar(max),
           @cSubject nvarchar(max), 
           @nIssue   int
   SET @nIssue = 0
   SET @cBody = '' 
   SET @cSubject = 'Integrity - WMS PickDetail - ' + @@SERVERNAME
               
   SELECT PD.PickDetailKey , PD.Storerkey, PD.SKU
   INTO #tempShipFlag   
   FROM PICKDETAIL PD WITH (nolock)
         JOIN ORDERS AS ORD WITH (nolock) ON ORD.OrderKey = PD.OrderKey  
   WHERE PD.shipFlag <> 'Y' 
   AND DateDiff(minute, PD.EditDate, getdate()) > 10
   AND EXISTS ( SELECT 1 FROM PICKDETAIL AS PD2 WITH (nolock) 
                WHERE PD2.shipFlag = 'Y' AND PD2.OrderKey = PD.OrderKey)
   AND ORD.Status = '9'
   AND PD.Editdate > getdate() - 3
                   
   IF EXISTS (SELECT 1 FROM #tempShipFlag)
   BEGIN
      SET @nIssue = @nIssue + 1
      SET @cBody = @cBody + '<h3>PickDetail ShipFlag </h3>' 
      SET @cBody = @cBody + N'<table border="1" cellspacing="0" cellpadding="5">' +
             N'<tr bgcolor=silver><th>PickDetailKey</th><th>Storer Key</th><th>SKU</th></tr>' +
             CAST ( ( SELECT td = ISNULL(CAST(PickDetailKey AS NVARCHAR(18)),''), '',
                             td = ISNULL(CAST(Storerkey AS NVARCHAR(15)),''), '',
                             td = ISNULL(CAST(SKU AS NVARCHAR(20)),'')
                     FROM #tempShipFlag   
                 FOR XML PATH('tr'), TYPE
             ) AS NVARCHAR(MAX) ) + N'</table>' ;  
   END

   DROP TABLE #tempShipFlag

   
   SELECT PickDetailKey, Storerkey, SKU, Lot
   INTO #tempLot
   FROM PICKDETAIL PD WITH (nolock) 
   WHERE status < '9'
   AND DateDiff(minute, PD.EditDate, getdate()) > 10
   AND NOT EXISTS ( SELECT 1 FROM  LOT WITH (nolock) 
                WHERE LOT.Lot = PD.Lot 
                  AND LOT.Storerkey = PD.Storerkey 
                  AND LOT.SKU = PD.SKU )
   AND PD.Editdate > getdate() - 3                  
                  
   IF EXISTS (SELECT 1 FROM #tempLot)
   BEGIN
      SET @nIssue = @nIssue + 1
      SET @cBody = @cBody + '<h3>PickDetail SKU LOT MisMatch </h3>' 
      SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +
             '<tr bgcolor=silver><th>PickDetailKey</th><th>Storer Key</th><th>SKU</th><th>Lot</th></tr>' +
             CAST ( ( SELECT td = ISNULL(CAST(PickDetailKey AS NVARCHAR(18)),''), '',
                             td = ISNULL(CAST(Storerkey AS NVARCHAR(15)),''),'',
                             td = ISNULL(CAST(SKU AS NVARCHAR(20)),''),'',
                             td = ISNULL(CAST(Lot AS NVARCHAR(10)),'' )
                     FROM #tempLot   
                 FOR XML PATH('tr'), TYPE
             ) AS NVARCHAR(MAX) ) + N'</table>' ;  
   END

   DROP TABLE #tempLot

   --(SW01) S  
   SELECT TOP 50 pickdetail.orderkey AS orderkey,   
      pickdetail.storerkey AS storerkey,  
      pickdetail.sku AS SKU, MAX(pickdetail.status) AS pd_status  
   INTO #tempInacSKU  
   FROM sku (NOLOCK)  
   JOIN  pickdetail (NOLOCK)   
   ON sku.sku = pickdetail.sku  
      AND sku.storerkey = pickdetail.storerkey  
   --KH01 WHERE pickdetail.status < '9'  AND (sku.skustatus <> 'active' OR sku.active<> '1' )
   WHERE pickdetail.status < '9'  AND (sku.skustatus = 'I' AND sku.active = '1' )  --KH01
   GROUP BY pickdetail.orderkey, pickdetail.storerkey, pickdetail.sku     
  
   IF EXISTS(SELECT 1 FROM #tempInacSKU)  
   BEGIN  
      SET @nIssue = @nIssue + 1  
      SET @cBody = @cBody + '<h3>PickDetail Suspended SKU </h3>'   
      SET @cBody = @cBody + '<table border="1" cellspacing="0" cellpadding="5">' +  
             '<tr bgcolor=silver><th>Order Key</th><th>Storer Key</th><th>SKU</th><th>Pickdetail Status</th></tr>' +  
             CAST ( ( SELECT td = ISNULL(CAST(orderkey AS nchar(10)),''), '',  
                             td = ISNULL(CAST(storerkey AS nchar(15)),''), '',  
                             td = ISNULL(CAST(SKU AS nchar(20)),''),'',  
                             td = ISNULL(CAST(pd_status AS nchar(10)),'')  
                     FROM #tempInacSKU     
                 FOR XML PATH('tr'), TYPE  
             ) AS NVARCHAR(MAX) ) + N'</table>' ;   
   END  
   --(SW01) E  
   IF @nIssue > 0
   BEGIN
      EXEC msdb.dbo.sp_send_dbmail 
         @recipients      = @cListTo,
         @copy_recipients = @cListCc,
         @subject         = @cSubject,
         @body            = @cBody,
         @body_format     = 'HTML' ;
   END

END /* main procedure */

GO