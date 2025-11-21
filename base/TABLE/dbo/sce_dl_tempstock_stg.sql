CREATE TABLE [dbo].[sce_dl_tempstock_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [ID] nvarchar(18) NULL,
    [Loc] nvarchar(10) NULL,
    [Qty] int NULL,
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [Sourcekey] nvarchar(20) NULL,
    [Sourcetype] nvarchar(30) NULL,
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
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_TEMPSTOCK_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_TEMPSTOCK_STG_Idx01] ON [dbo].[sce_dl_tempstock_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_TEMPSTOCK_STG_Idx02] ON [dbo].[sce_dl_tempstock_stg] ([STG_BatchNo], [STG_SeqNo]);
GO