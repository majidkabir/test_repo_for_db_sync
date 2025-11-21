CREATE TABLE [dbo].[withdrawstock]
(
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NOT NULL,
    [LOT] nvarchar(10) NULL DEFAULT (' '),
    [ID] nvarchar(18) NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [RowId] int IDENTITY(1,1) NOT NULL,
    [Sourcekey] nvarchar(20) NULL,
    [Sourcetype] nvarchar(30) NULL,
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
    CONSTRAINT [PK_WithdrawStock] PRIMARY KEY ([RowId])
);
GO
