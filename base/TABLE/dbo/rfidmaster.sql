CREATE TABLE [dbo].[rfidmaster]
(
    [RFIDMasterKey] bigint IDENTITY(1,1) NOT NULL,
    [RFIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [TIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Source] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DocRefno1] nvarchar(20) NULL,
    [DocRefno2] nvarchar(20) NULL,
    [DocRefno3] nvarchar(20) NULL,
    [DocRefno4] nvarchar(20) NULL,
    [DocRefno5] nvarchar(20) NULL,
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Editdate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKRFIDMaster] PRIMARY KEY ([RFIDMasterKey])
);
GO

CREATE INDEX [IX_RFIDMaster_RFIDNo] ON [dbo].[rfidmaster] ([RFIDNo], [TIDNo]);
GO
CREATE INDEX [IX_RFIDMaster_SKU] ON [dbo].[rfidmaster] ([Storerkey], [SKU]);
GO