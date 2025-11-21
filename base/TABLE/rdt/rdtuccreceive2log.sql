CREATE TABLE [rdt].[rdtuccreceive2log]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [ReceiptLineNumber] nvarchar(5) NOT NULL,
    [POKey] nvarchar(18) NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [UOM] nvarchar(10) NULL,
    [PackKey] nvarchar(10) NULL,
    [QtyExpected] int NOT NULL,
    [QtyReceived] int NOT NULL,
    [ToID] nvarchar(18) NOT NULL,
    [ToLOC] nvarchar(10) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [Lottable06] nvarchar(30) NULL,
    [Lottable07] nvarchar(30) NULL,
    [Lottable08] nvarchar(30) NULL,
    [Lottable09] nvarchar(30) NULL,
    [Lottable10] nvarchar(30) NULL,
    [Lottable11] nvarchar(30) NULL,
    [Lottable12] nvarchar(30) NULL,
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    [Status] nvarchar(10) NOT NULL,
    [ConditionCode] nvarchar(10) NULL,
    [AddDate] datetime NOT NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [EditDate] datetime NOT NULL,
    [EditWho] nvarchar(128) NOT NULL,
    CONSTRAINT [PK_rdtUCCReceive2Log] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtUCCReceive2Log_RptKey_Line_Stor_SKU] ON [rdt].[rdtuccreceive2log] ([ReceiptKey], [ReceiptLineNumber], [StorerKey], [SKU]);
GO