SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--https://jira.lfapps.net/browse/WMS-9945

CREATE VIEW  [BI].[V_Inventory]  AS  
SELECT LLI.Lot    
, LLI.Loc    
, LLI.Id    
, LLI.StorerKey    
, LLI.Sku    
, LLI.Qty     
, LLI.QtyAllocated     
, LLI.QtyPicked     
, LLI.QtyExpected     
, LLI.QtyPickInProcess     
, LLI.PendingMoveIN     
, LLI.ArchiveQty     
, LLI.ArchiveDate    
, LLI.TrafficCop    
, LLI.ArchiveCop    
, LLI.QtyReplen    
, LLI.EditWho    
, LLI.EditDate    
--, S.StorerKey    
--, S.Sku    
, S.DESCR AS Sku_Descr   
, S.SUSR1    
, S.SUSR2    
, S.SUSR3    
, S.SUSR4    
, S.SUSR5    
, S.MANUFACTURERSKU    
, S.RETAILSKU    
, S.ALTSKU    
, S.PACKKey    
, S.STDGROSSWGT    
, S.STDNETWGT    
, S.STDCUBE    
, S.TARE    
, S.CLASS    
, S.ACTIVE    
, S.SKUGROUP    
, S.Tariffkey    
, S.BUSR1    
, S.BUSR2    
, S.BUSR3    
, S.BUSR4    
, S.BUSR5    
, S.LOTTABLE01LABEL    
, S.LOTTABLE02LABEL    
, S.LOTTABLE03LABEL    
, S.LOTTABLE04LABEL    
, S.LOTTABLE05LABEL    
, S.NOTES1    
, S.NOTES2    
, S.PickCode    
, S.StrategyKey    
, S.CartonGroup    
, S.PutCode    
, S.PutawayLoc    
, S.PutawayZone AS SkuPutwawayZone   
, S.InnerPack    
, S.Cube    
, S.GrossWgt    
, S.NetWgt    
, S.ABC    
, S.CycleCountFrequency    
, S.LastCycleCount    
, S.ReorderPoint    
, S.ReorderQty    
, S.StdOrderCost    
, S.CarryCost    
, S.Price    
, S.Cost    
, S.ReceiptHoldCode    
, S.ReceiptInspectionLoc    
, S.OnReceiptCopyPackkey    
--, S.TrafficCop    
--, S.ArchiveCop    
, S.IOFlag    
, S.TareWeight    
, S.LotxIdDetailOtherlabel1    
, S.LotxIdDetailOtherlabel2    
, S.LotxIdDetailOtherlabel3    
, S.AvgCaseWeight    
, S.TolerancePct    
, S.SkuStatus    
, S.Length    
, S.Width    
, S.Height    
, S.weight    
, S.itemclass    
, S.ShelfLife    
, S.Facility    
, S.BUSR6    
, S.BUSR7    
, S.BUSR8    
, S.BUSR9    
, S.BUSR10    
, S.ReturnLoc    
, S.ReceiptLoc    
--, S.archiveqty    
, S.XDockReceiptLoc    
, S.PrePackIndicator    
, S.PackQtyIndicator    
, S.StackFactor    
, S.IVAS    
, S.OVAS    
, S.Style    
, S.Color    
, S.Size    
, S.Measurement    
, S.HazardousFlag    
, S.TemperatureFlag    
, S.ProductModel    
, S.CtnPickQty    
, S.CountryOfOrigin    
, S.IB_UOM    
, S.IB_RPT_UOM    
, S.OB_UOM    
, S.OB_RPT_UOM    
, S.ABCPL    
, S.ABCCS    
, S.ABCEA    
, S.DisableABCCalc    
, S.ABCPeriod    
, S.ABCStorerkey    
, S.ABCSku    
, S.OldStorerkey    
, S.OldSku    
, S.LOTTABLE06LABEL    
, S.LOTTABLE07LABEL    
, S.LOTTABLE08LABEL    
, S.LOTTABLE09LABEL    
, S.LOTTABLE10LABEL    
, S.LOTTABLE11LABEL    
, S.LOTTABLE12LABEL    
, S.LOTTABLE13LABEL    
, S.LOTTABLE14LABEL    
, S.LOTTABLE15LABEL    
, S.ImageFolder    
, S.OTM_SKUGroup    
, S.Pressure    
, S.LottableCode    
, S.SerialNoCapture    
, S.DataCapture  
, L.LocationGroup  
, L.LocationCategory
, LA.Lottable01
, LA.Lottable02
, LA.Lottable03
, LA.Lottable04
, LA.Lottable05
, LA.Lottable06
, LA.Lottable07
, LA.Lottable08
, LA.Lottable09
, LA.Lottable10
, LA.Lottable11
, LA.Lottable12
, LA.Lottable13
, LA.Lottable14
, LA.Lottable15
, PZ.PutawayZone
, PZ.Descr    
--, S.AddDate    
--, S.AddWho    
--, S.EditDate    
--, S.EditWho    
FROM      LotxLocxID   AS LLI WITH (NOLOCK)
JOIN      Lot          AS LT  WITH (NOLOCK) ON LT.LOT = LLI.Lot --join  
LEFT JOIN SKU          AS S   WITH (NOLOCK) ON LLI.StorerKey = S.StorerKey AND LLI.Sku = S.Sku    
LEFT JOIN Loc          AS L   WITH (NOLOCK) ON L.Loc = LLI.Loc
JOIN      PutawayZone  AS PZ  WITH (NOLOCK) ON PZ.PutawayZone = L.PutawayZone AND PZ.Facility = L.Facility    
LEFT JOIN LOTATTRIBUTE AS LA  WITH (NOLOCK) ON LLI.Lot = LA.Lot    
LEFT JOIN Pack         AS P   WITH (NOLOCK) ON S.PACKKey = P.PackKey
WHERE LLI.EditDate >= Dateadd(Month, Datediff(Month, 0, DATEADD(m, -3, current_timestamp)), 0)  

GO