CREATE TABLE [dbo].[workstation_log]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [WorkZone] nvarchar(10) NULL DEFAULT ('RACK'),
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WorkStation] nvarchar(50) NOT NULL,
    [WorkMethod] nvarchar(20) NULL DEFAULT (''),
    [Descr] nvarchar(80) NULL,
    [NoOfAssignedWorker] int NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ReasonCode] nvarchar(10) NULL,
    [SubReasonCode] nvarchar(10) NULL,
    [StartDownTime] datetime NULL,
    [EndDownTime] datetime NULL,
    [LogWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [LogDate] datetime NULL DEFAULT (getdate()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WorkStation_LOG] PRIMARY KEY ([RowRef])
);
GO
