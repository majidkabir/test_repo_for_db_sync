CREATE TABLE [rdt].[rdtmvflog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [QTY] int NOT NULL,
    [DropID] nvarchar(18) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    CONSTRAINT [PK_rdtMVFLog] PRIMARY KEY ([RowRef])
);
GO
