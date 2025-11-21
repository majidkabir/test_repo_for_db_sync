CREATE TABLE [dbo].[chartofaccounts]
(
    [ChartofAccountsKey] nvarchar(30) NOT NULL,
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PKChartOfAccounts] PRIMARY KEY ([ChartofAccountsKey]),
    CONSTRAINT [CK_ChartOfAccts_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
