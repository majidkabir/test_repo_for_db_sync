CREATE TABLE [dbo].[sce_dl_serialno_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [SerialNo] nvarchar(4000) NULL,
    [Qty] int NULL DEFAULT ((0)),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [LotNo] nvarchar(20) NULL,
    [ActionFlag] nvarchar(2) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [ID] nvarchar(18) NULL DEFAULT (''),
    [ExternStatus] nvarchar(10) NULL DEFAULT ('0'),
    [PickSlipNo] nvarchar(10) NULL DEFAULT (''),
    [CartonNo] int NULL DEFAULT ((0)),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [LabelLine] nvarchar(5) NULL DEFAULT (''),
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    [Lot] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_SCE_DL_SERIALNO_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_SERIALNO_STG_Idx01] ON [dbo].[sce_dl_serialno_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_SERIALNO_STG_Idx02] ON [dbo].[sce_dl_serialno_stg] ([STG_BatchNo], [STG_SeqNo]);
GO