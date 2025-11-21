CREATE TABLE [dbo].[sce_dl_serialno]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [SerialNo] nvarchar(4000) NOT NULL,
    [Qty] int NULL DEFAULT ((0)),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [LotNo] nvarchar(20) NULL,
    [ActionFlag] nvarchar(2) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
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
    CONSTRAINT [PK_SCE_DL_SERIALNO] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [IX_SCE_DL_SERIALNO_Orders] ON [dbo].[sce_dl_serialno] ([OrderKey], [OrderLineNumber]);
GO