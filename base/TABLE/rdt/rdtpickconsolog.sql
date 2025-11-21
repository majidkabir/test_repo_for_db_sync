CREATE TABLE [rdt].[rdtpickconsolog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [PickZone] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NULL,
    [LOC] nvarchar(10) NOT NULL,
    [Status] nvarchar(10) NOT NULL,
    [LabelPrinted] nvarchar(1) NOT NULL DEFAULT ('0'),
    [ReportPrinted] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Mobile] int NULL,
    [DropID] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PKPickConsoLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_rdtPickConsoLog_01] ON [rdt].[rdtpickconsolog] ([Orderkey], [PickZone]);
GO
CREATE INDEX [IDX_rdtPickConsoLog_02] ON [rdt].[rdtpickconsolog] ([Orderkey], [SKU]);
GO
CREATE INDEX [IDX_rdtPickConsoLog_03] ON [rdt].[rdtpickconsolog] ([Orderkey], [LOC]);
GO
CREATE INDEX [IDX_rdtPickConsoLog_04] ON [rdt].[rdtpickconsolog] ([LOC], [Status]);
GO