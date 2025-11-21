CREATE TABLE [dbo].[itemclass]
(
    [ItemClassKey] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ItemClass] nvarchar(30) NOT NULL,
    [TempCheckIndicator] nvarchar(2) NULL,
    [MaxTemp] decimal(13, 2) NULL,
    [MinTemp] decimal(13, 2) NULL,
    [TemperatureScale] nvarchar(30) NULL,
    [CertificateRequired] nvarchar(1) NULL,
    [FolderPath] nvarchar(128) NULL,
    [AddDate] datetime NULL,
    [AddWho] nvarchar(128) NULL,
    [EditDate] datetime NULL,
    [EditWho] nvarchar(128) NULL,
    [MarkForDelete] nvarchar(1) NULL,
    CONSTRAINT [PK_itemclass] PRIMARY KEY ([ItemClassKey]),
    CONSTRAINT [UC_StorerKey_ItemClass] UNIQUE ([StorerKey], [ItemClass])
);
GO

CREATE INDEX [IX_ItemClass_ItemClass] ON [dbo].[itemclass] ([ItemClass]);
GO
CREATE INDEX [IX_ItemClass_StorerKey] ON [dbo].[itemclass] ([StorerKey]);
GO