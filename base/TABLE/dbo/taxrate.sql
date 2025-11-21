CREATE TABLE [dbo].[taxrate]
(
    [TaxRateKey] nvarchar(10) NOT NULL,
    [TaxAuthority] nvarchar(30) NOT NULL DEFAULT (' '),
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [Rate] decimal(8, 7) NOT NULL DEFAULT ((0.0)),
    [ExternTaxRateKey] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKTAXRATE] PRIMARY KEY ([TaxRateKey]),
    CONSTRAINT [CK_TaxRate_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
