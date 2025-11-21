CREATE TABLE [rdt].[rdttaskmanagerconfig]
(
    [TaskType] nvarchar(10) NOT NULL DEFAULT (''),
    [TaskDesc] nvarchar(120) NULL DEFAULT (' '),
    [Function_ID] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Step] int NOT NULL DEFAULT ((1)),
    CONSTRAINT [PK_rdtTaskManagerConfig] PRIMARY KEY ([TaskType])
);
GO
