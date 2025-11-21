CREATE TABLE [dbo].[sce_dl_skuinfo_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Storerkey] nvarchar(15) NULL DEFAULT (''),
    [Sku] nvarchar(20) NULL DEFAULT (''),
    [ExtendedField01] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField02] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField03] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField04] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField05] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField06] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField07] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField08] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField09] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField10] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField11] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField12] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField13] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField14] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField15] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField16] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField17] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField18] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField19] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField20] nvarchar(30) NULL DEFAULT (''),
    [ExtendedField21] nvarchar(4000) NULL DEFAULT (''),
    [ExtendedField22] nvarchar(4000) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_SKUINFO_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_SKUINFO_STG_Idx01] ON [dbo].[sce_dl_skuinfo_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_SKUINFO_STG_Idx02] ON [dbo].[sce_dl_skuinfo_stg] ([STG_BatchNo], [STG_SeqNo]);
GO