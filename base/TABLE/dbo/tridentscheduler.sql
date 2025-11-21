CREATE TABLE [dbo].[tridentscheduler]
(
    [TridentSchedulerKey] nvarchar(10) NOT NULL,
    [Hikey] nvarchar(10) NULL,
    [HiImpExp] nvarchar(1) NULL,
    [NextRunDate] datetime NULL,
    [LastRunDate] datetime NULL,
    [Frequency] nvarchar(10) NULL DEFAULT ('D'),
    [StartWindow] nvarchar(30) NULL,
    [StartString] nvarchar(30) NULL,
    [EnableFlag] nvarchar(10) NOT NULL DEFAULT ('D'),
    [SkipDays] nvarchar(10) NULL,
    [SkipTime] nvarchar(10) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (user_name(NULL)),
    CONSTRAINT [PKscheduler] PRIMARY KEY ([TridentSchedulerKey])
);
GO
