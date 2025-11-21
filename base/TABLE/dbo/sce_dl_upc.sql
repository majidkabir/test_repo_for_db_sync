CREATE TABLE [dbo].[sce_dl_upc]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [UPC] nvarchar(60) NULL,
    [Storerkey] nvarchar(30) NULL,
    [SKU] nvarchar(40) NULL,
    [UOM] nchar(10) NULL,
    [Packkey] nvarchar(20) NULL,
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [QTY] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_SCE_DL_UPC] PRIMARY KEY ([RowRefNo])
);
GO
