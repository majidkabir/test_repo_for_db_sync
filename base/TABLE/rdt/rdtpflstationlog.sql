CREATE TABLE [rdt].[rdtpflstationlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Station] nvarchar(10) NOT NULL,
    [Method] nvarchar(1) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (''),
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [CartonID] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPFLStationLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPFLStationLog_Station] ON [rdt].[rdtpflstationlog] ([Station]);
GO