CREATE TABLE [dbo].[workorderjob]
(
    [SerialKey] int IDENTITY(1,1) NOT NULL,
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WorkOrderName] nvarchar(50) NOT NULL DEFAULT (''),
    [Sequence] nvarchar(10) NULL,
    [QtyRemaining] int NULL DEFAULT ((0)),
    [WorkStation] nvarchar(50) NULL,
    [TimeRate] nvarchar(30) NOT NULL DEFAULT (''),
    [NoOfAssignedWorker] int NOT NULL DEFAULT ((0)),
    [STDTime] float NOT NULL DEFAULT ((0.00)),
    [EstMins] int NOT NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [QtyJob] int NULL DEFAULT ((0)),
    [QtyCompleted] int NULL DEFAULT ((0)),
    [JobStatus] nvarchar(10) NULL DEFAULT ('0'),
    [UOMQtyJob] int NULL DEFAULT ((0)),
    [QtyReleased] int NULL DEFAULT ((0)),
    [Start_Production] datetime NULL,
    [End_Production] datetime NULL,
    [InLOC] nvarchar(10) NULL,
    [OutLOC] nvarchar(10) NULL,
    CONSTRAINT [PK_WorkOrderJob] PRIMARY KEY ([SerialKey])
);
GO

CREATE INDEX [IDX_WorkOrderJob_WorkOrderKey] ON [dbo].[workorderjob] ([WorkOrderKey], [Storerkey]);
GO