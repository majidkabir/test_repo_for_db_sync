CREATE TABLE [dbo].[packdetail]
(
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [LabelNo] nvarchar(20) NOT NULL,
    [LabelLine] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [RefNo] nvarchar(20) NULL DEFAULT (' '),
    [ArchiveCop] nvarchar(1) NULL,
    [ExpQty] int NULL DEFAULT ((0)),
    [UPC] nvarchar(30) NULL,
    [DropID] nvarchar(20) NOT NULL DEFAULT (' '),
    [RefNo2] nvarchar(30) NULL DEFAULT (' '),
    [LOTTABLEVALUE] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PKPackDetail] PRIMARY KEY ([PickSlipNo], [CartonNo], [LabelNo], [LabelLine]),
    CONSTRAINT [FK_PackDetail_PackHeader] FOREIGN KEY ([PickSlipNo]) REFERENCES [dbo].[PackHeader] ([PickSlipNo])
);
GO

CREATE INDEX [IX_PackDetail_DROPID] ON [dbo].[packdetail] ([DropID], [StorerKey]);
GO
CREATE INDEX [IX_PackDetail_LblNo_SKU] ON [dbo].[packdetail] ([LabelNo], [SKU]);
GO
CREATE INDEX [IX_PackDetail_Pickslipno_Storer_Sku] ON [dbo].[packdetail] ([StorerKey], [SKU], [PickSlipNo]);
GO
CREATE INDEX [IX_PackDetail_RefNo2] ON [dbo].[packdetail] ([RefNo2]);
GO
CREATE INDEX [IX_PackDetail_StorerKey_RefNo] ON [dbo].[packdetail] ([StorerKey], [RefNo]);
GO