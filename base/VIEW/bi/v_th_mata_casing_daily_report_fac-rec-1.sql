SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MATA_Casing_Daily_Report_fac-Rec-1] AS
SELECT DISTINCT
   RD.Lottable01 AS 'AirLine',
   R.OriginCountry AS 'Carriername',
   R.Signatory AS 'POkey',
   RIGHT(RD.Lottable03,
   case
      when
         CHARINDEX('/', REVERSE(RD.Lottable03)) - 1 < 0
      then
         ' '
      else
         CHARINDEX('/', REVERSE(RD.Lottable03)) - 1
   end
)AS 'Ro No.', R.ContainerKey, R.ReceiptKey, RD.ReceiptLineNumber, R.ExternReceiptKey, S.SKUGROUP, S.CLASS, S.SUSR3 AS 'Brand', RD.Sku, S.DESCR, RD.QtyExpected, RD.QtyReceived, RD.UOM, RD.Lottable06 AS 'Customer', RD.Lottable02 AS 'Serial No.', substring(RD.Lottable03, 1, 1)AS 'RL', RD.Lottable08 AS 'Status', RD.Lottable05 AS 'ReceiptDate',
   case
      when
         R.ContainerType = 'LTR40FT'
      then
         '40'
      when
         R.ContainerType = 'LTR20FT'
      then
         '20'
      when
         R.ContainerType = 'LTR6WH'
      then
         '6'
      else
         R.ContainerType
   end AS 'Containertype'
, R.ContainerQty, RD.Lottable07 AS 'Prod/Pool'
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
      AND R.ExternReceiptKey = RD.ExternReceiptKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
      AND RD.StorerKey = S.StorerKey
WHERE
   (
(R.StorerKey = 'MATA'
      AND R.EditDate >= DATEADD(dd, 0, DATEADD(mm, DATEDIFF(mm, 0, CURRENT_TIMESTAMP), 0))
      and R.EditDate < getdate ()
      AND R.Facility IN
      (
         'EANKE', 'MCNKC', 'MCNKE', 'NKG', 'NMNKC', 'NMNKE'
      )
      AND R.ASNStatus = '9')
   )

GO