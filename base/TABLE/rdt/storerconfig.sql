CREATE TABLE [rdt].[storerconfig]
(
    [Function_ID] int NOT NULL DEFAULT ((0)),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [ConfigKey] nvarchar(30) NOT NULL,
    [ConfigDesc] nvarchar(120) NULL DEFAULT (' '),
    [SValue] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_StorerConfig] PRIMARY KEY ([Function_ID], [StorerKey], [ConfigKey], [Facility])
);
GO
