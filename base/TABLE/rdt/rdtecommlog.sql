CREATE TABLE [rdt].[rdtecommlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NULL,
    [ToteNo] nvarchar(20) NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [DropIDType] nvarchar(10) NOT NULL,
    [ExpectedQty] int NOT NULL DEFAULT ((0)),
    [ScannedQty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [ErrMsg] nvarchar(250) NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [BatchKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtECOMMLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtECOMMLog_SKU] ON [rdt].[rdtecommlog] ([Status], [SKU], [Mobile]);
GO
CREATE INDEX [IX_rdtECOMMLog_ToteNo] ON [rdt].[rdtecommlog] ([ToteNo]);
GO
CREATE INDEX [IX_rdtECOMMLog_ToteNo01] ON [rdt].[rdtecommlog] ([ToteNo], [Orderkey], [SKU]);
GO
CREATE INDEX [IX_rdtECOMMLog_ToteNo02] ON [rdt].[rdtecommlog] ([ToteNo], [Orderkey], [AddWho]);
GO
CREATE INDEX [IX_rdtECOMMLog_ToteNo03] ON [rdt].[rdtecommlog] ([ToteNo], [SKU], [AddWho]);
GO
CREATE INDEX [IX_rdtECOMMLog_ToteNo04] ON [rdt].[rdtecommlog] ([ToteNo], [Mobile]);
GO