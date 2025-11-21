CREATE TABLE [dbo].[inventoryhold_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [InventoryHoldKey] nvarchar(10) NULL DEFAULT (' '),
    [Lot] nvarchar(10) NULL DEFAULT (' '),
    [Id] nvarchar(18) NULL DEFAULT (' '),
    [Loc] nvarchar(10) NULL DEFAULT (' '),
    [Hold] nvarchar(1) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT (' '),
    [DateOn] datetime NULL DEFAULT (getdate()),
    [WhoOn] nvarchar(128) NULL DEFAULT (suser_sname()),
    [DateOff] datetime NULL DEFAULT (getdate()),
    [WhoOff] nvarchar(128) NULL DEFAULT (suser_sname()),
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
    [Lottable06] nvarchar(30) NULL DEFAULT (' '),
    [Lottable07] nvarchar(30) NULL DEFAULT (' '),
    [Lottable08] nvarchar(30) NULL DEFAULT (' '),
    [Lottable09] nvarchar(30) NULL DEFAULT (' '),
    [Lottable10] nvarchar(30) NULL DEFAULT (' '),
    [Lottable11] nvarchar(30) NULL DEFAULT (' '),
    [Lottable12] nvarchar(30) NULL DEFAULT (' '),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    CONSTRAINT [PK_INVENTORYHOLD_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [INVENTORYHOLD_STG_Idx01] ON [dbo].[inventoryhold_stg] ([STG_BatchNo]);
GO
CREATE INDEX [INVENTORYHOLD_STG_Idx02] ON [dbo].[inventoryhold_stg] ([STG_BatchNo], [STG_SeqNo]);
GO