CREATE TABLE [dbo].[packinfo]
(
    [PickSlipNo] nvarchar(10) NOT NULL,
    [CartonNo] int NOT NULL,
    [Weight] float NULL DEFAULT ((0)),
    [Cube] float NULL DEFAULT ((0)),
    [Qty] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [CartonType] nvarchar(10) NULL DEFAULT (' '),
    [RefNo] nvarchar(40) NULL,
    [Length] float NULL DEFAULT ((0.00)),
    [Width] float NULL DEFAULT ((0.00)),
    [Height] float NULL DEFAULT ((0.00)),
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    [CartonGID] nvarchar(50) NULL DEFAULT (''),
    [CartonStatus] nvarchar(20) NULL DEFAULT (''),
    [TrackingNo] nvarchar(40) NULL DEFAULT (''),
    CONSTRAINT [PK_PackInfo] PRIMARY KEY ([PickSlipNo], [CartonNo])
);
GO

CREATE INDEX [IX_PackInfo_UCCNo] ON [dbo].[packinfo] ([UCCNo]);
GO