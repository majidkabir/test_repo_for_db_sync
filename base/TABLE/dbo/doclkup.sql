CREATE TABLE [dbo].[doclkup]
(
    [ConsigneeGroup] nvarchar(20) NOT NULL,
    [SkuGroup] nvarchar(20) NOT NULL,
    [ShelfLife] int NULL DEFAULT ((0)),
    [DocumentType] nvarchar(10) NULL,
    [UserDefine01] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine02] nvarchar(20) NULL DEFAULT (' '),
    [UserDefine03] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine04] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine05] nvarchar(30) NULL DEFAULT (' '),
    [UserDefine06] nvarchar(50) NULL DEFAULT (' '),
    [UserDefine07] datetime NULL,
    [UserDefine08] datetime NULL,
    [UserDefine09] int NULL,
    [UserDefine10] float NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_DOCLKUP] PRIMARY KEY ([ConsigneeGroup], [SkuGroup])
);
GO
