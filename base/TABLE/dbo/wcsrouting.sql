CREATE TABLE [dbo].[wcsrouting]
(
    [WCSKey] nvarchar(10) NOT NULL,
    [ToteNo] nvarchar(20) NULL,
    [Initial_Final_Zone] nvarchar(10) NOT NULL DEFAULT (' '),
    [Final_Zone] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ActionFlag] nvarchar(1) NOT NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [OrderType] nvarchar(10) NOT NULL DEFAULT (' '),
    [TaskType] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [LoadKey] nvarchar(10) NULL DEFAULT (''),
    [WaveKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_WCSRouting] PRIMARY KEY ([WCSKey])
);
GO

CREATE INDEX [IX_WCSRouting_ToteNo] ON [dbo].[wcsrouting] ([ToteNo]);
GO