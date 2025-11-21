CREATE TABLE [dbo].[btb_fta]
(
    [BTB_FTAKey] nvarchar(10) NOT NULL,
    [FormNo] nvarchar(40) NOT NULL DEFAULT (''),
    [FormType] nvarchar(10) NOT NULL DEFAULT (''),
    [CustomerCode] nvarchar(20) NOT NULL DEFAULT (''),
    [HSCode] nvarchar(20) NOT NULL DEFAULT (''),
    [COO] nvarchar(20) NOT NULL DEFAULT (''),
    [PermitNo] nvarchar(20) NOT NULL DEFAULT (''),
    [IssuedDate] datetime NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [SkuDescr] nvarchar(60) NOT NULL DEFAULT (''),
    [UOM] nvarchar(20) NOT NULL DEFAULT (''),
    [QtyImported] int NOT NULL DEFAULT ((0)),
    [QtyExported] int NOT NULL DEFAULT ((0)),
    [OriginCriterion] nvarchar(20) NULL,
    [EnabledFlag] nvarchar(1) NOT NULL DEFAULT ('Y'),
    [UserDefine01] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine06] datetime NULL,
    [UserDefine07] datetime NULL,
    [UserDefine08] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine09] nvarchar(30) NOT NULL DEFAULT (''),
    [UserDefine10] nvarchar(30) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [IssueCountry] nvarchar(30) NULL DEFAULT (''),
    [IssueAuthority] nvarchar(100) NULL DEFAULT (''),
    [BTBShipItem] nvarchar(50) NOT NULL DEFAULT (''),
    [CustomLotNo] nvarchar(20) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_btb_fta] PRIMARY KEY ([BTB_FTAKey])
);
GO

CREATE UNIQUE INDEX [BTB_FTA_IDX_BTB_FTA] ON [dbo].[btb_fta] ([FormType], [HSCode], [Storerkey], [Sku], [BTBShipItem], [COO], [FormNo], [CustomLotNo]);
GO