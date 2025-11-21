CREATE TABLE [dbo].[pickdetail_wip]
(
    [PickDetailKey] nvarchar(18) NOT NULL,
    [CaseID] nvarchar(20) NOT NULL DEFAULT (' '),
    [PickHeaderKey] nvarchar(18) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [AltSku] nvarchar(20) NOT NULL DEFAULT (' '),
    [UOM] nvarchar(10) NOT NULL DEFAULT (' '),
    [UOMQty] int NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyMoved] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [ID] nvarchar(18) NOT NULL DEFAULT (' '),
    [PackKey] nvarchar(10) NULL DEFAULT (' '),
    [UpdateSource] nvarchar(10) NULL DEFAULT ('0'),
    [CartonGroup] nvarchar(10) NULL,
    [CartonType] nvarchar(10) NULL,
    [ToLoc] nvarchar(10) NULL DEFAULT (' '),
    [DoReplenish] nvarchar(1) NULL DEFAULT ('N'),
    [ReplenishZone] nvarchar(10) NULL DEFAULT (' '),
    [DoCartonize] nvarchar(1) NULL DEFAULT ('N'),
    [PickMethod] nvarchar(1) NOT NULL DEFAULT (' '),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [OptimizeCop] nvarchar(1) NULL,
    [ShipFlag] nvarchar(1) NULL DEFAULT ('0'),
    [PickSlipNo] nvarchar(10) NULL,
    [TaskDetailKey] nvarchar(10) NULL,
    [TaskManagerReasonKey] nvarchar(10) NULL,
    [Notes] nvarchar(4000) NULL,
    [MoveRefKey] nvarchar(10) NULL DEFAULT (''),
    [WIP_Refno] nvarchar(30) NULL DEFAULT (''),
    [Channel_ID] bigint NULL DEFAULT ((0)),
    CONSTRAINT [PKPickDetail_WIP] PRIMARY KEY ([PickDetailKey])
);
GO

CREATE INDEX [IX_PickDetail_WIP_OrdKey] ON [dbo].[pickdetail_wip] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [PickDetail_WIP_WIP_RefNo] ON [dbo].[pickdetail_wip] ([WIP_Refno], [OrderKey]);
GO