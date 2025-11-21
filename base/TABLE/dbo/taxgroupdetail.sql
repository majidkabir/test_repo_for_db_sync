CREATE TABLE [dbo].[taxgroupdetail]
(
    [TaxGroupKey] nvarchar(10) NOT NULL,
    [TaxRateKey] nvarchar(10) NOT NULL,
    [GLDistributionKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKTaxGroupDetail] PRIMARY KEY ([TaxGroupKey], [TaxRateKey]),
    CONSTRAINT [FK_TaxGroupDetail_GLDist_01] FOREIGN KEY ([GLDistributionKey]) REFERENCES [dbo].[GLDistribution] ([GLDistributionKey]),
    CONSTRAINT [FKTaxGroupDetail] FOREIGN KEY ([TaxRateKey]) REFERENCES [dbo].[TaxRate] ([TaxRateKey]),
    CONSTRAINT [FKTaxGroupDetail_TxGrpKey_01] FOREIGN KEY ([TaxGroupKey]) REFERENCES [dbo].[TaxGroup] ([TaxGroupKey])
);
GO
