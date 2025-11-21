CREATE TABLE [api].[appsection]
(
    [APPName] nvarchar(30) NOT NULL DEFAULT (''),
    [DeviceID] nvarchar(50) NOT NULL DEFAULT (''),
    [UserID] nvarchar(128) NOT NULL DEFAULT (''),
    [SectionTime] datetime NULL,
    [ScanNo] nvarchar(30) NULL DEFAULT (''),
    [PickslipNo] nvarchar(30) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_AppSection] PRIMARY KEY ([DeviceID])
);
GO
