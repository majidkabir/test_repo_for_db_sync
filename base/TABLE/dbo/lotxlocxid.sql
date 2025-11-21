CREATE TABLE [dbo].[lotxlocxid]
(
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [QtyPicked] int NOT NULL DEFAULT ((0)),
    [QtyExpected] int NOT NULL DEFAULT ((0)),
    [QtyPickInProcess] int NOT NULL DEFAULT ((0)),
    [PendingMoveIN] int NOT NULL DEFAULT ((0)),
    [ArchiveQty] int NOT NULL DEFAULT ((0)),
    [ArchiveDate] datetime NOT NULL DEFAULT ('01/01/1901'),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [QtyReplen] int NULL DEFAULT ((0)),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKLOTxLOCxID] PRIMARY KEY ([Lot], [Loc], [Id]),
    CONSTRAINT [FK_LOTxLOCxID_ID_01] FOREIGN KEY ([Id]) REFERENCES [dbo].[ID] ([Id]),
    CONSTRAINT [FK_LOTxLOCxID_LOC_01] FOREIGN KEY ([Loc]) REFERENCES [dbo].[LOC] ([Loc]),
    CONSTRAINT [FK_LOTxLOCxID_LOT_01] FOREIGN KEY ([Lot]) REFERENCES [dbo].[LOT] ([Lot]),
    CONSTRAINT [FK_LOTxLOCxID_SKU_01] FOREIGN KEY ([StorerKey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku]),
    CONSTRAINT [CK_LOTxLOCxID_01] CHECK (([Qty]+[QtyExpected])>=([QtyAllocated]+[QtyPicked])),
    CONSTRAINT [CK_LOTxLOCxID_Qty] CHECK ([Qty]>=(0)),
    CONSTRAINT [CK_LOTxLOCxID_QtyAllocated] CHECK ([QtyAllocated]>=(0)),
    CONSTRAINT [CK_LOTxLOCxID_QtyPicked] CHECK ([QtyPicked]>=(0))
);
GO

CREATE INDEX [IDX_LOTxLOCxID_ID] ON [dbo].[lotxlocxid] ([Id]);
GO
CREATE INDEX [IDX_LOTxLOCxID_LOC] ON [dbo].[lotxlocxid] ([StorerKey], [Sku], [Loc]);
GO
CREATE INDEX [IDX_LotxLocxId_LocQty] ON [dbo].[lotxlocxid] ([Loc], [Lot], [Id], [StorerKey], [Sku], [Qty], [QtyAllocated], [QtyPicked], [QtyReplen]);
GO
CREATE INDEX [IDX_LotxLocxId_StorerkeySkuLLI] ON [dbo].[lotxlocxid] ([Lot], [Loc], [Id], [StorerKey], [Sku]);
GO