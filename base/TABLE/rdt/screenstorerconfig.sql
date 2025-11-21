CREATE TABLE [rdt].[screenstorerconfig]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Scn] int NOT NULL DEFAULT ((0)),
    [line] int NOT NULL DEFAULT ((0)),
    [Function_ID] int NOT NULL DEFAULT ((0)),
    [Attribute] nvarchar(30) NULL DEFAULT (' '),
    [SValue] nvarchar(MAX) NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname())
);
GO
