CREATE TABLE [dbo].[sce_dl_skuconfig_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
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
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [ConfigType] nvarchar(30) NULL,
    [Data] nvarchar(30) NULL,
    CONSTRAINT [PK_SCE_DL_SKUCONFIG_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_SKUCONFIG_STG_Idx01] ON [dbo].[sce_dl_skuconfig_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_SKUCONFIG_STG_Idx02] ON [dbo].[sce_dl_skuconfig_stg] ([STG_BatchNo], [STG_SeqNo]);
GO