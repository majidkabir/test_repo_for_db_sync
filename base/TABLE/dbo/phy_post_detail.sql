CREATE TABLE [dbo].[phy_post_detail]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT (' '),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [QtyTeamA] int NOT NULL DEFAULT ((0)),
    [QtyLOTxLOCxID] int NOT NULL DEFAULT ((0))
);
GO
