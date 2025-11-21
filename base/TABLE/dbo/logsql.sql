CREATE TABLE [dbo].[logsql]
(
    [SQLId] int IDENTITY(1,1) NOT NULL,
    [SQLDate] datetime NOT NULL DEFAULT (getdate()),
    [SQLDb] nvarchar(128) NOT NULL,
    [SQLSchema] nvarchar(128) NOT NULL,
    [SQLProc] nvarchar(128) NOT NULL,
    [SQLText] nvarchar(MAX) NOT NULL,
    [Duration] int NOT NULL,
    [RowCnt] int NOT NULL,
    [SourceKey] int NOT NULL,
    [SourceTable] nvarchar(128) NOT NULL,
    [SQLUser] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [SQLHost] nvarchar(128) NOT NULL DEFAULT (isnull(host_name(),'')),
    CONSTRAINT [PK_LogSQL] PRIMARY KEY ([SQLId])
);
GO

CREATE INDEX [IX_LogSQL] ON [dbo].[logsql] ([SourceTable], [SourceKey]);
GO