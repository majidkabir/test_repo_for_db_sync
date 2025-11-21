CREATE TABLE [dbo].[tcpsocket_queuetask_log]
(
    [ID] bigint NOT NULL,
    [CmdType] nvarchar(10) NULL DEFAULT (''),
    [Cmd] nvarchar(1024) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [ThreadPerAcct] int NULL DEFAULT ((0)),
    [ThreadPerStream] int NULL DEFAULT ((0)),
    [MilisecondDelay] int NULL DEFAULT ((0)),
    [DataStream] nvarchar(10) NULL DEFAULT (''),
    [TransmitLogKey] nvarchar(10) NULL DEFAULT (''),
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [ThreadId] nvarchar(20) NULL DEFAULT (''),
    [ThreadStartTime] datetime NULL,
    [ThreadEndTime] datetime NULL,
    [ErrMsg] nvarchar(1000) NULL DEFAULT (''),
    [Try] tinyint NULL,
    [SEQ] int NULL DEFAULT ((1)),
    [Port] nvarchar(5) NULL DEFAULT (''),
    [TargetDB] nvarchar(30) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [IP] nvarchar(30) NULL DEFAULT (''),
    [MsgRecvDate] datetime NULL,
    [Priority] int NOT NULL DEFAULT ('0'),
    [HashValue] tinyint NOT NULL DEFAULT (abs(checksum(newid())%(256))),
    CONSTRAINT [PK_TCPSocket_QueueTask_LOG] PRIMARY KEY ([ID])
);
GO

CREATE INDEX [IDX_TCPSocket_QueueTask_TransmitlogKey_Log] ON [dbo].[tcpsocket_queuetask_log] ([DataStream], [TransmitLogKey], [StorerKey], [Status]);
GO
CREATE INDEX [IX_TcpSocket_QueueTask_Log_01] ON [dbo].[tcpsocket_queuetask_log] ([DataStream], [StorerKey], [CmdType]);
GO
CREATE UNIQUE INDEX [IX_TCPSocket_QueueTask_LOG_HASHVALUE] ON [dbo].[tcpsocket_queuetask_log] ([HashValue], [ID]);
GO