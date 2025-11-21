CREATE TABLE [dbo].[websocket_outlog]
(
    [SerialNo] int IDENTITY(1,1) NOT NULL,
    [Application] nvarchar(50) NULL,
    [LocalEndPoint] nvarchar(50) NULL,
    [RemoteEndPoint] nvarchar(50) NULL,
    [MessageType] nvarchar(10) NULL,
    [Data] nvarchar(MAX) NULL,
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
    CONSTRAINT [PK_WebSocket_OUTLog] PRIMARY KEY ([GUIDRef])
);
GO
