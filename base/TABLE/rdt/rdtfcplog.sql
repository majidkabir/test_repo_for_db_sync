CREATE TABLE [rdt].[rdtfcplog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [QTY] int NOT NULL,
    [DropID] nvarchar(18) NOT NULL,
    [UCCNo] nvarchar(20) NOT NULL,
    CONSTRAINT [PK_rdtFCPLog] PRIMARY KEY ([RowRef])
);
GO
