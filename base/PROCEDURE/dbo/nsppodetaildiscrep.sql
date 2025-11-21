SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: nspPODetailDiscrep                                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[nspPODetailDiscrep] (  
@StorerKeyMin   NVARCHAR(15),  
@StorerKeyMax   NVARCHAR(15),  
@PoKeyMin       NVARCHAR(18),  
@PoKeyMax       NVARCHAR(18),  
@PoDateMin      DATETIME,  
@PoDateMax      DATETIME  
) AS  
BEGIN  
  SET NOCOUNT ON  
  SET ANSI_NULLS OFF
  SET QUOTED_IDENTIFIER OFF   
  SET CONCAT_NULL_YIELDS_NULL OFF  
  
   SELECT DISTINCT  
   PO.Pokey  
   INTO #PoCandidates  
   FROM PO  
   WHERE  
   PO.StorerKey >= @StorerKeyMin  
   AND PO.StorerKey <= @StorerKeyMax  
   AND PO.PoKey >= @PoKeyMin  
   AND PO.PoKey <= @PoKeyMax
   AND DATEDIFF(Day, @PoDateMin, PO.PoDate) >= 0    
   AND DATEDIFF(Day, PO.PoDate, @PoDateMax) >= 0    
   --AND PO.PoDate >= Convert( datetime, @PoDateMin )  
   --AND PO.PoDate <  DateAdd( day, 1, Convert( datetime, @PoDateMax ) )  
   SELECT  
   Podetail.Pokey,  
   SUM(Podetail.qtyreceived) qtyrcvd  
   INTO #poqtyrcvd  
   FROM podetail  
   WHERE  
   podetail.POKEY IN (SELECT POKEY FROM #POCANDIDATES)  
   GROUP BY podetail.pokey  
   SELECT  
   Receiptdetail.Pokey,  
   Receiptdetail.Sku,  
   SUM(Receiptdetail.qtyreceived) qtyrcv,  
   SUM( Receiptdetail.qtyadjusted) qtyadj  
   INTO #rcptqty  
   FROM receiptdetail  
   WHERE  
   receiptdetail.POKEY IN (SELECT pokey FROM #POCANDIDATES) AND  
   receiptdetail.sku NOT IN (SELECT sku FROM #POQTYRCVD)  
   GROUP BY receiptdetail.pokey, receiptdetail.sku  
   SELECT  
   PO.POKey pokey,  
   PO.StorerKey storerkey,  
   PO.PODate podate,  
   PO.SellersReference sellersreference,  
   PO.BuyersReference buyersreference,  
   PO.SellerName sellername,  
   PO.BuyerName buyername,  
   PODETAIL.Sku sku,  
   PODETAIL.QtyOrdered qtyorderd,  
   PODETAIL.QtyAdjusted qtyadjusted,  
   PODETAIL.QtyReceived qtyreceived,  
   SKU.DESCR descr,  
   STORER.Company company  
   INTO #podata  
   FROM PO, PODETAIL, STORER, SKU  
   WHERE  
   PO.PoKey IN (SELECT PoKey FROM #poqtyrcvd WHERE qtyreceived >= 0)  
   AND PO.POKey = PODETAIL.POKey  
   AND   PO.StorerKey = STORER.StorerKey  
   AND   PODETAIL.StorerKey = SKU.StorerKey  
   AND   PODETAIL.Sku = SKU.Sku  
   SELECT  
   PO.POKey pokey,  
   PO.StorerKey storerkey,  
   PO.PODate podate,  
   PO.SellersReference sellersreference,  
   PO.BuyersReference buyersreference,  
   PO.SellerName sellername,  
   PO.BuyerName buyername,  
   SKU.Sku sku,  
   0 qtyorderd,  
   #rcptqty.qtyadj qtyadjusted,  
   #rcptqty.qtyrcv qtyreceived,  
   SKU.DESCR descr,  
   STORER.Company company  
   INTO #rcptdata  
   FROM PO, STORER, SKU, #rcptqty  
   WHERE  
   PO.PoKey = #rcptqty.pokey  
   AND PO.StorerKey = STORER.StorerKey  
   AND PO.StorerKey = SKU.StorerKey  
   AND #rcptqty.sku = SKU.Sku  
   SELECT  
   pokey,  
   storerkey,  
   podate,  
   sellersreference,  
   buyersreference,  
   sellername,  
   buyername,  
   sku,  
   qtyorderd,  
   qtyadjusted,  
   qtyreceived,  
   descr,  
   company  
   FROM #podata  
   WHERE qtyorderd <> qtyreceived  
   UNION  
   SELECT  
   pokey,  
   storerkey,  
   podate,  
   sellersreference,  
   buyersreference,  
   sellername,  
   buyername,  
   sku,  
   qtyorderd,  
   qtyadjusted,  
   qtyreceived,  
   descr,  
   company  
   FROM #rcptdata  
   WHERE qtyorderd <> qtyreceived  
END    
  

GO