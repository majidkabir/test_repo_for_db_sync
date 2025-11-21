CREATE TABLE [dbo].[externlotattribute]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [ExternLot] nvarchar(60) NOT NULL,
    [ExternLotStatus] nvarchar(10) NULL DEFAULT (' '),
    [ExternLottable01] nvarchar(60) NULL DEFAULT (' '),
    [ExternLottable02] nvarchar(60) NULL DEFAULT (' '),
    [ExternLottable03] nvarchar(60) NULL DEFAULT (' '),
    [ExternLottable04] datetime NULL DEFAULT (' '),
    [ExternLottable05] datetime NULL DEFAULT (' '),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_ExternLotAttribute] PRIMARY KEY ([StorerKey], [SKU], [ExternLot])
);
GO

CREATE INDEX [IX_ExternLotAttribute_ExternLOT] ON [dbo].[externlotattribute] ([ExternLot]);
GO