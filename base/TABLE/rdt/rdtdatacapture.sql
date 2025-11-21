CREATE TABLE [rdt].[rdtdatacapture]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [V_Zone] nvarchar(10) NULL DEFAULT (''),
    [V_Loc] nvarchar(10) NULL DEFAULT (''),
    [V_SKU] nvarchar(20) NULL DEFAULT (''),
    [V_UOM] nvarchar(10) NULL DEFAULT (''),
    [V_ID] nvarchar(18) NULL DEFAULT (''),
    [V_ConsigneeKey] nvarchar(15) NULL DEFAULT (''),
    [V_CaseID] nvarchar(15) NULL DEFAULT (''),
    [V_SKUDescr] nvarchar(60) NULL DEFAULT (''),
    [V_QTY] int NULL DEFAULT ((0)),
    [V_UCC] nvarchar(20) NULL DEFAULT (''),
    [V_Lottable01] nvarchar(18) NULL DEFAULT (''),
    [V_Lottable02] nvarchar(18) NULL DEFAULT (''),
    [V_Lottable03] nvarchar(18) NULL DEFAULT (''),
    [V_Lottable04] datetime NULL,
    [V_Lottable05] datetime NULL,
    [V_String1] nvarchar(20) NULL DEFAULT (''),
    [V_String2] nvarchar(20) NULL DEFAULT (''),
    [V_String3] nvarchar(20) NULL DEFAULT (''),
    [V_String4] nvarchar(20) NULL DEFAULT (''),
    [V_String5] nvarchar(20) NULL DEFAULT (''),
    [V_String6] nvarchar(20) NULL DEFAULT (''),
    [V_String7] nvarchar(20) NULL DEFAULT (''),
    [V_String8] nvarchar(20) NULL DEFAULT (''),
    [V_String9] nvarchar(20) NULL DEFAULT (''),
    [V_String10] nvarchar(20) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [V_Lottable06] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable07] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable08] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable09] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable10] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable11] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable12] nvarchar(30) NULL DEFAULT (''),
    [V_Lottable13] datetime NULL,
    [V_Lottable14] datetime NULL,
    [V_Lottable15] datetime NULL,
    [SerialNo] nvarchar(30) NOT NULL DEFAULT (''),
    CONSTRAINT [PKRDTDataCapture] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_rdtDataCapture_serialno] ON [rdt].[rdtdatacapture] ([SerialNo]);
GO
CREATE INDEX [Idx_RDTDataCapture_StorerKey_Facility] ON [rdt].[rdtdatacapture] ([StorerKey], [Facility]);
GO
CREATE INDEX [Idx_RDTDataCapture_V_String1] ON [rdt].[rdtdatacapture] ([V_String1]);
GO