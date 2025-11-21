CREATE TABLE [dbo].[deviceprofilelog]
(
    [DeviceProfileKey] nvarchar(10) NOT NULL DEFAULT (''),
    [DeviceProfileLogKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [DropID] nvarchar(20) NOT NULL DEFAULT ('0'),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [UserDefine01] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine02] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine03] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine04] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine05] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine06] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine07] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine08] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine09] nvarchar(30) NOT NULL DEFAULT (' '),
    [UserDefine10] nvarchar(30) NOT NULL DEFAULT (' '),
    [ConsigneeKey] nvarchar(15) NULL DEFAULT (''),
    CONSTRAINT [PK_DeviceProfileLog] PRIMARY KEY ([DeviceProfileKey], [DeviceProfileLogKey], [OrderKey], [DropID])
);
GO

CREATE INDEX [IDX_DeviceProfileLog_DropID] ON [dbo].[deviceprofilelog] ([DropID], [OrderKey]);
GO