CREATE TABLE [dbo].[packserialno]
(
    [PackSerialNoKey] bigint IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [LabelNo] nvarchar(20) NOT NULL,
    [LabelLine] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [SerialNo] nvarchar(50) NULL,
    [QTY] int NOT NULL,
    [PickDetailKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Barcode] nvarchar(500) NULL,
    CONSTRAINT [PK_PackSerialNo] PRIMARY KEY ([PackSerialNoKey])
);
GO

CREATE INDEX [IDX_PACKSERIALNO_SERIALNO] ON [dbo].[packserialno] ([SerialNo], [StorerKey]);
GO
CREATE INDEX [IX_PACKSERIALNO_PickDetailkey] ON [dbo].[packserialno] ([PickDetailKey]);
GO
CREATE INDEX [IX_PackSerialNo_PickSlipNo_CartonNo_LabelNo_LabelLine] ON [dbo].[packserialno] ([PickSlipNo], [CartonNo], [LabelNo], [LabelLine]);
GO