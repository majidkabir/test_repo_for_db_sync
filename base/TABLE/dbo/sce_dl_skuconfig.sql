CREATE TABLE [dbo].[sce_dl_skuconfig]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [ConfigType] nvarchar(30) NULL,
    [Data] nvarchar(30) NULL,
    [userdefine01] nvarchar(50) NULL,
    [userdefine02] nvarchar(50) NULL,
    [userdefine03] nvarchar(50) NULL,
    [userdefine04] nvarchar(50) NULL,
    [userdefine05] nvarchar(50) NULL,
    [userdefine06] datetime NULL,
    [userdefine07] datetime NULL,
    [userdefine08] nvarchar(50) NULL,
    [userdefine09] nvarchar(50) NULL,
    [userdefine10] nvarchar(50) NULL,
    [userdefine11] nvarchar(50) NULL,
    [userdefine12] nvarchar(50) NULL,
    [userdefine13] nvarchar(50) NULL,
    [userdefine14] nvarchar(50) NULL,
    [userdefine15] nvarchar(50) NULL,
    [notes] nvarchar(4000) NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_SKUCONFIG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [IX_SCE_DL_SKUCONFIG_SKE] ON [dbo].[sce_dl_skuconfig] ([SKU], [StorerKey], [ConfigType]);
GO