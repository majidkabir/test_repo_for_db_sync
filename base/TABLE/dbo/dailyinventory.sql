CREATE TABLE [dbo].[dailyinventory]
(
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL,
    [InventoryDate] datetime NOT NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [InventoryCBM] float NULL DEFAULT ((0)),
    [InventoryPallet] float NULL DEFAULT ((0)),
    [CommingleSku] nvarchar(1) NULL DEFAULT ('0'),
    [SkuInventoryPallet] float NULL DEFAULT ((0)),
    [SkuChargingPallet] float NULL DEFAULT ((0)),
    [Lot] nvarchar(10) NOT NULL,
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [QtyPicked] int NOT NULL DEFAULT ((0)),
    [Pallet] float NOT NULL DEFAULT ((0)),
    [StdCube] float NOT NULL DEFAULT ((0)),
    [Facility] nvarchar(5) NOT NULL DEFAULT (' '),
    [HostWhCode] nvarchar(10) NULL,
    [LocationFlag] nvarchar(10) NOT NULL DEFAULT (' '),
    [Lottable01] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable03] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [QtyOnhold] int NOT NULL DEFAULT ((0)),
    [ArchiveCop] nvarchar(1) NULL,
    [Lottable06] nvarchar(30) NULL DEFAULT (''),
    [Lottable07] nvarchar(30) NULL DEFAULT (''),
    [Lottable08] nvarchar(30) NULL DEFAULT (''),
    [Lottable09] nvarchar(30) NULL DEFAULT (''),
    [Lottable10] nvarchar(30) NULL DEFAULT (''),
    [Lottable11] nvarchar(30) NULL DEFAULT (''),
    [Lottable12] nvarchar(30) NULL DEFAULT (''),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    CONSTRAINT [PKDailyInventory] PRIMARY KEY ([InventoryDate], [Storerkey], [Sku], [Lot], [Loc], [Id])
);
GO

CREATE INDEX [IDX_DailyInventory_InventoryDate2] ON [dbo].[dailyinventory] ([Storerkey], [InventoryDate]);
GO
CREATE INDEX [IDX_DailyInventory_Loc] ON [dbo].[dailyinventory] ([Loc]);
GO
CREATE INDEX [IX_DailyInventory_ArchiveCop] ON [dbo].[dailyinventory] ([ArchiveCop]);
GO