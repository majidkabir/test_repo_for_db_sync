CREATE TABLE [dbo].[tntlog]
(
    [TNTLogKey] int IDENTITY(1,1) NOT NULL,
    [Tablename] nvarchar(30) NOT NULL DEFAULT (' '),
    [Key1] nvarchar(10) NOT NULL DEFAULT (' '),
    [Key2] nvarchar(5) NOT NULL DEFAULT (' '),
    [Key3] nvarchar(20) NOT NULL DEFAULT (' '),
    [TransmitFlag] nvarchar(5) NOT NULL DEFAULT ('0'),
    [TransmitBatch] nvarchar(30) NULL DEFAULT (' '),
    [TargetDB] nvarchar(30) NOT NULL DEFAULT (' '),
    [TargetDBSchema] nvarchar(20) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKTNTLog] PRIMARY KEY ([TNTLogKey])
);
GO

CREATE INDEX [IDX_TNTLog_CIdx] ON [dbo].[tntlog] ([Tablename], [Key1], [Key2], [Key3]);
GO
CREATE INDEX [IDX_TNTLog_Tablename] ON [dbo].[tntlog] ([Tablename], [TransmitFlag], [TNTLogKey]);
GO