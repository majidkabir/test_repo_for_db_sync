CREATE TABLE [dbo].[workstation]
(
    [Facility] nvarchar(5) NOT NULL,
    [WorkZone] nvarchar(10) NULL DEFAULT ('RACK'),
    [WorkStation] nvarchar(50) NOT NULL,
    [WorkMethod] nvarchar(20) NULL DEFAULT (''),
    [Descr] nvarchar(80) NULL,
    [NoOfAssignedWorker] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ReasonCode] nvarchar(10) NULL,
    [SubReasonCode] nvarchar(10) NULL,
    [StartDownTime] datetime NULL,
    [EndDownTime] datetime NULL,
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_WorkStation] PRIMARY KEY ([WorkStation])
);
GO
