SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_GT-MT_Auto_Transfer] AS
SELECT
   TD.FromSku AS 'SKUItem',
   S.DESCR,
   TD.FromUOM AS 'UOM',
   TD.LOTTABLE03 AS 'FromWhLocation',
   TD.tolottable03 AS 'ToWhLocation',
   SUM ( TD.FromQty ) AS 'TransferQty'
FROM
   dbo.TRANSFER T with (nolock)
JOIN dbo.TRANSFERDETAIL TD with (nolock) ON T.TransferKey = TD.TransferKey
      AND T.FromStorerKey = TD.FromStorerKey
JOIN dbo.SKU S with (nolock) ON TD.FromStorerKey = S.StorerKey
      AND TD.FromSku = S.Sku
WHERE T.FromStorerKey = 'DSGTH'
      AND T.Type = 'RELOT'
      AND T.UserDefine01 = 'GT/MT Auto transfer'
      AND T.Status = '9'
      AND convert(date, T.EditDate) between convert(date, getdate() - 1) and convert(date, getdate())
GROUP BY
   TD.FromSku,
   S.DESCR,
   TD.FromUOM,
   TD.LOTTABLE03,
   TD.tolottable03

GO