CREATE TABLE [dbo].[help]
(
    [topic] nvarchar(64) NOT NULL DEFAULT (' '),
    [context] nvarchar(128) NOT NULL DEFAULT (' '),
    [langid] int NOT NULL DEFAULT (' '),
    [shorthelp] nvarchar(255) NOT NULL DEFAULT (' '),
    [extendedhelpurl] nvarchar(255) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKHelp] PRIMARY KEY ([topic], [context], [langid])
);
GO
