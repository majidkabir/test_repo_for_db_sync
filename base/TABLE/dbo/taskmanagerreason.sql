CREATE TABLE [dbo].[taskmanagerreason]
(
    [TaskManagerReasonKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [TOLOC] nvarchar(10) NOT NULL DEFAULT (' '),
    [ValidInFromLoc] nvarchar(10) NOT NULL DEFAULT ('1'),
    [ValidInToLoc] nvarchar(10) NOT NULL DEFAULT ('1'),
    [LOCHoldKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [IDHoldKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [RemoveTaskFromUserQueue] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DoCycleCount] nvarchar(10) NOT NULL DEFAULT ('0'),
    [TaskStatus] nvarchar(10) NOT NULL DEFAULT (' '),
    [ContinueProcessing] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [GenerateAlert] nvarchar(10) NULL DEFAULT ('1'),
    CONSTRAINT [PKTaskManagerReason] PRIMARY KEY ([TaskManagerReasonKey])
);
GO
