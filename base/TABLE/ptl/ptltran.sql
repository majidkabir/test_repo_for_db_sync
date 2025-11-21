CREATE TABLE [ptl].[ptltran]
(
    [PTLKey] bigint IDENTITY(1,1) NOT NULL,
    [IPAddress] nvarchar(40) NOT NULL DEFAULT (''),
    [DevicePosition] nvarchar(10) NOT NULL DEFAULT (''),
    [DeviceID] nvarchar(10) NULL DEFAULT (''),
    [Status] nvarchar(2) NOT NULL DEFAULT ('0'),
    [LightMode] nvarchar(10) NULL DEFAULT (''),
    [LightUp] nvarchar(1) NULL DEFAULT ('0'),
    [LightSequence] nvarchar(10) NULL DEFAULT (''),
    [PTLType] nvarchar(20) NOT NULL,
    [SourceKey] nvarchar(20) NULL DEFAULT (''),
    [DropID] nvarchar(20) NULL DEFAULT (''),
    [CaseID] nvarchar(20) NULL DEFAULT (''),
    [RefPTLKey] nvarchar(10) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [ConsigneeKey] nvarchar(15) NULL DEFAULT (''),
    [SKU] nvarchar(20) NULL DEFAULT (''),
    [LOC] nvarchar(10) NULL DEFAULT (''),
    [LOT] nvarchar(10) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [ExpectedQty] int NULL DEFAULT (''),
    [Qty] int NULL DEFAULT (''),
    [Remarks] nvarchar(500) NULL DEFAULT (''),
    [DisplayValue] nvarchar(10) NULL DEFAULT (''),
    [ReceiveValue] nvarchar(50) NULL DEFAULT (''),
    [DeviceProfileLogKey] nvarchar(10) NULL DEFAULT (''),
    [Func] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [GroupKey] int NOT NULL DEFAULT ((0)),
    [SourceType] nvarchar(50) NOT NULL DEFAULT (''),
    [Lottable01] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable02] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable03] nvarchar(18) NOT NULL DEFAULT (''),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [Lottable06] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable07] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable08] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable09] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable10] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable11] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable12] nvarchar(30) NOT NULL DEFAULT (''),
    [Lottable13] datetime NULL,
    [Lottable14] datetime NULL,
    [Lottable15] datetime NULL,
    [MessageNum] nvarchar(10) NULL DEFAULT (''),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    CONSTRAINT [PK_PTLTran] PRIMARY KEY ([PTLKey])
);
GO

CREATE INDEX [IDX_PTLTRAN_01] ON [ptl].[ptltran] ([DeviceProfileLogKey], [DevicePosition]);
GO
CREATE INDEX [IDX_PTLTRAN_02] ON [ptl].[ptltran] ([DeviceID], [LightUp]);
GO
CREATE INDEX [IDX_PTLTRAN_03] ON [ptl].[ptltran] ([StorerKey], [SKU], [DropID], [Status]);
GO
CREATE INDEX [IDX_PTLTRAN_DeviceID] ON [ptl].[ptltran] ([DeviceID], [DevicePosition]);
GO
CREATE INDEX [IX_PTLTran_CaseID] ON [ptl].[ptltran] ([CaseID], [StorerKey]);
GO
CREATE INDEX [IX_PTLTran_Key1] ON [ptl].[ptltran] ([IPAddress], [DevicePosition], [Status]);
GO
CREATE INDEX [IX_PTLTran_Orderkey] ON [ptl].[ptltran] ([OrderKey], [SKU]);
GO