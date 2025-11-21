SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO










CREATE VIEW [dbo].[MovementHistory]
AS 	
	SELECT SKU.Storerkey, SKU.sku, SKU.Susr3,  Lotattribute.Lottable02, ITRN.TranType, ITRN.Qty, ITRN.Effectivedate, ITRN.ItrnKey
	 FROM Sku (nolock), Itrn (nolock), Lotattribute (nolock)
	WHERE Sku.Storerkey=Itrn.Storerkey
	AND Sku.Sku=Itrn.Sku
	AND Itrn.Lot=Lotattribute.Lot







GO