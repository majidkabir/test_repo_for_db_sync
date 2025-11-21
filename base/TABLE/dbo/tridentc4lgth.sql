CREATE TABLE [dbo].[tridentc4lgth]
(
    [TridentSchedulerKey] nvarchar(10) NOT NULL,
    [Hikey] nvarchar(10) NULL,
    [HiImpExp] nvarchar(1) NULL,
    [NextRunDate] datetime NULL,
    [LastRunDate] datetime NULL,
    [Frequency] nvarchar(10) NULL DEFAULT ('D'),
    [StartWindow] nvarchar(30) NULL,
    [StartString] nvarchar(30) NULL,
    [EnableFlag] nvarchar(10) NOT NULL,
    [SkipDays] nvarchar(10) NULL DEFAULT ('D'),
    [SkipTime] nvarchar(10) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (user_name(NULL))
);
GO

CREATE UNIQUE INDEX [PKscheduler] ON [dbo].[tridentc4lgth] ([TridentSchedulerKey]);
GO