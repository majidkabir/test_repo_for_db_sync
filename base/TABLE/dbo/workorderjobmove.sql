CREATE TABLE [dbo].[workorderjobmove]
(
    [WOMoveKey] bigint IDENTITY(1,1) NOT NULL,
    [JobKey] nvarchar(10) NOT NULL DEFAULT (''),
    [JobLine] nvarchar(5) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [PackKey] nvarchar(10) NOT NULL DEFAULT (''),
    [UOM] nvarchar(10) NOT NULL DEFAULT (''),
    [Lot] nvarchar(10) NOT NULL DEFAULT (''),
    [FromLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [ToLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [Qty] int NULL DEFAULT ((0)),
    [Lottable01] nvarchar(18) NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable03] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
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
    [PickMethod] nvarchar(10) NULL DEFAULT (''),
    [JobReserveKey] nvarchar(10) NULL DEFAULT (''),
    [OriginalLoc] nvarchar(10) NULL DEFAULT ('')
);
GO

CREATE INDEX [IDX_WorkOrderJobMove_Job] ON [dbo].[workorderjobmove] ([JobKey], [JobLine]);
GO