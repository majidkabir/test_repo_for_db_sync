CREATE TABLE [dbo].[wmsfieldslist]
(
    [ProcessID] nvarchar(30) NOT NULL DEFAULT (' '),
    [FieldID] int NOT NULL,
    [ColID] int NOT NULL,
    [ColName] nvarchar(60) NOT NULL DEFAULT (' '),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_WMSFieldsList] PRIMARY KEY ([ProcessID], [FieldID])
);
GO

CREATE INDEX [Seq_ind] ON [dbo].[wmsfieldslist] ([ProcessID], [ColName]);
GO