SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: isp_ReplenishOnDemand_rpt                           */    
/* Creation Date: 14-Mar-2013                                            */    
/* Copyright: IDS                                                        */    
/* Written by:                                                           */    
/*                                                                       */    
/* Purpose: SOS#272299 - NIKE Replenishmnt On Demand report              */    
/*                                                                       */    
/* Called By: Report                                                     */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 17-Jun-2013  NJOW01   1.0  279922-add facility and pa zone param      */  
/* 08-Apr-2014  NJOW02   1.1  303237-Sort by qty available               */  
/* 25-Oct-2018  WLCHOOI  1.2  WMS-6803 - add show barcode flag  (WL01)   */  
/* 24-Jun-2019  CSCHONG  1.3  WMS-9437 - add new parameter (CS01)        */
/* 23-Jul-2019  CSCHONG  1.4  WMS-9437 - revised field mapping (CS01a)   */
/*************************************************************************/    
CREATE PROCEDURE [dbo].[isp_ReplenishOnDemand_rpt] (  
                                         @cstorerkey NVARCHAR(15),  
                                         @ddeliveryfrom DATETIME,  
                                         @ddeliveryto DATETIME,  
                                         @cSKUGroup NVARCHAR(10),  
                                         @cLottable01 NVARCHAR(18)='',  
                                         @cLottable02 NVARCHAR(18)='',  
                                         @cLottable03 NVARCHAR(18)='',  
                                         @cFacility NVARCHAR(5)='',  --NJOW01  
                                         @cPAZoneFrom NVARCHAR(10)='',  --NJOW01  
                                         @cPAZoneTo NVARCHAR(10)='',  --NJOW01  
                                         @cShowBCode NVARCHAR(1)='N', --WL01
                                         @cEmptyPickloc NVARCHAR(1)='N' --CS01                     
                                     )          
AS          
BEGIN  
 SET NOCOUNT ON          
 SET ANSI_DEFAULTS OFF            
 SET QUOTED_IDENTIFIER OFF          
 SET CONCAT_NULL_YIELDS_NULL OFF   
   
 -- Order demand        
 SELECT od.storerkey,  
        od.sku,  
        COUNT(DISTINCT o.orderkey)     NoOfOrder,  
        SUM(od.originalqty)            OrderQTY,  
        SPACE(10)                      ToLoc,  
        0                              PFAvail,  
        0                              BulkAvail,  
        0 QTYtoReplen,  
        sku.DESCR,  
        pack.PackUOM3,
        @cShowBCode as ShowBCode --WL01
 INTO   #Demand  
 FROM   orders o(NOLOCK)  
        INNER JOIN orderdetail od(NOLOCK)  
             ON  (o.orderkey = od.orderkey)  
        INNER JOIN sku(NOLOCK)  
             ON  (sku.storerkey = od.storerkey AND sku.sku = od.sku)  
        INNER JOIN PACK (NOLOCK) ON (sku.PACKKey = pack.PackKey)  
 WHERE  o.storerkey = @cstorerkey  
        AND o.status = '0'  
        --AND o.deliverydate BETWEEN @ddeliveryfrom AND @ddeliveryto  
        AND DATEDIFF(DAY,@ddeliveryfrom, o.DeliveryDate) >= 0  
        AND DATEDIFF(DAY,o.DeliveryDate, @ddeliveryto) >= 0  
        AND sku.skugroup = @cSKUGroup  
        AND o.Facility = @cFacility  --NJOW01  
 GROUP BY  
        od.storerkey,  
        od.sku,  
        sku.descr,  
        pack.packuom3  
 ORDER BY  
        od.storerkey,  
        od.sku  
 
 -- Update PF loc (mezzanine floor)        
 UPDATE #Demand  
 SET    ToLOC = sl.loc  
 FROM   #Demand d(NOLOCK)  
        INNER JOIN (  
                 SELECT sl.storerkey,  
                        sl.sku,  
                        MIN(sl.loc) loc -- sku could have multi pick face, use min()  
                 FROM   skuxloc sl(NOLOCK)  
                        INNER JOIN loc(NOLOCK)  
                             ON  (sl.loc = loc.loc)  
                 WHERE  sl.storerkey = @cstorerkey  
                        AND sl.locationtype IN ('case', 'pick')  
                        AND loc.putawayzone <> 'adidas'  
                        AND loc.facility = @cFacility --NJOW01  
                         AND loc.putawayzone BETWEEN @cPAZoneFrom AND @cPAZoneTo --NJOW01  
                 GROUP BY  
                        sl.storerkey,  
                        sl.sku  
             ) sl  
             ON  (d.storerkey = sl.storerkey AND d.sku = sl.sku)   
     
 -- Update PF avail        
 UPDATE #Demand  
 SET    PFAvail = sl.PFAvail  
 FROM   #Demand r(NOLOCK)  
        INNER JOIN (  
                 SELECT sl.storerkey,  
                        sl.sku,  
                        SUM(sl.qty - sl.qtyallocated - sl.qtypicked) PFAvail  
                 FROM   skuxloc sl(NOLOCK)  
                        INNER JOIN loc(NOLOCK)  
                             ON  (sl.loc = loc.loc)  
                 WHERE  sl.storerkey = @cstorerkey  
                        AND (sl.locationtype IN ('case', 'pick')) -- or loc.loclevel in ( 1, 2))  
                        AND (sl.qty - sl.qtyallocated - sl.qtypicked) > 0  
                        AND loc.locationflag NOT IN ('HOLD', 'DAMAGE')  
                        AND loc.status <> 'HOLD'  
                        AND loc.facility = @cFacility --NJOW01  
                         AND loc.putawayzone BETWEEN @cPAZoneFrom AND @cPAZoneTo --NJOW01  
                 GROUP BY  
                        sl.storerkey,  
                        sl.sku  
             ) sl  
             ON  (r.storerkey = sl.storerkey AND r.sku = sl.sku)   
   
 -- Update bulk avail        
 UPDATE #Demand  
 SET    BulkAvail = sl.BulkAvail  
 FROM   #Demand r(NOLOCK)  
        INNER JOIN (  
                 SELECT sl.storerkey,  
                        sl.sku,  
                        SUM(lli.qty - lli.qtyallocated - lli.qtypicked) AS BulkAvail  
                 FROM   skuxloc sl(NOLOCK)  
                        INNER JOIN loc(NOLOCK) ON  (sl.loc = loc.loc)  
                        INNER JOIN LOTxLOCxID lli(NOLOCK) ON (lli.StorerKey = sl.StorerKey AND lli.Sku = sl.Sku AND lli.Loc = sl.Loc)  
                        INNER JOIN LOTATTRIBUTE l(NOLOCK) ON (l.Lot = lli.Lot)  
                 WHERE  sl.storerkey = @cstorerkey  
                        AND sl.locationtype NOT IN ('case', 'pick')  
                        AND (lli.qty - lli.qtyallocated - lli.qtypicked) > 0  
                        AND loc.locationflag NOT IN ('HOLD', 'DAMAGE')  
                        AND loc.status <> 'HOLD'          
                        AND (l.Lottable01 = @cLottable01 OR ISNULL(@cLottable01,'') = '')                  
                        AND (l.Lottable02 = @cLottable02 OR ISNULL(@cLottable02,'') = '')                  
                        AND (l.Lottable03 = @cLottable03 OR ISNULL(@cLottable03,'') = '')                
                         AND loc.facility = @cFacility --NJOW01    
                 GROUP BY  
                        sl.storerkey,  
                        sl.sku  
             ) sl  
             ON  (r.storerkey = sl.storerkey AND r.sku = sl.sku)   
   
 -- update QtytoReplen        
 UPDATE #Demand  
 SET    QTYtoReplen = OrderQTY - PFAvail  
 WHERE  (OrderQTY - PFAvail) > 0   

--CS01 Start   
--  delete those don't need replen  
IF ISNULL(@cEmptyPickloc,'N') = 'N'
BEGIN      

 DELETE #Demand  
 WHERE  QTYtoReplen = 0   
 OR ISNULL(ToLoc,'') = ''  
END
ELSE  -- CS01a START
BEGIN
DELETE #Demand  
 WHERE  QTYtoReplen = 0   
 --OR ISNULL(ToLoc,'') = ''  
END  -- CS01a End
 --CS01 End

 -- create blank #replen        
 SELECT lli.StorerKey,  
        lli.SKU,  
        lli.LOC,  
        lli.ID,  
        lli.QTY,  
        l.lottable01,  
        l.Lottable02,  
        l.Lottable03   
 INTO #Replen  
 FROM   lotxlocxid lli(NOLOCK)  
 JOIN   lotattribute l (NOLOCK) ON lli.lot = l.lot   
 WHERE  1 = 0        
   
 DECLARE @cSKU NVARCHAR(20)        
 DECLARE @cPrevSKU NVARCHAR(20)        
 DECLARE @cFromLOC NVARCHAR(10)        
 DECLARE @cFromID NVARCHAR(18)        
 DECLARE @cFromLOTLOCID NVARCHAR(38)        
 DECLARE @nQTYtoReplen INT        
 DECLARE @nQTYAvail INT  
 DECLARE @c_Lottable01 NVARCHAR(18)        
 DECLARE @c_Lottable02 NVARCHAR(18)        
 DECLARE @c_Lottable03 NVARCHAR(18)        
   
 DECLARE cur_Demand CURSOR    
 FOR  
     SELECT storerkey,  
            sku,  
            qtytoreplen  
     FROM   #Demand  
     ORDER BY storerkey, sku       
   
 OPEN cur_Demand   
 FETCH NEXT FROM cur_Demand INTO @cStorerKey, @cSKU, @nQTYtoReplen        
 WHILE @@fetch_status = 0  
 BEGIN  
     IF @cPrevSKU <> @cSKU  
     BEGIN  
         SET @cFromLOTLOCID = ''        
         SET @cFromLOC = ''        
         SET @cFromID = ''        
         SET @cPrevSKU = @cSKU  
     END    
       
     SELECT TOP 1   
            @cFromLOTLOCID = REPLICATE('0',5-LEN(CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar)))+CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar)+lli.loc + lli.ID + lli.Lot,  
            @cFromLOC      = lli.loc,  
            @cFromID       = lli.ID,  
            @nQTYAvail     = SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked),  
            @c_Lottable01  = l.Lottable01,  
            @c_Lottable02  = l.Lottable02,  
            @c_Lottable03  = l.Lottable03  
     FROM   lotxlocxid lli(NOLOCK)  
            INNER JOIN skuxloc sl(NOLOCK)  
                 ON  (  
                         lli.storerkey = sl.storerkey  
                         AND lli.sku = sl.sku  
                         AND lli.loc = sl.loc  
                     )  
            INNER JOIN loc(NOLOCK)  
                 ON  (sl.loc = loc.loc)  
            INNER JOIN LOTATTRIBUTE l(NOLOCK) ON (l.Lot = lli.Lot)  
     WHERE  sl.storerkey = @cStorerKey  
            AND sl.sku = @csku  
            AND sl.locationtype NOT IN ('pick', 'case')   
                --and loc.loclevel not in (1, 2)  
            AND (lli.qty - lli.qtyallocated - lli.qtypicked) > 0  
            AND loc.locationflag NOT IN ('HOLD', 'DAMAGE')  
            AND loc.status <> 'HOLD'  
            AND (l.Lottable01 = @cLottable01 OR ISNULL(@cLottable01,'') = '')                  
            AND (l.Lottable02 = @cLottable02 OR ISNULL(@cLottable02,'') = '')                  
            AND (l.Lottable03 = @cLottable03 OR ISNULL(@cLottable03,'') = '')                  
            --AND cast(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar) + lli.loc + lli.ID + lli.Lot > @cFromLOTLOCID --[7/4] update to sort by available qty  
            AND loc.facility = @cFacility --NJOW01  
     GROUP BY  
            lli.loc, lli.ID, lli.Lot, --[7/4] updated to sort by available qty  
            lli.loc,  
            lli.ID,  
            l.Lottable01,  
            l.Lottable02,  
            l.Lottable03  
  HAVING  
      REPLICATE('0',5-LEN(CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar)))+CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar) + lli.loc + lli.ID + lli.Lot > @cFromLOTLOCID --[7/4] updated to sort by available qty  
     ORDER BY  
            REPLICATE('0',5-LEN(CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar)))+CAST(SUM(lli.QTY - lli.QTYallocated - lli.QTYpicked) as varchar) + lli.loc + lli.ID + lli.Lot     --[7/4] updated to sort by available qty  
       
     IF @nQTYAvail IS NULL  
         FETCH NEXT FROM cur_Demand INTO @cStorerKey, @cSKU, @nQTYtoReplen  
     ELSE  
     BEGIN  
         IF @nQTYtoReplen <= @nQTYAvail  
         BEGIN  
             INSERT INTO #Replen  
               (  
                 storerkey,  
                 sku,  
                 loc,  
                 id,  
                 QTY,  
                 Lottable01,  
                 Lottable02,  
                 Lottable03  
               )  
             VALUES  
               (  
                 @cStorerKey,  
                 @cSKU,  
                 UPPER(@cFromLOC),  
                 @cFromID,  
                 @nQTYtoReplen,  
                 @c_Lottable01,  
                 @c_Lottable02,  
                 @c_Lottable03  
               )   
             FETCH NEXT FROM cur_Demand INTO @cStorerKey, @cSKU, @nQTYtoReplen  
         END  
         ELSE  
         BEGIN  
             INSERT INTO #Replen  
               (  
                 storerkey,  
                 sku,  
                 loc,  
                 id,  
                 QTY,  
                 Lottable01,  
                 Lottable02,  
                 Lottable03  
               )  
             VALUES  
               (  
                 @cStorerKey,  
                 @cSKU,  
                 UPPER(@cFromLOC),  
                 @cFromID,  
                 @nQTYAvail,  
                 @c_Lottable01,  
                 @c_Lottable02,  
                 @c_Lottable03  
               )        
             SET @nQTYtoReplen = @nQTYtoReplen - @nQTYAvail  
         END  
     END  
 END   
 CLOSE cur_Demand   
 DEALLOCATE cur_Demand        
   
 SELECT d.storerkey,  
        d.sku,  
        d.descr,  
        d.packuom3,  
        d.toloc,  
        r.loc,  
        r.id,  
        r.qty,  
        r.lottable01,  
        r.lottable02,  
        r.lottable03,
        d.ShowBCode  --WL01
 FROM   #demand d  
        LEFT JOIN #replen r  
             ON  (r.storerkey = d.storerkey AND r.sku = d.sku)  
 ORDER BY  
        r.loc  
END  

GO