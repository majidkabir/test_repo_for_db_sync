CREATE TABLE [dbo].[tcpsocket_inlog]
(
    [SerialNo] int IDENTITY(1,1) NOT NULL,
    [Application] nvarchar(50) NULL DEFAULT (''),
    [LocalEndPoint] nvarchar(50) NULL DEFAULT (''),
    [RemoteEndPoint] nvarchar(50) NULL DEFAULT (''),
    [MessageType] nvarchar(10) NULL DEFAULT (''),
    [Data] nvarchar(MAX) NULL DEFAULT (''),
    [MessageNum] nvarchar(10) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL,
    [StartTime] datetime NULL,
    [EndTime] datetime NULL,
    [ErrMsg] nvarchar(400) NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [NoOfTry] int NOT NULL DEFAULT ((0)),
    [EmailSent] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(215) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(215) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ACKData] nvarchar(MAX) NULL DEFAULT (''),
    CONSTRAINT [PK_TCPSocket_INLog] PRIMARY KEY ([SerialNo])
);
GO

CREATE INDEX [IX_TCPSocket_INLog_MessageNum] ON [dbo].[tcpsocket_inlog] ([MessageNum]);
GO