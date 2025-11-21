SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_NUTRA_Shipconfirm_Report_0800AM] AS
SELECT
   convert(char(10), O.OrderDate, 103) AS 'OrderDate',
   convert(char(10), O.EditDate, 103)AS 'ShippedDate',
   O.Status,
   O.ExternOrderKey,
   S.Sku,
   S.DESCR,
   OD.OriginalQty,
   OD.ShippedQty,
   O.OrderKey,
   case
      when
         O.ConsigneeKey = ''
      then
         O.C_Company
      when
         O.ConsigneeKey is null
      then
         O.C_Company
      else
         O.ConsigneeKey
   end AS 'Ship_To.'
, O.C_Address1 + O.C_Address2 + O.C_Address3 + O.C_Address4 As 'Address', O.StorerKey
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
JOIN dbo.SKU S with (nolock) ON OD.Sku = S.Sku
      AND OD.StorerKey = S.StorerKey
WHERE
   (
(O.StorerKey = 'NUTRA'
      AND convert(char(10), O.EditDate, 103) = convert(char(10), getdate() - 1, 103)
      AND O.Status = '5')
   )
--ORDER BY
--   1

GO