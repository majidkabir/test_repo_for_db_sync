CREATE TABLE [dbo].[billofmaterial]
(
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [ComponentSku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Sequence] nvarchar(10) NOT NULL DEFAULT (' '),
    [BomOnly] nvarchar(1) NOT NULL DEFAULT (' '),
    [Notes] nvarchar(4000) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL DEFAULT ((1)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ParentQty] int NOT NULL DEFAULT ((1)),
    [UDF01] nvarchar(20) NULL DEFAULT (''),
    [UDF02] nvarchar(20) NULL,
    [UDF03] nvarchar(20) NULL,
    [UDF04] nvarchar(20) NULL,
    [UDF05] nvarchar(20) NULL,
    CONSTRAINT [PKBillOfMaterial] PRIMARY KEY ([Storerkey], [Sku], [ComponentSku]),
    CONSTRAINT [FK_BillOfMaterial_SKU_01] FOREIGN KEY ([Storerkey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku])
);
GO

CREATE INDEX [IDX_BillOfMaterial_01] ON [dbo].[billofmaterial] ([Storerkey], [ComponentSku]);
GO
CREATE INDEX [IDX_BillofMaterial_UDF01] ON [dbo].[billofmaterial] ([UDF01], [Storerkey]);
GO