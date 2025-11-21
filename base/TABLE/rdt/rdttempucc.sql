CREATE TABLE [rdt].[rdttempucc]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TaskType] nvarchar(10) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [LOT] nvarchar(10) NULL,
    [LOC] nvarchar(10) NULL,
    [ID] nvarchar(18) NULL,
    [Lottable01] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable03] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Lottable06] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable07] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable08] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable09] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable10] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable11] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable12] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    [UCCLottable01] nvarchar(18) NULL DEFAULT (''),
    [UCCLottable02] nvarchar(18) NULL DEFAULT (''),
    [UCCLottable03] nvarchar(18) NULL DEFAULT (''),
    [UCCLottable04] datetime NULL,
    [UCCLottable05] datetime NULL,
    [UCCLottable06] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable07] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable08] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable09] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable10] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable11] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable12] nvarchar(30) NULL DEFAULT (''),
    [UCCLottable13] datetime NULL,
    [UCCLottable14] datetime NULL,
    [UCCLottable15] datetime NULL,
    CONSTRAINT [PKRDTTempUCC] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_RDTTempUCC_TaskType_StorerKey_SKU_LOC] ON [rdt].[rdttempucc] ([TaskType], [StorerKey], [SKU], [LOC]);
GO
CREATE INDEX [IDX_RDTTempUCC_UCCNo] ON [rdt].[rdttempucc] ([UCCNo]);
GO