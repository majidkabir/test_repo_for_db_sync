SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


Create View [dbo].[V_Monthly_Order_Summary]
as SELECT datepart(yyyy,AL2.EditDate) as Year, 
      datepart(mm,AL2.EditDate) as Month, 
      COUNT (DISTINCT (AL2.MbolKey)) as Customer_MBOLs, 
      COUNT (DISTINCT (AL1.OrderKey)) as Customer_Orders, 
      Count (AL4.OrderLineNumber) as Customer_Order_Lines, 
      COUNT (DISTINCT (AL4.Sku)) as Order_Sku, 
      SUM ( AL4.ShippedQty ) as Unit_Shipped
FROM dbo.V_ORDERS AL1 with (NOLOCK)
   JOIN dbo.V_MBOLDETAIL AL3 with (NOLOCK) on (AL3.OrderKey = AL1.OrderKey)
   JOIN dbo.V_MBOL AL2 with (NOLOCK)       on (AL2.MbolKey = AL3.MbolKey )
   JOIN dbo.V_ORDERDETAIL AL4 with (NOLOCK) on (AL1.OrderKey = AL4.OrderKey 
                              AND AL1.StorerKey = AL4.StorerKey)
WHERE (AL2.Status='9') 
GROUP BY datepart(yyyy,AL2.EditDate), datepart(mm,AL2.EditDate)


GO