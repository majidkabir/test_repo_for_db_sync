CREATE TABLE [rdt].[rdttracklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NULL,
    [Username] nvarchar(128) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [TrackNo] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [ErrMsg] nvarchar(250) NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [PickSlipNo] nvarchar(10) NULL DEFAULT (''),
    [CartonNo] int NULL DEFAULT ((0)),
    [LabelNo] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtTrackLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtTrackLog01] ON [rdt].[rdttracklog] ([Orderkey], [TrackNo]);
GO