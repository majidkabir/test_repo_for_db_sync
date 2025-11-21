CREATE TABLE [dbo].[packconfig]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [ExternPOKey] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [PackKey] nvarchar(10) NOT NULL,
    [UOM1Barcode] nvarchar(30) NULL DEFAULT (' '),
    [UOM2Barcode] nvarchar(30) NULL DEFAULT (' '),
    [UOM3Barcode] nvarchar(30) NULL DEFAULT (' '),
    [UOM4Barcode] nvarchar(30) NULL DEFAULT (' '),
    [BatchNo] nvarchar(30) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_PackConfig] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_PackConfig_SKU] ON [dbo].[packconfig] ([Storerkey], [SKU]);
GO
CREATE INDEX [IX_PackConfig_UOM1Barcode] ON [dbo].[packconfig] ([Storerkey], [ExternPOKey], [UOM1Barcode]);
GO
CREATE INDEX [IX_PackConfig_UOM2Barcode] ON [dbo].[packconfig] ([Storerkey], [ExternPOKey], [UOM2Barcode]);
GO
CREATE INDEX [IX_PackConfig_UOM3Barcode] ON [dbo].[packconfig] ([Storerkey], [ExternPOKey], [UOM3Barcode]);
GO
CREATE INDEX [IX_PackConfig_UOM4Barcode] ON [dbo].[packconfig] ([Storerkey], [ExternPOKey], [UOM4Barcode]);
GO