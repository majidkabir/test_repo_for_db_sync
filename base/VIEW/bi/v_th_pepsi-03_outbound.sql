SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_PEPSI-03_Outbound] as
SELECT
   O.StorerKey,
   O.ExternOrderKey,
   O.ConsigneeKey,
   O.C_Company,
   O.DeliveryDate,
   O.Status,
   O.EditDate,
   OD.OrderLineNumber,
   S.DESCR,
   OD.Sku,
   OD.ShippedQty + OD.QtyPicked as 'QTY Pick and shipped',
   DATEDIFF ( dy, O.EditDate,
   (
      getdate()
   )
)as 'Aging',
   getdate() as 'date'
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
JOIN dbo.SKU S with (nolock) ON OD.StorerKey = S.StorerKey
      AND OD.Sku = S.Sku
WHERE
   (
(O.StorerKey = 'PEPSI'
      AND O.Status IN
      (
         '5',
         '9'
      )
      AND convert(varchar, O.EditDate, 120) between convert(varchar, getdate() - 2, 23) + ' 04:00:00' and convert(varchar, getdate(), 23) + ' 04:00:00')
   )

GO