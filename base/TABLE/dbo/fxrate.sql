CREATE TABLE [dbo].[fxrate]
(
    [CurrencyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [BaseCurrency] nvarchar(10) NOT NULL DEFAULT ('USD'),
    [TargetCurrency] nvarchar(10) NULL DEFAULT ('USD'),
    [ConversionRate] decimal(8, 4) NOT NULL DEFAULT ((1.0)),
    [FxDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKFxRATE] PRIMARY KEY ([CurrencyKey])
);
GO
