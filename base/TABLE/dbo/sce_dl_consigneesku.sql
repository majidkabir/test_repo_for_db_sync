CREATE TABLE [dbo].[sce_dl_consigneesku]
(
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [ConsigneeSKU] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ConsigneeSKUAddWho] nvarchar(128) NULL,
    [UOM] nvarchar(10) NULL,
    [Active] nvarchar(10) NULL,
    [CrossSKUQty] int NULL,
    [UDF01] nvarchar(60) NULL,
    [UDF02] nvarchar(60) NULL,
    [UDF03] nvarchar(60) NULL,
    [UDF04] nvarchar(60) NULL,
    [UDF05] nvarchar(60) NULL,
    CONSTRAINT [PK_SCE_DL_CONSIGNEESKU] PRIMARY KEY ([ConsigneeKey], [ConsigneeSKU])
);
GO

CREATE INDEX [IX_SCE_DL_ConsigneeSKU_StorerSKU] ON [dbo].[sce_dl_consigneesku] ([StorerKey], [SKU]);
GO