CREATE TABLE [rdt].[rdtppa]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Refkey] nvarchar(18) NULL,
    [PickSlipno] nvarchar(10) NULL,
    [LoadKey] nvarchar(10) NULL,
    [Store] nvarchar(15) NULL,
    [StorerKey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [Descr] nvarchar(60) NULL,
    [PQty] int NULL,
    [CQty] int NULL,
    [Status] nvarchar(1) NULL,
    [UserName] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [NoofCheck] int NULL,
    [UOMQty] int NULL,
    [UCC] nvarchar(20) NULL DEFAULT (''),
    [ArchiveCop] nvarchar(1) NULL,
    [OrderKey] nvarchar(10) NULL DEFAULT (''),
    [DropID] nvarchar(20) NULL DEFAULT (''),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ID] nvarchar(18) NULL DEFAULT (''),
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
    [TaskDetailKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_RDTPPA] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [idx_rdtppa_dropid] ON [rdt].[rdtppa] ([StorerKey], [DropID]);
GO
CREATE INDEX [Idx_rdtPPA_LoadKey] ON [rdt].[rdtppa] ([LoadKey]);
GO
CREATE INDEX [IX_RDTPPA_SKUPickSlipNo] ON [rdt].[rdtppa] ([Sku], [StorerKey], [PickSlipno]);
GO
CREATE INDEX [IX_RDTPPA_SKURef] ON [rdt].[rdtppa] ([Sku], [StorerKey], [Refkey]);
GO