CREATE TABLE [dbo].[transmitlog2]
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
    CONSTRAINT [PKTRANSMITLOG2] PRIMARY KEY ([transmitlogkey])
);
GO

CREATE INDEX [IDX_TRANSMITLOG2_CIdx] ON [dbo].[transmitlog2] ([tablename], [key1], [key2], [key3]);
GO
CREATE INDEX [IDX_TRANSMITLOG2_CIdx2] ON [dbo].[transmitlog2] ([tablename], [key2], [key3]);
GO
CREATE INDEX [IDX_TRANSMITLOG2_KEY1] ON [dbo].[transmitlog2] ([key1]);
GO
CREATE INDEX [IDX_TRANSMITLOG2_KEY3] ON [dbo].[transmitlog2] ([key3], [transmitflag], [tablename], [key1]);
GO