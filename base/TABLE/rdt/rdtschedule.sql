CREATE TABLE [rdt].[rdtschedule]
(
    [ScheduleID] int IDENTITY(1,1) NOT NULL,
    [Type] nvarchar(1) NOT NULL,
    [TimeInterval] int NOT NULL DEFAULT ((0)),
    [IntervalType] nvarchar(1) NOT NULL DEFAULT ('S'),
    [CheckWeekDay] nvarchar(1) NULL DEFAULT ('N'),
    [Mon] nvarchar(1) NULL DEFAULT ('N'),
    [Teu] nvarchar(1) NULL DEFAULT ('N'),
    [Wed] nvarchar(1) NULL DEFAULT ('N'),
    [Thu] nvarchar(1) NULL DEFAULT ('N'),
    [Fri] nvarchar(1) NULL DEFAULT ('N'),
    [Sat] nvarchar(1) NULL DEFAULT ('N'),
    [Sun] nvarchar(1) NULL DEFAULT ('N'),
    [CheckTimeRestric] nvarchar(1) NULL DEFAULT ('N'),
    [StartingFrom] nvarchar(5) NULL,
    [EndingAt] nvarchar(5) NULL,
    [CheckDateRestric] nvarchar(1) NULL DEFAULT ('N'),
    [EffectiveFrom] datetime NULL,
    [EffectiveTill] datetime NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_RDTSchedule] PRIMARY KEY ([ScheduleID])
);
GO
