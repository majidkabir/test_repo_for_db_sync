SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_IDSMED_SHIP] AS
SELECT DISTINCT
   O.StorerKey,
   O.OrderKey,
   O.ExternOrderKey,
   O.C_Company,
   O.OrderGroup,
   O.BuyerPO,
   O.Salesman,
   O.MBOLKey,
   O.OrderDate,
   O.DeliveryDate,
   O.ConsigneeKey,
   OD.Sku,
   OD.Lottable12,
   S.DESCR,
   OD.ShippedQty,
   OD.UOM,
   OD.EditDate,
   OD.Lottable02,
   convert(varchar, OD.Lottable04, 103) AS 'Expire Date',
   O.Notes,
   S.STDCUBE
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
JOIN dbo.SKU S with (nolock) ON OD.StorerKey = S.StorerKey
      AND OD.Sku = S.Sku
WHERE
   (
(convert(varchar, O.EditDate, 112) >= convert(varchar, getdate() - 1, 112)
      and convert(varchar, O.EditDate, 112) < convert(varchar, getdate(), 112)
      AND O.StorerKey = 'IDSMED'
      AND O.Status = '9')
   )

GO