CREATE TABLE [dbo].[transmitlog]
(
    [transmitlogkey] nvarchar(10) NOT NULL,
    [tablename] nvarchar(30) NOT NULL DEFAULT (' '),
    [key1] nvarchar(10) NOT NULL DEFAULT (' '),
    [key2] nvarchar(30) NOT NULL DEFAULT (' '),
    [key3] nvarchar(20) NOT NULL DEFAULT (' '),
    [transmitflag] nvarchar(5) NOT NULL DEFAULT ('0'),
    [transmitbatch] nvarchar(30) NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKTRANSMITLOG] PRIMARY KEY ([transmitlogkey])
);
GO

CREATE INDEX [IDX_TRANSMITLOG_CIdx] ON [dbo].[transmitlog] ([tablename], [key1], [key2], [key3]);
GO
CREATE INDEX [IDX_TRANSMITLOG_KEY1] ON [dbo].[transmitlog] ([key1], [key2]);
GO
CREATE INDEX [IDX_TRANSMITLOG_KEY3] ON [dbo].[transmitlog] ([key3]);
GO