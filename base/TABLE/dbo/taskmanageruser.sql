CREATE TABLE [dbo].[taskmanageruser]
(
    [UserKey] nvarchar(18) NOT NULL DEFAULT (' '),
    [PriorityTaskType] nvarchar(10) NOT NULL DEFAULT ('1'),
    [StrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [EquipmentProfileKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [LastCaseIdPicked] nvarchar(10) NOT NULL DEFAULT (' '),
    [Lastwavekey] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [LastDropID] nvarchar(20) NULL DEFAULT (''),
    [LastLoadKey] nvarchar(10) NULL DEFAULT (''),
    [LastLoc] nvarchar(10) NULL DEFAULT (''),
    [LastPermissionProfileKey] nvarchar(10) NULL DEFAULT (' '),
    [LastOrderKey] nvarchar(10) NULL,
    CONSTRAINT [PKTaskManagerUser] PRIMARY KEY ([UserKey])
);
GO
