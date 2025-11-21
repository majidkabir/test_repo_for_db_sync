CREATE TABLE [dbo].[storerconfig]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (' '),
    [ConfigKey] nvarchar(30) NOT NULL,
    [ConfigDesc] nvarchar(120) NULL DEFAULT (' '),
    [SValue] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [OPTION1] nvarchar(50) NULL DEFAULT (''),
    [OPTION2] nvarchar(50) NULL DEFAULT (''),
    [OPTION3] nvarchar(50) NULL DEFAULT (''),
    [OPTION4] nvarchar(50) NULL DEFAULT (''),
    [OPTION5] nvarchar(4000) NULL DEFAULT (''),
    CONSTRAINT [PK_StorerConfig] PRIMARY KEY ([StorerKey], [ConfigKey], [Facility])
);
GO

CREATE INDEX [IDX_STORERCONFIG_Config] ON [dbo].[storerconfig] ([StorerKey], [ConfigKey], [SValue]);
GO