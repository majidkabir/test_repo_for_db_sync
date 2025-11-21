CREATE TABLE [dbo].[packqrf]
(
    [PackQRFKey] bigint IDENTITY(1,1) NOT NULL,
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [CartonNo] int NOT NULL DEFAULT ((0)),
    [LabelLine] nvarchar(5) NOT NULL DEFAULT (''),
    [QRCode] nvarchar(100) NOT NULL DEFAULT (''),
    [RFIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [TIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [QRFGroupKey] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_PackQRF] PRIMARY KEY ([PackQRFKey])
);
GO

CREATE INDEX [IDX_PackQRF_PackCartonLine] ON [dbo].[packqrf] ([PickSlipNo], [CartonNo], [LabelLine]);
GO
CREATE INDEX [IDX_PackQRF_QRCode] ON [dbo].[packqrf] ([QRCode]);
GO
CREATE INDEX [IDX_PackQRF_QRFGroupKey] ON [dbo].[packqrf] ([PickSlipNo], [CartonNo], [LabelLine], [QRFGroupKey]);
GO
CREATE INDEX [IDX_PackQRF_RFIDNo_TIDNo] ON [dbo].[packqrf] ([RFIDNo], [TIDNo]);
GO