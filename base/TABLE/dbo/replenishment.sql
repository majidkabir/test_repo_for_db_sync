CREATE TABLE [dbo].[replenishment]
(
    [ReplenishmentKey] nvarchar(10) NOT NULL,
    [ReplenishmentGroup] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [ToLoc] nvarchar(10) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Id] nvarchar(18) NOT NULL,
    [Qty] int NOT NULL,
    [QtyMoved] int NULL DEFAULT ((0)),
    [QtyInPickLoc] int NULL DEFAULT ((0)),
    [Priority] nvarchar(5) NULL DEFAULT ('99999'),
    [UOM] nvarchar(10) NOT NULL,
    [PackKey] nvarchar(10) NOT NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Confirmed] nvarchar(1) NULL,
    [ReplenNo] nvarchar(10) NULL DEFAULT (' '),
    [Remark] nvarchar(255) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [RefNo] nvarchar(20) NULL DEFAULT (' '),
    [DropID] nvarchar(20) NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NULL DEFAULT (' '),
    [Wavekey] nvarchar(10) NULL DEFAULT (''),
    [OriginalFromLoc] nvarchar(10) NULL DEFAULT (''),
    [OriginalQty] int NULL DEFAULT ((0)),
    [ToID] nvarchar(18) NULL DEFAULT (''),
    [MoveRefKey] nvarchar(10) NULL DEFAULT (''),
    [PendingMoveIn] int NULL DEFAULT ((0)),
    [QtyReplen] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_REPLENISHMENT] PRIMARY KEY ([ReplenishmentKey])
);
GO

CREATE INDEX [IX_REPLENISHMENT_Group] ON [dbo].[replenishment] ([ReplenishmentGroup], [Storerkey]);
GO
CREATE INDEX [IX_REPLENISHMENT_RefNo] ON [dbo].[replenishment] ([RefNo]);
GO