CREATE TABLE [dbo].[consigneesku]
(
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [ConsigneeSKU] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [UOM] nvarchar(10) NOT NULL DEFAULT ('EA'),
    [Active] nvarchar(10) NOT NULL DEFAULT ('Y'),
    [CrossSKUQty] int NOT NULL DEFAULT ((0)),
    [UDF01] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF02] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF03] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF04] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF05] nvarchar(60) NOT NULL DEFAULT (' '),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_ConsigneeSKU] PRIMARY KEY ([ConsigneeKey], [ConsigneeSKU])
);
GO

CREATE INDEX [IX_ConsigneeSKU_StorerSKU] ON [dbo].[consigneesku] ([StorerKey], [SKU]);
GO