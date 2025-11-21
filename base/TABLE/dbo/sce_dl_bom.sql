CREATE TABLE [dbo].[sce_dl_bom]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [ComponentSku] nvarchar(20) NULL,
    [Sequence] nvarchar(10) NULL,
    [BomOnly] nvarchar(1) NULL,
    [Notes] nvarchar(4000) NULL,
    [Qty] int NULL,
    [ParentQty] int NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [UDF01] nvarchar(20) NULL DEFAULT (''),
    [UDF02] nvarchar(20) NULL DEFAULT (''),
    [UDF03] nvarchar(20) NULL DEFAULT (''),
    [UDF04] nvarchar(20) NULL DEFAULT (''),
    [UDF05] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_SCE_DL_BOM] PRIMARY KEY ([RowRefNo])
);
GO
