CREATE TABLE [api].[appworkstation_log]
(
    [AppWorkStationLogKey] bigint IDENTITY(1,1) NOT NULL,
    [AppName] nvarchar(30) NOT NULL DEFAULT (''),
    [WorkStation] nvarchar(30) NOT NULL DEFAULT (''),
    [DeviceID] nvarchar(50) NOT NULL DEFAULT (''),
    [CurrentVersion] nvarchar(12) NULL DEFAULT (''),
    [TargetVersion] nvarchar(12) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_AppWorkStation_Log] PRIMARY KEY ([AppWorkStationLogKey])
);
GO
