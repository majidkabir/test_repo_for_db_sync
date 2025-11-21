CREATE TABLE [dbo].[rfidtranslog]
(
    [RFIDTransLogKey] bigint IDENTITY(1,1) NOT NULL,
    [RFIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [TIDNo] nvarchar(100) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [TranType] nvarchar(10) NOT NULL DEFAULT (''),
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Adddate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Editdate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKRFIDTransLog] PRIMARY KEY ([RFIDTransLogKey])
);
GO

CREATE INDEX [IX_RFIDTransLog_RFIDNo] ON [dbo].[rfidtranslog] ([RFIDNo], [TIDNo]);
GO
CREATE INDEX [IX_RFIDTransLog_Storerkey] ON [dbo].[rfidtranslog] ([Storerkey], [SKU]);
GO