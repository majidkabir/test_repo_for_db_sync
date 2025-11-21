SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[v_IT69]
AS
SELECT                     a.OrderKey , a.Sku , c.UserDefine04, b.Lottable01, b.Lottable02, b.Lottable03, a.Lot, a.Qty, a.QtyMoved, a.Status, a.Loc, a.ID, SUBSTRING(b.Lottable02, 5, 2) + RTRIM(b.Sku)
                                      + SUBSTRING(b.Lottable02, 1, 12) + SUBSTRING(b.Lottable02, 14, 2) AS barcode, a.PickDetailKey
FROM                         dbo.PICKDETAIL AS a WITH (nolock) INNER JOIN
                                      dbo.LOTATTRIBUTE AS b WITH (nolock) ON a.Lot = b.Lot INNER JOIN
                                      dbo.ORDERS AS c WITH (nolock) ON a.OrderKey = c.OrderKey


GO