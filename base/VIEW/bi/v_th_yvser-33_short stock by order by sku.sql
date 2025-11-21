SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-33_Short stock by order by sku] as 
SELECT	ORDERS.StorerKey, ORDERS.Status, ORDERS.OrderKey, ORDERS.ExternOrderKey, ORDERS.OrderDate, ORDERS.DeliveryDate, ORDERS.AddDate, ORDERS.EditDate, 
        ORDERS.ConsigneeKey, ORDERS.C_Company, ORDERS.C_City, ORDERS.C_State, ORDERDetail.OrderLineNumber, ORDERDetail.Sku, SKU.DESCR, ORDERDetail.OriginalQty, 
        SOH.QTYinWH as SKU_QTYinWH , SOH.SellableQty as SKU_SellableQty
FROM	ORDERS with (nolock) 
INNER JOIN ORDERDetail with (nolock) ON ORDERS.OrderKey = ORDERDetail.OrderKey 
INNER JOIN SKU with (nolock) ON ORDERDetail.StorerKey = SKU.StorerKey AND ORDERDetail.Sku = SKU.Sku 
INNER JOIN (SELECT	SOH_1.Sku, SOH_1.QTYinWH, ord.OrderQTY, SOH_1.QTYinWH - ord.OrderQTY AS SellableQty
            FROM	(SELECT	Sku, SUM(Qty - (QtyAllocated + QtyPicked)) AS QTYinWH
					FROM	LOTxLOCxID with (nolock) 
                    WHERE	(StorerKey = 'YVESR')
                    GROUP BY Sku) AS SOH_1 
			INNER JOIN (SELECT	Sku, SUM(OriginalQty) AS OrderQTY
                        FROM	ORDERDetail WITH (nolock)
                        WHERE	(StorerKey = 'YVESR') AND (Status IN ('0', '1'))
                        GROUP BY Sku) AS ord ON ord.Sku = SOH_1.Sku) AS SOH ON SOH.Sku = SKU.Sku
WHERE	(ORDERS.StorerKey = N'YVESR') 
AND 	(ORDERS.Status IN (N'0', N'1'))

GO