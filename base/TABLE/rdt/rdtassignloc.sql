CREATE TABLE [rdt].[rdtassignloc]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [PTSZone] nvarchar(10) NOT NULL,
    [PTSLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [PTSPosition] nvarchar(10) NOT NULL,
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKrdtAssignLoc] PRIMARY KEY ([RowRef])
);
GO
