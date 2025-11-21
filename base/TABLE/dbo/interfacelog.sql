CREATE TABLE [dbo].[interfacelog]
(
    [InterfaceKey] nvarchar(10) NOT NULL,
    [SourceKey] nvarchar(10) NULL,
    [StorerKey] nvarchar(15) NULL,
    [ExternSourceKey] nvarchar(10) NULL,
    [Tablename] nvarchar(30) NULL,
    [Sku] nvarchar(20) NULL,
    [Qty] int NULL,
    [UOM] nvarchar(10) NULL,
    [UserID] nvarchar(128) NULL,
    [TranCode] nvarchar(10) NULL,
    [TranStatus] nvarchar(10) NULL,
    [TranDate] datetime NULL,
    [Userdefine01] nvarchar(30) NULL,
    [Userdefine02] nvarchar(30) NULL,
    [Userdefine03] nvarchar(30) NULL,
    [Userdefine04] nvarchar(30) NULL,
    [Userdefine05] nvarchar(30) NULL,
    [Userdefine06] nvarchar(30) NULL,
    [Userdefine07] nvarchar(30) NULL,
    [Userdefine08] nvarchar(30) NULL,
    [Userdefine09] nvarchar(30) NULL,
    [Userdefine10] nvarchar(30) NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [Msgtext] nvarchar(100) NULL,
    CONSTRAINT [PK_InterfaceLog] PRIMARY KEY ([InterfaceKey])
);
GO

CREATE INDEX [IX_INTERFACELOG_SKU] ON [dbo].[interfacelog] ([StorerKey], [Sku]);
GO
CREATE INDEX [IX_INTERFACELOG_TranCode] ON [dbo].[interfacelog] ([TranCode]);
GO