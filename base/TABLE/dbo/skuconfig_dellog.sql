CREATE TABLE [dbo].[skuconfig_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [ConfigType] nvarchar(30) NOT NULL,
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] varchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] char(1) NULL,
    CONSTRAINT [PK_skuconfig_dellog] PRIMARY KEY ([Rowref])
);
GO
