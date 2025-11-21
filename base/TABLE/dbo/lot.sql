CREATE TABLE [dbo].[lot]
(
    [Lot] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [CaseCnt] int NOT NULL DEFAULT ((0)),
    [InnerPack] int NOT NULL DEFAULT ((0)),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Pallet] int NOT NULL DEFAULT ((0)),
    [Cube] float NOT NULL DEFAULT ((0)),
    [GrossWgt] float NOT NULL DEFAULT ((0)),
    [NetWgt] float NOT NULL DEFAULT ((0)),
    [OtherUnit1] float NOT NULL DEFAULT ((0)),
    [OtherUnit2] float NOT NULL DEFAULT ((0)),
    [QtyPreAllocated] int NOT NULL DEFAULT ((0)),
    [GrossWgtpreAllocated] float NOT NULL DEFAULT ((0)),
    [NetWgtpreAllocated] float NOT NULL DEFAULT ((0)),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [GrossWgtAllocated] float NOT NULL DEFAULT ((0)),
    [NetWgtAllocated] float NOT NULL DEFAULT ((0)),
    [QtyPicked] int NOT NULL DEFAULT ((0)),
    [GrossWgtPicked] float NOT NULL DEFAULT ((0)),
    [NetWgtPicked] float NOT NULL DEFAULT ((0)),
    [QtyOnHold] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(10) NOT NULL DEFAULT ('OK'),
    [ArchiveQty] int NOT NULL DEFAULT ((0)),
    [ArchiveDate] datetime NOT NULL DEFAULT ('01/01/1901'),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKLot] PRIMARY KEY ([Lot]),
    CONSTRAINT [FK_LOT_LOTATTRIBUTE_01] FOREIGN KEY ([Lot]) REFERENCES [dbo].[LOTATTRIBUTE] ([Lot]),
    CONSTRAINT [FK_LOT_SKU_01] FOREIGN KEY ([StorerKey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku]),
    CONSTRAINT [FK_LOT_STORER_01] FOREIGN KEY ([StorerKey]) REFERENCES [dbo].[STORER] ([StorerKey]),
    CONSTRAINT [CK_LOT_01] CHECK ([Qty]>=(([QtyPreAllocated]+[QtyAllocated])+[QtyPicked])),
    CONSTRAINT [CK_LOT_QTY] CHECK ([Qty]>=(0)),
    CONSTRAINT [CK_LOT_QtyAllocated] CHECK ([QtyAllocated]>=(0)),
    CONSTRAINT [CK_LOT_QtyPicked] CHECK ([QtyPicked]>=(0)),
    CONSTRAINT [CK_LOT_QtyPreAllocated] CHECK ([QtyPreAllocated]>=(0)),
    CONSTRAINT [CK_LOT_QtyOnHold] CHECK ([QtyOnHold]>=(0))
);
GO

CREATE INDEX [LOTQty] ON [dbo].[lot] ([StorerKey], [Sku], [Lot], [Qty], [QtyPreAllocated], [QtyAllocated], [QtyPicked], [QtyOnHold], [Status]);
GO
CREATE UNIQUE INDEX [IDX_LOT_SKU_LOT] ON [dbo].[lot] ([StorerKey], [Sku], [Lot]);
GO