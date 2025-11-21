CREATE TABLE [dbo].[tmslog]
(
    [TMSLogKey] int IDENTITY(1,1) NOT NULL,
    [TableName] nvarchar(30) NOT NULL DEFAULT (' '),
    [key1] nvarchar(10) NOT NULL DEFAULT (' '),
    [key2] nvarchar(5) NOT NULL DEFAULT (' '),
    [key3] nvarchar(20) NOT NULL DEFAULT (' '),
    [TransmitFlag] nvarchar(5) NOT NULL DEFAULT ('0'),
    [TransmitBatch] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKTMSLog] PRIMARY KEY ([TMSLogKey])
);
GO

CREATE INDEX [IDX_TMSLOG_CIdx] ON [dbo].[tmslog] ([TableName], [key1], [key2], [key3]);
GO