CREATE TABLE [dbo].[sce_dl_orddetref_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Orderkey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(5) NULL,
    [StorerKey] nvarchar(15) NULL,
    [ParentSKU] nvarchar(20) NULL,
    [ComponentSKU] nvarchar(20) NULL,
    [RetailSKU] nvarchar(20) NULL,
    [Note1] nvarchar(1000) NULL,
    [BOMQty] int NULL,
    [RefType] nvarchar(10) NULL,
    [PackCnt] int NULL,
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_ORDDETREF_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_ORDDETREF_STG_Idx01] ON [dbo].[sce_dl_orddetref_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_ORDDETREF_STG_Idx02] ON [dbo].[sce_dl_orddetref_stg] ([STG_BatchNo], [STG_SeqNo]);
GO