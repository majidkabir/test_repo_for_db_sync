CREATE TABLE [api].[appworkstation]
(
    [APPName] nvarchar(30) NOT NULL DEFAULT (''),
    [Workstation] nvarchar(30) NOT NULL DEFAULT (''),
    [DeviceID] nvarchar(50) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [CurrentVersion] nvarchar(12) NOT NULL DEFAULT (''),
    [TargetVersion] nvarchar(12) NOT NULL DEFAULT (''),
    [PrinterID] nvarchar(20) NOT NULL DEFAULT (''),
    [Defaultstorerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [DefaultFacility] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_AppWorkstation] PRIMARY KEY ([APPName], [Workstation], [DeviceID])
);
GO
