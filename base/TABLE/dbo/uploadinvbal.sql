CREATE TABLE [dbo].[uploadinvbal]
(
    [STORERKEY] nvarchar(15) NULL DEFAULT (' '),
    [SKU] nvarchar(20) NULL DEFAULT (' '),
    [LOCATION] nvarchar(10) NULL DEFAULT (' '),
    [lottable01] nvarchar(18) NULL DEFAULT (' '),
    [lottable02] nvarchar(18) NULL DEFAULT (' '),
    [lottable03] nvarchar(18) NULL DEFAULT (' '),
    [lottable04] datetime NULL DEFAULT ((0)),
    [lottable05] datetime NULL DEFAULT ((0)),
    [QTY] int NULL DEFAULT ((0)),
    [STATUS] nvarchar(5) NULL DEFAULT ('1'),
    [RUNNING] int IDENTITY(1,1) NOT NULL,
    [UploadStatus] nvarchar(3) NULL DEFAULT ('NO'),
    [Reason] nvarchar(255) NULL DEFAULT (' '),
    [OldLocation] nvarchar(10) NULL DEFAULT (' '),
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
    [Channel] nvarchar(20) NULL DEFAULT ('')
);
GO
