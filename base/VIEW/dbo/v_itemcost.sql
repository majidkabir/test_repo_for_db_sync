SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[v_ItemCost]
AS
Select	storerkey,
	sku = sku,
	cost = cost,
	busr10 = busr10
From	sku (nolock)





GO