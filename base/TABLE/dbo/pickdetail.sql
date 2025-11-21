CREATE TABLE [dbo].[pickdetail]
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
    [Channel_ID] bigint NULL DEFAULT ((0)),
    [SourceType] nvarchar(50) NULL DEFAULT (''),
    CONSTRAINT [PKPickDetail] PRIMARY KEY ([PickDetailKey]),
    CONSTRAINT [FK_PICKDETAIL_LOT_01] FOREIGN KEY ([Storerkey], [Sku], [Lot]) REFERENCES [dbo].[LOTATTRIBUTE] ([StorerKey], [Sku], [Lot]),
    CONSTRAINT [FK_PICKDETAIL_LOTLOCID_01] FOREIGN KEY ([Lot], [Loc], [ID]) REFERENCES [dbo].[LOTxLOCxID] ([Lot], [Loc], [Id]),
    CONSTRAINT [FK_PICKDETAIL_SKU_01] FOREIGN KEY ([Storerkey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku]),
    CONSTRAINT [CK_PICKDETAIL_Qty] CHECK ([Qty]>=(0)),
    CONSTRAINT [CK_PICKDETAIL_Status] CHECK (rtrim([Status]) like '[0-9]')
);
GO

CREATE INDEX [IDX_PICKDETAIL_CASEID] ON [dbo].[pickdetail] ([CaseID]);
GO
CREATE INDEX [IDX_PICKDETAIL_DropID] ON [dbo].[pickdetail] ([WaveKey], [DropID], [Sku], [Storerkey], [Status]);
GO
CREATE INDEX [IDX_PICKDETAIL_ID] ON [dbo].[pickdetail] ([ID]);
GO
CREATE INDEX [IDX_PICKDETAIL_ORDERKEY] ON [dbo].[pickdetail] ([OrderKey]);
GO
CREATE INDEX [idx_pickdetail_pickslipno] ON [dbo].[pickdetail] ([PickSlipNo]);
GO
CREATE INDEX [ix_PICKDETAIL_Lotxlocxid] ON [dbo].[pickdetail] ([Lot], [Loc], [ID]);
GO
CREATE INDEX [IX_PICKDETAIL_TaskDetailKey] ON [dbo].[pickdetail] ([TaskDetailKey]);
GO
CREATE INDEX [PICKDETAIL_OrderDetStatus] ON [dbo].[pickdetail] ([OrderKey], [OrderLineNumber], [Status]);
GO
CREATE INDEX [PICKDETAIL10] ON [dbo].[pickdetail] ([OrderKey], [Storerkey], [Status], [Qty], [DropID]);
GO
CREATE INDEX [PICKDETAIL12] ON [dbo].[pickdetail] ([OrderKey], [PickHeaderKey]);
GO
CREATE INDEX [PICKDETAIL9] ON [dbo].[pickdetail] ([Loc]);
GO