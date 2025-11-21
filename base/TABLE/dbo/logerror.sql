CREATE TABLE [dbo].[logerror]
(
    [ErrId] int IDENTITY(1,1) NOT NULL,
    [ErrDate] datetime NOT NULL DEFAULT (getdate()),
    [ErrDb] nvarchar(128) NOT NULL,
    [ErrSchema] nvarchar(128) NOT NULL,
    [ErrProc] nvarchar(128) NOT NULL,
    [ErrLine] int NOT NULL,
    [ErrMsg] nvarchar(1024) NOT NULL,
    [ErrNo] int NOT NULL,
    [ErrSeverity] tinyint NOT NULL,
    [ErrState] tinyint NOT NULL,
    [Success] bit NOT NULL,
    [SourceKey] int NOT NULL,
    [SourceTable] nvarchar(128) NOT NULL,
    [ErrUser] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ErrHost] nvarchar(128) NOT NULL DEFAULT (isnull(host_name(),'')),
    CONSTRAINT [PK_LogError] PRIMARY KEY ([ErrId])
);
GO

CREATE INDEX [IX_LogError] ON [dbo].[logerror] ([SourceTable], [SourceKey]);
GO