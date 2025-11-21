CREATE TABLE [dbo].[wms_sysprocess]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [currenttime] datetime NOT NULL,
    [spid] smallint NOT NULL,
    [Blocked] smallint NOT NULL,
    [hostname] nvarchar(256) NOT NULL,
    [program_name] nvarchar(256) NOT NULL,
    [net_address] nvarchar(24) NOT NULL,
    [loginame] nvarchar(256) NOT NULL,
    [login_time] datetime NOT NULL,
    [last_batch] datetime NOT NULL,
    [Duration] int NOT NULL,
    [Eventinfo] nvarchar(4000) NOT NULL,
    [DB_Name] nvarchar(200) NULL DEFAULT (''),
    [lastwaittype] nchar(32) NULL,
    CONSTRAINT [PK_wms_sysprocess] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_WMS_SysProcess_Currenttime_SPID] ON [dbo].[wms_sysprocess] ([currenttime], [spid]);
GO
CREATE INDEX [IX_WMS_sysProcessTime] ON [dbo].[wms_sysprocess] ([currenttime], [last_batch]);
GO