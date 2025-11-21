SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_BONC_Outbound] AS
SELECT
   O.StorerKey,
   O.ExternOrderKey,
   O.ConsigneeKey,
   O.C_Company,
   OD.Sku,
   S.DESCR,
   PD.Qty,
   PD.ID,
   case
      when
         A.Lottable01 = 'UR'
      then
         'Saleable'
      else
         A.Lottable01
   end AS 'Ststus'
, A.Lottable02, A.Lottable03, A.Lottable04,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, CHARINDEX('-', A.Lottable06) + 1, Len(A.Lottable06))
   end AS 'Container No.'
,
   case
      when
         len(A.Lottable06) = '0'
      then
         ''
      else
         SUBSTRING(A.Lottable06, 1, CHARINDEX('-', A.Lottable06))
   end AS 'Invoice No.'
FROM dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
JOIN dbo.SKU S with (nolock) ON OD.StorerKey = S.StorerKey
      AND OD.Sku = S.Sku
JOIN dbo.PICKDETAIL PD with (nolock) ON OD.OrderKey = PD.OrderKey
      AND OD.StorerKey = PD.Storerkey
      AND OD.Sku = PD.Sku
      AND OD.OrderLineNumber = PD.OrderLineNumber
JOIN dbo.LOTATTRIBUTE A with (nolock) ON PD.Storerkey = A.StorerKey
      AND PD.Sku = A.Sku
      AND PD.Lot = A.Lot
WHERE O.StorerKey = 'BONC'
      AND O.Status = '9'
      AND convert(varchar, OD.EditDate, 112) >= convert(varchar, getdate() - 1, 112)

GO