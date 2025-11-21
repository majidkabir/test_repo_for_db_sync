CREATE TABLE [dbo].[jobtasklookup]
(
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobLine] nvarchar(5) NOT NULL DEFAULT (''),
    [WOMovekey] bigint NOT NULL DEFAULT ((0)),
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WorkOrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_JobTaskLookup] PRIMARY KEY ([JobKey], [JobLine], [WOMovekey], [TaskDetailKey])
);
GO

CREATE INDEX [IX_JobTaskLookup_Move] ON [dbo].[jobtasklookup] ([JobKey], [JobLine], [WOMovekey]);
GO
CREATE INDEX [IX_JobTaskLookup_Task] ON [dbo].[jobtasklookup] ([TaskDetailKey]);
GO
CREATE INDEX [IX_JobTaskLookup_WorkOrder] ON [dbo].[jobtasklookup] ([JobKey], [JobLine], [WorkOrderKey]);
GO