CREATE TABLE [dbo].[phy_inv2a_id]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyLOTxLOCxID] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKPHY_INV2A_ID] PRIMARY KEY ([Id])
);
GO
