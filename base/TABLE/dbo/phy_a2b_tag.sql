CREATE TABLE [dbo].[phy_a2b_tag]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [InventoryTag] nvarchar(18) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyTeamB] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKPHY_A2B_TAG] PRIMARY KEY ([StorerKey], [Sku], [Loc], [Id], [InventoryTag])
);
GO
