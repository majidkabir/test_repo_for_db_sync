CREATE TABLE [dbo].[phy_inv2a_lot]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyLOTxLOCxID] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKPHY_INV2A_LOT] PRIMARY KEY ([StorerKey], [Sku], [Lot])
);
GO
