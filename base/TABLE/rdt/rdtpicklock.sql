CREATE TABLE [rdt].[rdtpicklock]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [PutawayZone] nvarchar(10) NOT NULL,
    [PickZone] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [PickDetailKey] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [Descr] nvarchar(60) NULL,
    [LOC] nvarchar(10) NOT NULL,
    [LOT] nvarchar(10) NOT NULL,
    [ID] nvarchar(18) NULL,
    [PickQty] int NOT NULL DEFAULT ((0)),
    [UOM] nvarchar(10) NULL,
    [UOMQty] int NOT NULL DEFAULT ((0)),
    [Packkey] nvarchar(10) NULL,
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [PickSlipNo] nvarchar(10) NULL,
    [LogicalLocation] nvarchar(18) NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [DropID] nvarchar(20) NULL,
    [Mobile] int NULL,
    [LabelNo] nvarchar(20) NULL,
    [Lottable06] nvarchar(30) NULL DEFAULT (''),
    [Lottable07] nvarchar(30) NULL DEFAULT (''),
    [Lottable08] nvarchar(30) NULL DEFAULT (''),
    [Lottable09] nvarchar(30) NULL DEFAULT (''),
    [Lottable10] nvarchar(30) NULL DEFAULT (''),
    [Lottable11] nvarchar(30) NULL DEFAULT (''),
    [Lottable12] nvarchar(30) NULL DEFAULT (''),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    [BatchKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKrdtPickLock] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [idx_RDTPickLock_01] ON [rdt].[rdtpicklock] ([Status], [AddWho], [Orderkey], [Storerkey], [WaveKey]);
GO
CREATE INDEX [idx_RDTPickLock_Mobile] ON [rdt].[rdtpicklock] ([Mobile]);
GO
CREATE INDEX [idx_RDTPickLock_Order_sku] ON [rdt].[rdtpicklock] ([Orderkey], [SKU], [LOC], [DropID]);
GO
CREATE INDEX [IDX_RDTPickLock_PickDetailKey] ON [rdt].[rdtpicklock] ([AddWho], [PickDetailKey], [Status]);
GO
CREATE INDEX [idx_RDTPickLock_Storer_SKU] ON [rdt].[rdtpicklock] ([Storerkey], [AddWho], [SKU], [Status]);
GO