CREATE TABLE [dbo].[taxgroup]
(
    [TaxGroupKey] nvarchar(10) NOT NULL,
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKTAXGROUP] PRIMARY KEY ([TaxGroupKey]),
    CONSTRAINT [CK_TaxGroup_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
