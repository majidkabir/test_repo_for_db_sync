CREATE TABLE [dbo].[preallocatepickdetail]
(
    [PreAllocatePickDetailKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [OrderLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [UOM] nvarchar(5) NOT NULL DEFAULT (' '),
    [UOMQty] int NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Packkey] nvarchar(10) NOT NULL DEFAULT (' '),
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [PreAllocateStrategyKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [PreAllocatePickCode] nvarchar(10) NOT NULL DEFAULT (' '),
    [DoCartonize] nvarchar(1) NOT NULL DEFAULT ('N'),
    [PickMethod] nvarchar(1) NOT NULL DEFAULT (' '),
    [RunKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKPreAllocatePickDetail] PRIMARY KEY ([PreAllocatePickDetailKey]),
    CONSTRAINT [CK_PAPD_Qty] CHECK ([Qty]>=(0))
);
GO

CREATE INDEX [IDX_PAPD_ORDERKEY] ON [dbo].[preallocatepickdetail] ([OrderKey], [OrderLineNumber]);
GO