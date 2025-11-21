CREATE TABLE [dbo].[errlog]
(
    [LogDate] datetime NOT NULL DEFAULT (getdate()),
    [UserId] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ErrorID] int NOT NULL,
    [SystemState] nvarchar(18) NULL,
    [Module] nvarchar(250) NULL,
    [ErrorText] nvarchar(4000) NOT NULL,
    [TrafficCop] nvarchar(1) NULL,
    [GUIDRef] uniqueidentifier NOT NULL DEFAULT (newid()),
    CONSTRAINT [PKerrlog] PRIMARY KEY ([GUIDRef])
);
GO

CREATE INDEX [IX_ERRLOG_Module] ON [dbo].[errlog] ([Module], [ErrorID]);
GO