CREATE TABLE [dbo].[sce_dl_bom_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [ComponentSku] nvarchar(20) NULL,
    [Sequence] nvarchar(10) NULL,
    [BomOnly] nvarchar(1) NULL,
    [Notes] nvarchar(4000) NULL,
    [Qty] int NULL,
    [ParentQty] int NULL,
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [UDF01] nvarchar(20) NULL DEFAULT (''),
    [UDF02] nvarchar(20) NULL DEFAULT (''),
    [UDF03] nvarchar(20) NULL DEFAULT (''),
    [UDF04] nvarchar(20) NULL DEFAULT (''),
    [UDF05] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_SCE_DL_BOM_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_BOM_STG_Idx01] ON [dbo].[sce_dl_bom_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_BOM_STG_Idx02] ON [dbo].[sce_dl_bom_stg] ([STG_BatchNo], [STG_SeqNo]);
GO