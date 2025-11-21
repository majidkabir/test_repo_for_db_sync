CREATE TABLE [dbo].[services]
(
    [Servicekey] nvarchar(10) NOT NULL,
    [Descrip] nvarchar(30) NOT NULL DEFAULT (' '),
    [SupportFlag] nvarchar(1) NOT NULL DEFAULT ('A'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    CONSTRAINT [PKService] PRIMARY KEY ([Servicekey]),
    CONSTRAINT [CK_SERV_SupportFlag] CHECK ([SupportFLag]='D' OR [SupportFLag]='I' OR [SupportFLag]='A')
);
GO
