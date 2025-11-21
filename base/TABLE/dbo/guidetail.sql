CREATE TABLE [dbo].[guidetail]
(
    [InvoiceNo] nvarchar(10) NOT NULL,
    [ExternOrderkey] nvarchar(50) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [LineNumber] nvarchar(6) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [UnitPrice] money NOT NULL DEFAULT ((0)),
    [Amount] money NOT NULL DEFAULT ((0)),
    [DiscAmount] money NOT NULL DEFAULT ((0)),
    [SKUDesc] nvarchar(60) NULL DEFAULT (' '),
    [UOM] nvarchar(5) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Remarks] nvarchar(20) NULL DEFAULT (' '),
    [IndicatorFlag] nvarchar(1) NULL,
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [UserDefine01] nvarchar(80) NULL,
    [UserDefine02] nvarchar(80) NULL,
    [UserDefine03] nvarchar(80) NULL,
    [UserDefine04] nvarchar(80) NULL,
    [UserDefine05] nvarchar(80) NULL,
    [UserDefine06] nvarchar(80) NULL,
    [UserDefine07] nvarchar(80) NULL,
    [UserDefine08] nvarchar(80) NULL,
    [UserDefine09] nvarchar(80) NULL,
    [UserDefine10] nvarchar(80) NULL,
    CONSTRAINT [PK_GUIDetail] PRIMARY KEY ([InvoiceNo], [ExternOrderkey], [Storerkey], [LineNumber])
);
GO

CREATE INDEX [IX_GUIDetail_ExternOrderkey] ON [dbo].[guidetail] ([ExternOrderkey], [Storerkey]);
GO