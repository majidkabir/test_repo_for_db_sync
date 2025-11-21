CREATE TABLE [rdt].[rdtreplenishmentlog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
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
    CONSTRAINT [PK_rdtReplenishmentLog] PRIMARY KEY ([ReplenishmentKey])
);
GO

CREATE INDEX [IDX_rdtReplenishmentLog_01] ON [rdt].[rdtreplenishmentlog] ([Rowref]);
GO
CREATE INDEX [IDX_rdtReplenishmentLog_02] ON [rdt].[rdtreplenishmentlog] ([FromLoc], [Confirmed], [AddWho], [Wavekey]);
GO