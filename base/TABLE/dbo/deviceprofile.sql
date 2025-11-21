CREATE TABLE [dbo].[deviceprofile]
(
    [DeviceProfileKey] nvarchar(10) NOT NULL DEFAULT (''),
    [IPAddress] nvarchar(40) NOT NULL DEFAULT (' '),
    [PortNo] nvarchar(5) NOT NULL DEFAULT (' '),
    [DeviceType] nvarchar(20) NOT NULL DEFAULT ('0'),
    [DeviceID] nvarchar(20) NOT NULL DEFAULT ('0'),
    [DevicePosition] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [DeviceProfileLogKey] nvarchar(20) NULL DEFAULT (''),
    [Priority] nvarchar(10) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL,
    [LogicalPOS] nvarchar(10) NOT NULL DEFAULT (''),
    [LogicalName] nvarchar(10) NOT NULL DEFAULT (''),
    [Col] int NOT NULL DEFAULT ((0)),
    [Row] int NOT NULL DEFAULT ((0)),
    [DeviceModel] nvarchar(20) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    CONSTRAINT [PK_DeviceProfile] PRIMARY KEY ([DeviceProfileKey])
);
GO

CREATE INDEX [idx_DeviceProfile_Device] ON [dbo].[deviceprofile] ([DeviceType], [StorerKey], [DeviceID], [DevicePosition]);
GO
CREATE INDEX [IDX_DEVICEPROFILE_Loc] ON [dbo].[deviceprofile] ([Loc]);
GO