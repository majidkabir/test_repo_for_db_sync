CREATE TABLE [dbo].[tcpsocket_outlog]
(
    [SerialNo] int IDENTITY(1,1) NOT NULL,
    [Application] nvarchar(50) NULL,
    [LocalEndPoint] nvarchar(50) NULL,
    [RemoteEndPoint] nvarchar(50) NULL,
    [MessageType] nvarchar(10) NULL,
    [Data] nvarchar(4000) NULL,
    [MessageNum] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [BatchNo] nvarchar(50) NULL,
    [LabelNo] nvarchar(20) NULL,
    [RefNo] nvarchar(20) NULL,
    [ErrMsg] nvarchar(400) NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [NoOfTry] int NOT NULL DEFAULT ((0)),
    [EmailSent] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(215) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(215) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [ACKData] nvarchar(MAX) NULL,
    [GUIDRef] uniqueidentifier NOT NULL DEFAULT (newid()),
    [HashValue] tinyint NOT NULL DEFAULT (abs(checksum(newid())%(256))),
    CONSTRAINT [PK_TCPSOCKET_OUTLOG] PRIMARY KEY ([GUIDRef])
);
GO

CREATE INDEX [IX_TCPSocket_OUTLog_MsgNo] ON [dbo].[tcpsocket_outlog] ([MessageNum]);
GO
CREATE UNIQUE INDEX [IX_TCPSOCKET_OUTLOG_HASHVALUE] ON [dbo].[tcpsocket_outlog] ([HashValue], [SerialNo]);
GO
CREATE UNIQUE INDEX [IX_TCPSocket_OUTLog_PK] ON [dbo].[tcpsocket_outlog] ([SerialNo]);
GO