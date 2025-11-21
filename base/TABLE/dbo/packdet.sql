CREATE TABLE [dbo].[packdet]
(
    [PackDetKey] nvarchar(50) NOT NULL,
    [PackKey] nvarchar(10) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL,
    [CaseQty] int NULL DEFAULT ((0)),
    [CaseWeight] float NULL DEFAULT ((0)),
    [CaseVolume] float NULL DEFAULT ((0)),
    [CaseLength] float NULL DEFAULT ((0)),
    [CaseWidth] float NULL DEFAULT ((0)),
    [CaseHeight] float NULL DEFAULT ((0)),
    [PalletQty] int NULL DEFAULT ((0)),
    [PalletWeight] float NULL DEFAULT ((0)),
    [PalletVolume] float NULL DEFAULT ((0)),
    [PalletLength] float NULL DEFAULT ((0)),
    [PalletWidth] float NULL DEFAULT ((0)),
    [PalletHeight] float NULL DEFAULT ((0)),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [UserDefine06] nvarchar(30) NULL DEFAULT (''),
    [UserDefine07] nvarchar(30) NULL DEFAULT (''),
    [UserDefine08] nvarchar(30) NULL DEFAULT (''),
    [UserDefine09] nvarchar(30) NULL DEFAULT (''),
    [UserDefine10] nvarchar(30) NULL DEFAULT (''),
    [UserDefine11] datetime NULL,
    [UserDefine12] datetime NULL,
    [UserDefine13] datetime NULL,
    [UserDefine14] datetime NULL,
    [UserDefine15] datetime NULL,
    [UserDefine16] datetime NULL,
    [UserDefine17] datetime NULL,
    [UserDefine18] datetime NULL,
    [UserDefine19] datetime NULL,
    [UserDefine20] datetime NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] varchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] varchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_PACKDet] PRIMARY KEY ([PackDetKey], [PackKey], [SKU], [StorerKey])
);
GO

CREATE INDEX [IDX_PackDet_PackKey] ON [dbo].[packdet] ([PackKey]);
GO
CREATE INDEX [IDX_PackDet_SKU] ON [dbo].[packdet] ([SKU], [StorerKey]);
GO