CREATE TABLE [dbo].[transmitlog3]
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
    CONSTRAINT [PKTRANSMITLOG3] PRIMARY KEY ([transmitlogkey])
);
GO

CREATE INDEX [IDX_TRANSMITLOG3_01] ON [dbo].[transmitlog3] ([transmitflag], [tablename], [key3]);
GO
CREATE INDEX [IDX_TRANSMITLOG3_CIdx] ON [dbo].[transmitlog3] ([tablename], [key1], [key3], [key2]);
GO