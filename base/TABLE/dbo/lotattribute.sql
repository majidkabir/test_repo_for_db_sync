CREATE TABLE [dbo].[lotattribute]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Lottable01] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable03] nvarchar(18) NOT NULL DEFAULT (' '),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Flag] nvarchar(1) NOT NULL DEFAULT (' '),
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
    CONSTRAINT [PKLOTAttribute] PRIMARY KEY ([Lot]),
    CONSTRAINT [FK_LOTATTRIBUTE_STORER_01] FOREIGN KEY ([StorerKey]) REFERENCES [dbo].[STORER] ([StorerKey])
);
GO

CREATE INDEX [AK_LOTATTRIBUTE_01] ON [dbo].[lotattribute] ([StorerKey], [Sku], [Lottable01], [Lottable02], [Lottable03], [Lottable04], [Lottable05], [Lottable06], [Lottable07], [Lottable08], [Lottable09], [Lottable10], [Lottable11], [Lottable12], [Lottable13], [Lottable14]);
GO
CREATE INDEX [AK_LOTATTRIBUTE02] ON [dbo].[lotattribute] ([StorerKey], [Sku], [Lottable01], [Lottable05]);
GO
CREATE UNIQUE INDEX [IDX_LOTATTRIBUTE_SKU_LOT] ON [dbo].[lotattribute] ([StorerKey], [Sku], [Lot]);
GO