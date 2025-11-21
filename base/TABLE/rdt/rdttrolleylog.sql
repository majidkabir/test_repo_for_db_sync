CREATE TABLE [rdt].[rdttrolleylog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TrolleyNo] nvarchar(10) NOT NULL DEFAULT (''),
    [Position] nvarchar(10) NOT NULL DEFAULT (''),
    [UCCNo] nvarchar(20) NOT NULL DEFAULT (''),
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtTrolleyLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtTrolleyLog_TrolleyNo_UCCNo] ON [rdt].[rdttrolleylog] ([TrolleyNo], [UCCNo]);
GO