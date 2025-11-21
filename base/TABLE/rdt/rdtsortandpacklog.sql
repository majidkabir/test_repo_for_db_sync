CREATE TABLE [rdt].[rdtsortandpacklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NULL,
    [Username] nvarchar(128) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [PickSlipNo] nvarchar(10) NULL DEFAULT (''),
    [CartonNo] int NULL DEFAULT ((0)),
    [LabelNo] nvarchar(20) NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [UCC] nvarchar(20) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [CartonType] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [BatchKey] nvarchar(10) NULL DEFAULT (''),
    [WaveKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtSortAndPackLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_rdtSortAndPackLog_waveKey] ON [rdt].[rdtsortandpacklog] ([WaveKey], [SKU], [Status]);
GO