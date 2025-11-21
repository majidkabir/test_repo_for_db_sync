CREATE TABLE [dbo].[phy_inv2a_sku]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyLOTxLOCxID] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKPHY_INV2A_SKU] PRIMARY KEY ([StorerKey], [Sku])
);
GO
