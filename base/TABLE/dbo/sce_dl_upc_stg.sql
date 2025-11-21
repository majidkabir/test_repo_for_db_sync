CREATE TABLE [dbo].[sce_dl_upc_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [UPC] nvarchar(60) NULL,
    [Storerkey] nvarchar(30) NULL,
    [SKU] nvarchar(40) NULL,
    [UOM] nchar(10) NULL,
    [Packkey] nvarchar(20) NULL,
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [QTY] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_SCE_DL_UPC_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_UPC_STG_Idx01] ON [dbo].[sce_dl_upc_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_UPC_STG_Idx02] ON [dbo].[sce_dl_upc_stg] ([STG_BatchNo], [STG_SeqNo]);
GO