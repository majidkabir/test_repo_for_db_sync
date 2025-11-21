CREATE TABLE [dbo].[sce_dl_orddetref]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
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
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_ORDDETREF] PRIMARY KEY ([RowRefNo])
);
GO
