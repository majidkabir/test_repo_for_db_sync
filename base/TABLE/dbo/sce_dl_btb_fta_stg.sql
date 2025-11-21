CREATE TABLE [dbo].[sce_dl_btb_fta_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [FormNo] nvarchar(40) NULL DEFAULT (''),
    [FormType] nvarchar(10) NULL DEFAULT (''),
    [CustomerCode] nvarchar(20) NULL DEFAULT (''),
    [HSCode] nvarchar(20) NULL DEFAULT (''),
    [COO] nvarchar(20) NULL DEFAULT (''),
    [PermitNo] nvarchar(20) NULL DEFAULT (''),
    [IssuedDate] datetime NULL,
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [Sku] nvarchar(20) NULL DEFAULT (''),
    [SkuDescr] nvarchar(60) NULL DEFAULT (''),
    [UOM] nvarchar(20) NULL DEFAULT (''),
    [QtyImported] int NULL DEFAULT ((0)),
    [QtyExported] int NULL DEFAULT ((0)),
    [OriginCriterion] nvarchar(20) NULL,
    [EnabledFlag] nvarchar(1) NULL DEFAULT ('Y'),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [UserDefine06] datetime NULL,
    [UserDefine07] datetime NULL,
    [UserDefine08] nvarchar(30) NULL DEFAULT (''),
    [UserDefine09] nvarchar(30) NULL DEFAULT (''),
    [UserDefine10] nvarchar(30) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [IssueCountry] nvarchar(30) NULL DEFAULT (''),
    [IssueAuthority] nvarchar(100) NULL DEFAULT (''),
    [BTBShipItem] nvarchar(50) NULL DEFAULT (''),
    [CustomLotNo] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_SCE_DL_BTB_FTA_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_BTB_FTA_STG_Idx01] ON [dbo].[sce_dl_btb_fta_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_BTB_FTA_STG_Idx02] ON [dbo].[sce_dl_btb_fta_stg] ([STG_BatchNo], [STG_SeqNo]);
GO