SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_RECEIPTDETAIL_ROIC]
AS
SELECT 	distinct rd.*,
	TransDate = CONVERT(datetime, CONVERT(char(10), i.adddate, 103), 103)
FROM 	RECEIPTDETAIL rd (nolock),
	ITRN i (nolock)
WHERE	i.sourcekey = rd.receiptkey+rd.receiptlinenumber and
	i.sourcetype like 'ntrReceiptDetail%'



GO