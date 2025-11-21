CREATE TABLE [dbo].[skuimage]
(
    [SkuImageKey] bigint IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(20) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [ImageFolder] nvarchar(200) NOT NULL DEFAULT (''),
    [ImageFile] nvarchar(50) NOT NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_SkuImage] PRIMARY KEY ([SkuImageKey])
);
GO

CREATE INDEX [IDX_SkuImage_ImageFile] ON [dbo].[skuimage] ([Storerkey], [Sku], [ImageFile]);
GO