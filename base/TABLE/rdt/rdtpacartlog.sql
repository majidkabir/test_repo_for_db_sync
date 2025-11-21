CREATE TABLE [rdt].[rdtpacartlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [CartID] nvarchar(10) NOT NULL,
    [ToteID] nvarchar(20) NOT NULL,
    [Position] nvarchar(10) NOT NULL,
    [Col] nvarchar(2) NOT NULL,
    [Row] nvarchar(2) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPACartLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPACartLog_CartID_ToteID_Position] ON [rdt].[rdtpacartlog] ([CartID], [ToteID], [Position]);
GO