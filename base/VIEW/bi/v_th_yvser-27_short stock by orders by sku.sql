SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-27_Short stock by orders by sku] as 

SELECT  ORDERS.StorerKey, ORDERS.Status, ORDERS.OrderKey, ORDERS.ExternOrderKey,ORDERS.Notes as ReceiptNumber ,
		FORMAT( ORDERDetail.AddDate, 'dd-MM-yyyy HH:mm:ss') as AddDate, 
		CONVERT(varchar, ORDERS.OrderDate, 105) as OrderDate, 
		CONVERT(varchar, ORDERS.DeliveryDate, 105) as DeliveryDate,  
        ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_City, ORDERS.C_State, ORDERS.C_Phone1,  ORDERDetail.OrderLineNumber, ORDERDetail.Sku, SKU.DESCR
		, ORDERDetail.OriginalQty as OrderQTY
        , SOH.OrderQTY as SKU_OrderinProgress
		, CONVERT(varchar,  case when SOH.SellableQty >= 0 then SOH.SellableQty else '' end ) as [SKU_SellableQty] 
		, CONVERT(varchar,  case when SOH.SellableQty < 0 then SOH.SellableQty else  '' end  ) as  [SKU_ShortageQty]
FROM    ORDERS with (nolock) 
INNER JOIN ORDERDetail with (nolock) ON ORDERS.OrderKey = ORDERDetail.OrderKey 
INNER JOIN SKU with (nolock) ON ORDERDetail.StorerKey = SKU.StorerKey AND ORDERDetail.Sku = SKU.Sku 
INNER JOIN (SELECT	loclot.Sku, loclot.QTYinWH, ord.OrderQTY, CONVERT(varchar, loclot.QTYinWH - ord.OrderQTY) AS SellableQty
            FROM 	(SELECT	Sku, SUM(Qty - (QtyAllocated + QtyPicked)) AS QTYinWH
                    FROM	LOTxLOCxID with (nolock)
                    WHERE   (StorerKey = 'YVESR' ) and loc not in (  select code from codelkup with (nolock) where StorerKey = 'YVESR' and listname = 'yrexsoh' )
                    GROUP BY Sku) AS loclot 
			INNER JOIN (SELECT	Sku, SUM(OriginalQty) AS OrderQTY
                        FROM	ORDERDetail WITH (nolock)
                        WHERE	(StorerKey = 'YVESR') AND (Status IN ('0', '1'))
                        GROUP BY Sku) AS ord ON ord.Sku = loclot.Sku) AS SOH ON SOH.Sku = SKU.Sku
WHERE	(ORDERS.StorerKey = N'YVESR') 
AND 	(ORDERS.Status IN (N'0', N'1'))

GO