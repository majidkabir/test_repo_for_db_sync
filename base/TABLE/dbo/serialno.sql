CREATE TABLE [dbo].[serialno]
(
    [SerialNoKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [SerialNo] nvarchar(30) NOT NULL,
    [Qty] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [LotNo] nvarchar(20) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ID] nvarchar(18) NULL DEFAULT (''),
    [ExternStatus] nvarchar(10) NULL DEFAULT ('0'),
    [PickSlipNo] nvarchar(10) NULL DEFAULT (''),
    [CartonNo] int NULL DEFAULT ((0)),
    [LabelLine] nvarchar(5) NULL DEFAULT (''),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    [Lot] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_SerialNo] PRIMARY KEY ([SerialNoKey])
);
GO

CREATE INDEX [IX_SerialNo_Orders] ON [dbo].[serialno] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [IX_SerialNo_Pack] ON [dbo].[serialno] ([PickSlipNo], [CartonNo], [LabelLine]);
GO
CREATE INDEX [IX_SerialNo_UCCNo] ON [dbo].[serialno] ([UCCNo], [SKU], [StorerKey]);
GO
CREATE INDEX [IX_StorerKey_SerialNo] ON [dbo].[serialno] ([StorerKey], [SerialNo]);
GO