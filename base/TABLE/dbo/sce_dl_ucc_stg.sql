CREATE TABLE [dbo].[sce_dl_ucc_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [UCCNo] nvarchar(40) NULL,
    [Storerkey] nvarchar(40) NULL,
    [ExternKey] nvarchar(40) NULL DEFAULT (''),
    [SKU] nvarchar(40) NULL DEFAULT (''),
    [Qty] int NULL,
    [SourceKey] nvarchar(40) NULL,
    [SourceType] nvarchar(40) NULL,
    [Userdefined01] nvarchar(15) NULL,
    [Userdefined02] nvarchar(15) NULL,
    [Userdefined03] nvarchar(20) NULL,
    [Userdefined04] nvarchar(30) NULL DEFAULT (''),
    [Userdefined05] nvarchar(30) NULL DEFAULT (''),
    [Userdefined06] nvarchar(30) NULL DEFAULT (''),
    [Userdefined07] nvarchar(30) NULL DEFAULT (''),
    [Userdefined08] nvarchar(30) NULL DEFAULT (''),
    [Userdefined09] nvarchar(30) NULL DEFAULT (''),
    [Userdefined10] nvarchar(30) NULL DEFAULT (''),
    [Status] nvarchar(20) NULL,
    [Lot] nvarchar(10) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL DEFAULT (''),
    [Id] nvarchar(18) NULL DEFAULT (''),
    [Receiptkey] nvarchar(10) NULL DEFAULT (' '),
    [ReceiptLineNumber] nvarchar(5) NULL DEFAULT (' '),
    [Orderkey] nvarchar(10) NULL DEFAULT (' '),
    [OrderLineNumber] nvarchar(5) NULL DEFAULT (' '),
    [WaveKey] nvarchar(10) NULL DEFAULT (' '),
    [PickDetailKey] nvarchar(18) NULL DEFAULT (' '),
    [UCC_RowRef] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_UCC_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_UCC_STG_Idx01] ON [dbo].[sce_dl_ucc_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_UCC_STG_Idx02] ON [dbo].[sce_dl_ucc_stg] ([STG_BatchNo], [STG_SeqNo]);
GO