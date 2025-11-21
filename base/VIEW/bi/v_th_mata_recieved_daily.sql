SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MATA_Recieved_daily] AS
SELECT
   R.ReceiptDate AS 'Receipted date IDS',
   R.POKey AS 'PO Number',
   R.POKey AS 'IDS_Reference',
   ST.Company AS 'Supplier code',
   RD.Sku AS 'CAI',
   substring(S.DESCR, charindex(';', S.DESCR ) + 2, 30) AS 'Size',
   RD.Lottable02 AS 'Serial No.',
   RD.Lottable01,
   RD.QtyReceived,
   substring(RD.Lottable03, 1, 1) AS 'Last rethreaded R level',
   RD.Lottable09 AS 'Last R/O No.',
   case
((substring(RD.Lottable03, 1, 1)))
      when
         '0'
      then
         'N'
      ELSE
         'R'
   end AS 'Status'
, R.Facility,
   case
((R.Facility))
      when
         '3101'
      then
((RD.Lottable01))
      ELSE
(substring(RD.Lottable01, 1, 3))
   end AS 'Customer code'
,
   case
      when
         charindex('/', RD.Lottable01) = 0
      then
         ' '
      else
         substring(RD.Lottable01, 1, charindex('/', RD.Lottable01) - 1)
   end AS 'Airlines'
, S.SKUGROUP, S.BUSR6 AS 'Type', RD.AddDate, RD.AddWho, RD.AltSku, RD.ArchiveCop, RD.BeforeReceivedQty, RD.CaseCnt, RD.ConditionCode, RD.ContainerKey, RD.Cube, RD.DateReceived, RD.DuplicateFrom, RD.EditDate, RD.EditWho, RD.EffectiveDate, RD.ExportStatus, RD.ExtendedPrice, RD.ExternLineNo, RD.ExternPoKey, RD.ExternReceiptKey, RD.FinalizeFlag, RD.FreeGoodQtyExpected, RD.FreeGoodQtyReceived, RD.GrossWgt, RD.Id, RD.InnerPack, RD.LoadKey, RD.Lottable01 AS 'Lottable2', RD.Lottable02, RD.Lottable03, RD.Lottable04, RD.Lottable05, RD.NetWgt, RD.OtherUnit1, RD.OtherUnit2, RD.PackKey, RD.Pallet, RD.POKey, RD.POLineNumber, RD.PutawayLoc, RD.QtyAdjusted, RD.QtyExpected , RD.QtyReceived AS 'Qty_received', RD.ReceiptKey, RD.ReceiptLineNumber, RD.Sku, RD.SourceKey, RD.SplitPalletFlag, RD.Status AS 'Status2', RD.StorerKey, RD.SubReasonCode, RD.TariffKey, RD.Lottable11 AS 'Remark'
FROM
   dbo.RECEIPT R with (nolock)
JOIN dbo.V_RECEIPTDETAIL RD with (nolock) ON R.ReceiptKey = RD.ReceiptKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
JOIN dbo.STORER ST with (nolock) ON R.CarrierKey = ST.StorerKey
WHERE
   (
(R.StorerKey = 'MATA'
      AND R.Facility IN
      (
         'IND', 'MCNKA', 'MCNKF'
      )
      AND R.ReceiptDate >= convert(varchar(10), getdate() - 1, 120)
      and R.ReceiptDate < convert(varchar(10), getdate(), 120)
      AND RD.QtyReceived > 0)
   )
--ORDER BY
--   1
---ReceiptDate

GO