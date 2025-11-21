CREATE TABLE [dbo].[gldistribution]
(
    [GLDistributionKey] nvarchar(10) NOT NULL,
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PKGLDistribution] PRIMARY KEY ([GLDistributionKey]),
    CONSTRAINT [CK_GLDistribution_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
