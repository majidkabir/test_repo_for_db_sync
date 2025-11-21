CREATE TABLE [rdt].[rdtrpflog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [QTY] int NOT NULL,
    [DropID] nvarchar(20) NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtRPFLog] PRIMARY KEY ([RowRef])
);
GO
