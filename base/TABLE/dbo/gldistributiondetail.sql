CREATE TABLE [dbo].[gldistributiondetail]
(
    [GLDistributionKey] nvarchar(10) NOT NULL,
    [GLDistributionLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [ChartofAccountsKey] nvarchar(30) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [GLDistributionPct] decimal(12, 6) NOT NULL DEFAULT ((0.0)),
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PKGLDistributionDetail] PRIMARY KEY ([GLDistributionKey], [GLDistributionLineNumber]),
    CONSTRAINT [FK_GLDistDet_COAKey_01] FOREIGN KEY ([ChartofAccountsKey]) REFERENCES [dbo].[ChartOfAccounts] ([ChartofAccountsKey]),
    CONSTRAINT [FKGLDistDet] FOREIGN KEY ([GLDistributionKey]) REFERENCES [dbo].[GLDistribution] ([GLDistributionKey])
);
GO
