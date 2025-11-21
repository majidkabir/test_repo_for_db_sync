CREATE TABLE [rdt].[nsqlconfig]
(
    [Function_ID] int NOT NULL DEFAULT ((0)),
    [ConfigKey] nvarchar(30) NOT NULL,
    [NSQLValue] nvarchar(30) NOT NULL DEFAULT (' '),
    [NSQLDefault] nvarchar(30) NOT NULL DEFAULT (' '),
    [NSQLDescrip] nvarchar(120) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    CONSTRAINT [PK_NSQLConfig] PRIMARY KEY ([Function_ID], [ConfigKey])
);
GO
