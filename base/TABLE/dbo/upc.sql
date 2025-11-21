CREATE TABLE [dbo].[upc]
(
    [UPC] nvarchar(30) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [PackKey] nvarchar(10) NOT NULL,
    [UOM] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [Qty] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_UPC] PRIMARY KEY ([StorerKey], [SKU], [UPC]),
    CONSTRAINT [FK_UPC_SKU_01] FOREIGN KEY ([StorerKey], [SKU]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku])
);
GO

CREATE INDEX [IDX_UPC01] ON [dbo].[upc] ([UPC], [StorerKey]);
GO