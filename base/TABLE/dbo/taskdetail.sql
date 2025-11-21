CREATE TABLE [dbo].[taskdetail]
(
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [TaskType] nvarchar(10) NOT NULL DEFAULT (' '),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [UOM] nvarchar(5) NOT NULL DEFAULT (' '),
    [UOMQty] int NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [FromLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [LogicalFromLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [FromID] nvarchar(18) NOT NULL DEFAULT (' '),
    [ToLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [LogicalToLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [ToID] nvarchar(18) NOT NULL DEFAULT (' '),
    [Caseid] nvarchar(20) NOT NULL DEFAULT (' '),
    [PickMethod] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [StatusMsg] nvarchar(255) NOT NULL DEFAULT (' '),
    [Priority] nvarchar(10) NOT NULL DEFAULT (' '),
    [SourcePriority] nvarchar(10) NOT NULL DEFAULT (' '),
    [Holdkey] nvarchar(10) NOT NULL DEFAULT (' '),
    [UserKey] nvarchar(18) NOT NULL DEFAULT (' '),
    [UserPosition] nvarchar(10) NOT NULL DEFAULT ('1'),
    [UserKeyOverRide] nvarchar(18) NOT NULL DEFAULT (' '),
    [StartTime] datetime NOT NULL DEFAULT (getdate()),
    [EndTime] datetime NOT NULL DEFAULT (getdate()),
    [SourceType] nvarchar(30) NOT NULL DEFAULT (' '),
    [SourceKey] nvarchar(30) NOT NULL DEFAULT (' '),
    [PickDetailKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [ListKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ReasonKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Message01] nvarchar(20) NOT NULL DEFAULT (' '),
    [Message02] nvarchar(20) NOT NULL DEFAULT (' '),
    [Message03] nvarchar(20) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [SystemQty] int NULL DEFAULT ((0)),
    [RefTaskKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [AreaKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [TransitCount] int NOT NULL DEFAULT ((0)),
    [TransitLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [FinalLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [FinalID] nvarchar(18) NOT NULL DEFAULT (''),
    [Groupkey] nvarchar(10) NULL DEFAULT (''),
    [PendingMoveIn] int NULL DEFAULT ((0)),
    [QtyReplen] int NULL DEFAULT ((0)),
    [DeviceID] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKTaskDetail] PRIMARY KEY ([TaskDetailKey])
);
GO

CREATE INDEX [IDX_TASKDETAIL_01] ON [dbo].[taskdetail] ([UserKey], [TaskType], [Status], [FromLoc]);
GO
CREATE INDEX [IDX_TASKDETAIL_CASEID] ON [dbo].[taskdetail] ([Caseid], [TaskType], [Status], [Storerkey], [FromID]);
GO
CREATE INDEX [IDX_TASKDETAIL_DROPID] ON [dbo].[taskdetail] ([DropID]);
GO
CREATE INDEX [IDX_TASKDETAIL_FROMID] ON [dbo].[taskdetail] ([FromID]);
GO
CREATE INDEX [IDX_TASKDETAIL_ORDERKEY] ON [dbo].[taskdetail] ([OrderKey]);
GO
CREATE INDEX [IDX_Taskdetail_PickDetailKey] ON [dbo].[taskdetail] ([PickDetailKey]);
GO
CREATE INDEX [IDX_TASKDETAIL_TASKTYPE] ON [dbo].[taskdetail] ([TaskType]);
GO
CREATE INDEX [IDX_TASKDETAIL_WAVEKEY] ON [dbo].[taskdetail] ([WaveKey]);
GO