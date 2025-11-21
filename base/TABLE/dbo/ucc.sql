CREATE TABLE [dbo].[ucc]
(
    [UCCNo] nvarchar(20) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [ExternKey] nvarchar(50) NULL,
    [SKU] nvarchar(20) NOT NULL,
    [qty] int NULL,
    [Sourcekey] nvarchar(20) NULL,
    [Sourcetype] nvarchar(30) NULL,
    [Userdefined01] nvarchar(15) NULL DEFAULT (''),
    [Userdefined02] nvarchar(15) NULL DEFAULT (''),
    [Userdefined03] nvarchar(20) NULL DEFAULT (''),
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Lot] nvarchar(10) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL DEFAULT (''),
    [Id] nvarchar(18) NULL DEFAULT (''),
    [Receiptkey] nvarchar(10) NULL DEFAULT (' '),
    [ReceiptLineNumber] nvarchar(5) NULL DEFAULT (' '),
    [Orderkey] nvarchar(10) NULL DEFAULT (' '),
    [OrderLineNumber] nvarchar(5) NULL DEFAULT (' '),
    [WaveKey] nvarchar(10) NULL DEFAULT (' '),
    [PickDetailKey] nvarchar(18) NULL DEFAULT (' '),
    [Userdefined04] nvarchar(30) NULL DEFAULT (''),
    [Userdefined05] nvarchar(30) NULL DEFAULT (''),
    [Userdefined06] nvarchar(30) NULL DEFAULT (''),
    [Userdefined07] nvarchar(30) NULL DEFAULT (''),
    [Userdefined08] nvarchar(30) NULL DEFAULT (''),
    [Userdefined09] nvarchar(30) NULL DEFAULT (''),
    [Userdefined10] nvarchar(30) NULL DEFAULT (''),
    [UCC_RowRef] int IDENTITY(1,1) NOT NULL,
    [ArchiveCop] nchar(1) NULL,
    [TrafficCop] nchar(1) NULL,
    CONSTRAINT [PK_UCC] PRIMARY KEY ([UCC_RowRef])
);
GO

CREATE INDEX [IDX_UCC_ExternKey] ON [dbo].[ucc] ([Storerkey], [ExternKey]);
GO
CREATE INDEX [IDX_UCC_LOC] ON [dbo].[ucc] ([Loc]);
GO
CREATE INDEX [IDX_UCC_LOTxLOCxID] ON [dbo].[ucc] ([Lot], [Loc], [Id]);
GO
CREATE INDEX [IDX_UCC_Pickdetailkey] ON [dbo].[ucc] ([PickDetailKey]);
GO
CREATE INDEX [IDX_UCC_SKU_LOT_LOC] ON [dbo].[ucc] ([Storerkey], [SKU], [Lot], [Loc]);
GO
CREATE INDEX [IDX_UCC_SourceKey] ON [dbo].[ucc] ([Sourcekey]);
GO
CREATE INDEX [IDX_UCC_StorerKey_LOC_ID] ON [dbo].[ucc] ([Storerkey], [Loc], [Id]);
GO
CREATE INDEX [IDX_UCC_UCCNo] ON [dbo].[ucc] ([UCCNo]);
GO
CREATE INDEX [IX_UCC_Receipt] ON [dbo].[ucc] ([Receiptkey], [ReceiptLineNumber]);
GO
CREATE INDEX [IX_UCC_StorerKey_SKU] ON [dbo].[ucc] ([Storerkey], [SKU]);
GO
CREATE INDEX [IX_UCC_Storerkey_Status_Userdefined05_Userdefined06] ON [dbo].[ucc] ([Storerkey], [Status], [Userdefined05], [Userdefined06]);
GO
CREATE INDEX [IX_UCC_StorerKey_Userdefined04] ON [dbo].[ucc] ([Storerkey], [Userdefined04]);
GO