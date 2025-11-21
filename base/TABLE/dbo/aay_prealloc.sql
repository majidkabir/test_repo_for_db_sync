CREATE TABLE [dbo].[aay_prealloc]
(
    [PreAllocatePickDetailKey] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [UOM] nvarchar(5) NOT NULL,
    [UOMQty] int NOT NULL,
    [Qty] int NOT NULL,
    [Packkey] nvarchar(10) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [PreAllocateStrategyKey] nvarchar(10) NOT NULL,
    [PreAllocatePickCode] nvarchar(10) NOT NULL,
    [DoCartonize] nvarchar(1) NOT NULL,
    [PickMethod] nvarchar(1) NOT NULL,
    [RunKey] nvarchar(10) NOT NULL,
    [EffectiveDate] datetime NOT NULL,
    [AddDate] datetime NOT NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [EditDate] datetime NOT NULL,
    [EditWho] nvarchar(128) NOT NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL
);
GO
