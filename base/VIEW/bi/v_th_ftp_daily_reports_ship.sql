SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_FTP_Daily_Reports_Ship] AS
SELECT
   O.StorerKey,
   O.ExternOrderKey,
   O.OrderDate,
   O.DeliveryDate,
   O.EditDate,
   O.ConsigneeKey,
   O.C_Company,
   PD.OrderLineNumber,
   PD.Sku,
   S.DESCR,
   Sum(PD.Qty) AS 'SumQTY',
   P.CaseCnt,
   P.InnerPack
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.PICKDETAIL PD with (nolock) ON O.OrderKey = PD.OrderKey
      AND O.StorerKey = PD.Storerkey
JOIN dbo.SKU S with (nolock) ON PD.Sku = S.Sku
      AND PD.Storerkey = S.StorerKey
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
WHERE
   (
(O.StorerKey = 'FTP'
      AND convert(date, O.EditDate) = convert(date, getdate() - 1))
   )
GROUP BY
   O.StorerKey,
   O.ExternOrderKey,
   O.OrderDate,
   O.DeliveryDate,
   O.EditDate,
   O.ConsigneeKey,
   O.C_Company,
   PD.OrderLineNumber,
   PD.Sku,
   S.DESCR,
   P.CaseCnt,
   P.InnerPack

GO