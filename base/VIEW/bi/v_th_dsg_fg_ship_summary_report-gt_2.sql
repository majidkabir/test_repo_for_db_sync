SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_FG_Ship_Summary_Report-GT_2] AS
SELECT
   case
      when
         O.Status = '9'
      then
         'Shipped'
      when
         O.Status = '0'
      then
         'Open'
      when
         O.Status = '3'
      then
         'Picking'
      when
         O.Status = '5'
      then
         'Picked'
      when
         O.Status = 'CANC'
      then
         'Cancelled'
      Else
         'Allocated'
   end AS 'Order Status'
, O.OrderKey, O.ExternOrderKey, O.OrderDate, O.ConsigneeKey, O.Type, O.EditDate, O.LoadKey, O.MBOLKey, OD.ExternLineNo, OD.Sku, S.DESCR, OD.OriginalQty, OD.QtyAllocated, OD.QtyPicked, OD.ShippedQty, P.PackUOM3, P.CaseCnt, P.PackUOM1,
   (
      OD.OriginalQty
   )
   / (P.CaseCnt) AS 'OriginalQTY(Case)',
   (
      OD.QtyAllocated
   )
   / (P.CaseCnt) AS 'Qtyallocated (Case)',
   (
      OD.OriginalQty
   )
   - ( (OD.ShippedQty) + (OD.QtyAllocated) + (OD.QtyPicked) ) AS 'Short Shipped (BG)',
   (
(OD.OriginalQty) / (P.CaseCnt)
   )
   - ( ((OD.ShippedQty) / (P.CaseCnt)) + ((OD.QtyAllocated) / (P.CaseCnt)) + ((OD.QtyPicked) / (P.CaseCnt)) ) AS 'Short Shipped(Case)' , SUBSTRING ( OD.Lottable01, 5, 4 ) + SUBSTRING ( OD.Lottable01, 3, 2 ) + SUBSTRING ( OD.Lottable01, 1, 2 ) AS 'MFG Date', OD.Lottable04 AS ' Expiry Date',
   (OD.ShippedQty) / (P.CaseCnt) AS 'Qty ShippedQty',
   ( OD.QtyPicked) / (P.CaseCnt)  AS 'QtyPick (Case)'

FROM dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
JOIN dbo.SKU S with (nolock) ON OD.Sku = S.Sku
      AND OD.StorerKey = S.StorerKey
JOIN dbo.PACK P  with (nolock) ON S.PACKKey = P.PackKey
WHERE O.StorerKey = 'DSGTH'
AND O.Type = 'DK'
AND O.Status = '9'
AND O.EditDate >= convert(varchar(10), getdate() - 1, 120)
--ORDER BY
--   3, 10
--   --ExternOrderkey,Externline No.

GO