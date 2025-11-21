CREATE TABLE [dbo].[pickdet_log]
(
    [PDetLogNo] int IDENTITY(1,1) NOT NULL,
    [PickDetailKey] nvarchar(18) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [ID] nvarchar(18) NOT NULL,
    [UOM] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DropID] nvarchar(20) NOT NULL DEFAULT (''),
    [PackKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL,
    [LogDate] datetime NOT NULL DEFAULT (getdate()),
    [LogWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [PickSlipNo] nvarchar(10) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TaskDetailKey] nvarchar(10) NULL,
    [CaseID] nvarchar(20) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_PDetLogNo] PRIMARY KEY ([PDetLogNo])
);
GO

CREATE INDEX [idx_PICKDET_LOG_Pickdetailkey] ON [dbo].[pickdet_log] ([PickDetailKey]);
GO
CREATE INDEX [IX_PICKDET_LOG] ON [dbo].[pickdet_log] ([OrderKey], [OrderLineNumber]);
GO
CREATE INDEX [IX_PICKDET_LOG_OrderKey] ON [dbo].[pickdet_log] ([OrderKey], [OrderLineNumber]);
GO