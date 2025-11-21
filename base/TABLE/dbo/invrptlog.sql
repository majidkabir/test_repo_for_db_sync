CREATE TABLE [dbo].[invrptlog]
(
    [invrptlogkey] nvarchar(10) NOT NULL,
    [tablename] nvarchar(30) NULL DEFAULT (' '),
    [key1] nvarchar(10) NULL DEFAULT (' '),
    [key2] nvarchar(5) NULL DEFAULT (' '),
    [key3] nvarchar(20) NULL DEFAULT (' '),
    [invrptflag] nvarchar(5) NULL DEFAULT ('0'),
    [flag2] nvarchar(5) NULL,
    [adddate] datetime NULL DEFAULT (getdate()),
    [addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [editdate] datetime NULL DEFAULT (getdate()),
    [editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKINVRPTLOG] PRIMARY KEY ([invrptlogkey])
);
GO

CREATE INDEX [IDX_INVRPTLOG_KEY1] ON [dbo].[invrptlog] ([key1]);
GO
CREATE INDEX [IDX_INVRPTLOG_KEY1_2] ON [dbo].[invrptlog] ([key1], [key2]);
GO
CREATE INDEX [IDX_INVRPTLOG_TABLENAME] ON [dbo].[invrptlog] ([tablename]);
GO
CREATE UNIQUE INDEX [IDS_INVRPTLOG_TBNM_key1_key2_key3] ON [dbo].[invrptlog] ([tablename], [key1], [key2], [key3]);
GO