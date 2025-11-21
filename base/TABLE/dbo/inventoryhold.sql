CREATE TABLE [dbo].[inventoryhold]
(
    [InventoryHoldKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT (' '),
    [Hold] nvarchar(1) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT (' '),
    [DateOn] datetime NOT NULL DEFAULT (getdate()),
    [WhoOn] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [DateOff] datetime NOT NULL DEFAULT (getdate()),
    [WhoOff] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [SKU] nvarchar(20) NULL DEFAULT (' '),
    [Storerkey] nvarchar(18) NULL DEFAULT (' '),
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [Remark] nvarchar(255) NULL,
    [Lottable06] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable07] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable08] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable09] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable10] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable11] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable12] nvarchar(30) NOT NULL DEFAULT (' '),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    CONSTRAINT [PKINVENTORYHOLD] PRIMARY KEY ([InventoryHoldKey]),
    CONSTRAINT [CK_IH_01] CHECK (NOT ltrim(rtrim([Lot]))='' AND ltrim(rtrim([Loc]))='' AND ltrim(rtrim([id]))='' AND isnull(ltrim(rtrim([lottable01])),' ')=' ' AND isnull(ltrim(rtrim([lottable02])),' ')=' ' AND isnull(ltrim(rtrim([lottable03])),' ')=' ' AND isnull([lottable04],' ')=' ' AND isnull([lottable05],' ')=' ' AND isnull(ltrim(rtrim([lottable06])),' ')=' ' AND isnull(ltrim(rtrim([lottable07])),' ')=' ' AND isnull(ltrim(rtrim([lottable08])),' ')=' ' AND isnull(ltrim(rtrim([lottable09])),' ')=' ' AND isnull(ltrim(rtrim([lottable10])),' ')=' ' AND isnull(ltrim(rtrim([lottable11])),' ')=' ' AND isnull(ltrim(rtrim([lottable12])),' ')=' ' AND isnull([lottable13],' ')=' ' AND isnull([lottable14],' ')=' ' AND isnull([lottable15],' ')=' ' OR ltrim(rtrim([Lot]))='' AND NOT ltrim(rtrim([Loc]))='' AND ltrim(rtrim([id]))='' AND isnull(ltrim(rtrim([lottable01])),' ')=' ' AND isnull(ltrim(rtrim([lottable02])),' ')=' ' AND isnull(ltrim(rtrim([lottable03])),' ')=' ' AND isnull([lottable04],' ')=' ' AND isnull([lottable05],' ')=' ' AND isnull(ltrim(rtrim([lottable06])),' ')=' ' AND isnull(ltrim(rtrim([lottable07])),' ')=' ' AND isnull(ltrim(rtrim([lottable08])),' ')=' ' AND isnull(ltrim(rtrim([lottable09])),' ')=' ' AND isnull(ltrim(rtrim([lottable10])),' ')=' ' AND isnull(ltrim(rtrim([lottable11])),' ')=' ' AND isnull(ltrim(rtrim([lottable12])),' ')=' ' AND isnull([lottable13],' ')=' ' AND isnull([lottable14],' ')=' ' AND isnull([lottable15],' ')=' ' OR ltrim(rtrim([Lot]))='' AND ltrim(rtrim([Loc]))='' AND NOT ltrim(rtrim([id]))='' AND isnull(ltrim(rtrim([lottable01])),' ')=' ' AND isnull(ltrim(rtrim([lottable02])),' ')=' ' AND isnull(ltrim(rtrim([lottable03])),' ')=' ' AND isnull([lottable04],' ')=' ' AND isnull([lottable05],' ')=' ' AND isnull(ltrim(rtrim([lottable06])),' ')=' ' AND isnull(ltrim(rtrim([lottable07])),' ')=' ' AND isnull(ltrim(rtrim([lottable08])),' ')=' ' AND isnull(ltrim(rtrim([lottable09])),' ')=' ' AND isnull(ltrim(rtrim([lottable10])),' ')=' ' AND isnull(ltrim(rtrim([lottable11])),' ')=' ' AND isnull(ltrim(rtrim([lottable12])),' ')=' ' AND isnull([lottable13],' ')=' ' AND isnull([lottable14],' ')=' ' AND isnull([lottable15],' ')=' ' OR ltrim(rtrim([Lot]))='' AND ltrim(rtrim([Loc]))='' AND ltrim(rtrim([id]))='' AND NOT ltrim(rtrim([storerkey]))='' AND NOT ltrim(rtrim([sku]))='' AND (NOT ltrim(rtrim([lottable01]))='' OR NOT ltrim(rtrim([lottable02]))='' OR NOT ltrim(rtrim([lottable03]))='' OR NOT [lottable04]='' OR NOT [lottable05]='' OR NOT ltrim(rtrim([lottable06]))='' OR NOT ltrim(rtrim([lottable07]))='' OR NOT ltrim(rtrim([lottable08]))='' OR NOT ltrim(rtrim([lottable09]))='' OR NOT ltrim(rtrim([lottable10]))='' OR NOT ltrim(rtrim([lottable11]))='' OR NOT ltrim(rtrim([lottable12]))='' OR NOT [lottable13]='' OR NOT [lottable14]='' OR NOT [lottable15]=''))
);
GO

CREATE INDEX [IX_INVENTORYHOLD_ID] ON [dbo].[inventoryhold] ([Id]);
GO
CREATE INDEX [IX_INVENTORYHOLD_LOC] ON [dbo].[inventoryhold] ([Loc]);
GO
CREATE INDEX [IX_INVENTORYHOLD_LOT] ON [dbo].[inventoryhold] ([Lot]);
GO
CREATE INDEX [IX_INVENTORYHOLD_LOTATT] ON [dbo].[inventoryhold] ([Storerkey], [SKU], [Lottable01], [Lottable02], [Lottable03], [Lottable04], [Lottable06], [Lottable07], [Lottable08], [Lottable09], [Lottable10], [Lottable11], [Lottable12], [Lottable13], [Lottable14], [Lottable15]);
GO