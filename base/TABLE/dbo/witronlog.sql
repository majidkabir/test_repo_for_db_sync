CREATE TABLE [dbo].[witronlog]
(
    [WitronLogKey] int IDENTITY(1,1) NOT NULL,
    [Tablename] nvarchar(30) NOT NULL DEFAULT (' '),
    [Key1] nvarchar(10) NOT NULL DEFAULT (' '),
    [Key2] nvarchar(5) NOT NULL DEFAULT (' '),
    [Key3] nvarchar(20) NOT NULL DEFAULT (' '),
    [TransmitFlag] nvarchar(5) NOT NULL DEFAULT ('0'),
    [TransmitBatch] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKWITRONLOG] PRIMARY KEY ([WitronLogKey])
);
GO

CREATE INDEX [IDX_WITRONLOG_CIdx] ON [dbo].[witronlog] ([Tablename], [Key1], [Key2], [Key3]);
GO