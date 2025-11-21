CREATE TABLE [dbo].[skuconfig]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [ConfigType] nvarchar(30) NOT NULL,
    [Data] nvarchar(30) NOT NULL DEFAULT (' '),
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [userdefine01] nvarchar(50) NULL DEFAULT (''),
    [userdefine02] nvarchar(50) NULL DEFAULT (''),
    [userdefine03] nvarchar(50) NULL DEFAULT (''),
    [userdefine04] nvarchar(50) NULL DEFAULT (''),
    [userdefine05] nvarchar(50) NULL DEFAULT (''),
    [userdefine06] datetime NULL,
    [userdefine07] datetime NULL,
    [userdefine08] nvarchar(100) NULL DEFAULT (''),
    [userdefine09] nvarchar(100) NULL DEFAULT (''),
    [userdefine10] nvarchar(100) NULL DEFAULT (''),
    [userdefine11] nvarchar(50) NULL DEFAULT (''),
    [userdefine12] nvarchar(50) NULL DEFAULT (''),
    [userdefine13] nvarchar(50) NULL DEFAULT (''),
    [userdefine14] nvarchar(50) NULL DEFAULT (''),
    [userdefine15] nvarchar(50) NULL DEFAULT (''),
    [notes] nvarchar(4000) NULL,
    CONSTRAINT [PK_SKUConfig] PRIMARY KEY ([StorerKey], [SKU], [ConfigType])
);
GO
