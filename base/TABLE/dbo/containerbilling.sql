CREATE TABLE [dbo].[containerbilling]
(
    [ContainerBillingKey] nvarchar(10) NOT NULL,
    [DocType] nvarchar(10) NOT NULL DEFAULT ('ASN'),
    [ContainerType] nvarchar(20) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [Rate] decimal(12, 6) NOT NULL,
    [Base] nvarchar(1) NOT NULL DEFAULT ('Q'),
    [TaxGroupKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [GLDistributionKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [CostRate] decimal(12, 6) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKContainerBilling] PRIMARY KEY ([ContainerBillingKey]),
    CONSTRAINT [CK_ContBill_Base] CHECK ([Base]='R' OR [Base]='P' OR [Base]='F' OR [Base]='C' OR [Base]='G' OR [Base]='Q'),
    CONSTRAINT [CK_ContBill_DocType] CHECK ([DocType]='CNT' OR [DocType]='SO' OR [DocType]='ASN')
);
GO
