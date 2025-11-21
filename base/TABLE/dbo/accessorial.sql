CREATE TABLE [dbo].[accessorial]
(
    [Accessorialkey] nvarchar(10) NOT NULL,
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [SKU] nvarchar(20) NOT NULL DEFAULT (' '),
    [ServiceKey] nvarchar(10) NOT NULL DEFAULT ('XXXXXXXXXX'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    CONSTRAINT [PKAccessorial] PRIMARY KEY ([Accessorialkey]),
    CONSTRAINT [FKAccessorial] FOREIGN KEY ([ServiceKey]) REFERENCES [dbo].[Services] ([Servicekey]),
    CONSTRAINT [CK_ACCS_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
