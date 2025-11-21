SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_DSG_DailyReport_v5] AS
SELECT DISTINCT
   R.ReceiptDate,
   RD.ExternReceiptKey,
   RD.ExternLineNo,
   R.Facility,
   RD.Sku,
   S.DESCR,
   S.ABC AS 'Level',
   RD.Lottable02,
   SUM ( RD.QtyReceived ) AS 'QtyReceivedBG',
   SUM ( RD.QtyReceived / P.CaseCnt ) AS 'QtyReceivedCA',
   Count (RD.Sku) AS 'No.of Pallet',
   RD.ToLoc,
   L.HOSTWHCODE,
   RD.ToId,
   RD.ContainerKey,
   RD.UserDefine01,
   R.ReceiptKey
FROM dbo.RECEIPTDETAIL RD with (nolock)
JOIN dbo.RECEIPT R with (nolock) ON RD.ReceiptKey = R.ReceiptKey
	AND	RD.StorerKey = R.StorerKey
JOIN dbo.SKU S with (nolock) ON RD.Sku = S.Sku
	AND R.StorerKey = S.StorerKey
JOIN dbo.PACK P with (nolock) ON S.PACKKey = P.PackKey
JOIN dbo.LOC L with (nolock) ON RD.ToLoc = L.Loc
WHERE
(R.Facility IN
      (
         '18120',
         '18130',
         '18140'
      )
      AND RD.StorerKey = 'DSGTH'
      AND R.ASNStatus = '9'
      AND convert(date, R.ReceiptDate) between convert(date, getdate() - 1) and convert(date, getdate()))
GROUP BY
   R.ReceiptDate,
   RD.ExternReceiptKey,
   RD.ExternLineNo,
   R.Facility,
   RD.Sku,
   S.DESCR,
   S.ABC,
   RD.Lottable02,
   RD.ToLoc,
   L.HOSTWHCODE,
   RD.ToId,
   RD.ContainerKey,
   RD.UserDefine01,
   R.ReceiptKey
--ORDER BY
--   7
--   --Level

GO