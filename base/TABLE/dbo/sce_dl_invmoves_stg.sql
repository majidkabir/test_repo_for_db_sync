CREATE TABLE [dbo].[sce_dl_invmoves_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [StorerKey] nvarchar(15) NULL,
    [Facility] nvarchar(5) NULL,
    [Sku] nvarchar(20) NULL,
    [Descr] nvarchar(60) NULL,
    [Style] nvarchar(20) NULL,
    [Color] nvarchar(10) NULL,
    [Lot] nvarchar(10) NULL,
    [Loc] nvarchar(10) NULL,
    [MovableUnit] nvarchar(18) NULL,
    [Qty_available] int NULL DEFAULT ((0)),
    [ToQty] int NULL DEFAULT ((0)),
    [ToLoc] nvarchar(10) NULL,
    [ToId] nvarchar(18) NULL,
    [ToUom] nvarchar(10) NULL,
    [ToPackKey] nvarchar(10) NULL,
    [Pack_uom3] nvarchar(10) NULL,
    [Delivery_unit] int NULL DEFAULT ((0)),
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
    [Qty] int NULL DEFAULT ((0)),
    [Allocated] int NULL DEFAULT ((0)),
    [Picked] int NULL DEFAULT ((0)),
    [OverAllocated] int NULL DEFAULT ((0)),
    [PicksInProcess] int NULL DEFAULT ((0)),
    [Size] nvarchar(10) NULL,
    CONSTRAINT [PK_SCE_DL_INVMOVES_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_INVMOVES_STG_Idx01] ON [dbo].[sce_dl_invmoves_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_INVMOVES_STG_Idx02] ON [dbo].[sce_dl_invmoves_stg] ([STG_BatchNo], [STG_SeqNo]);
GO