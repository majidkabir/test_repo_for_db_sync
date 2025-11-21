CREATE TABLE [dbo].[lotxlocxid_b4post]
(
    [CCKey] nvarchar(10) NOT NULL,
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
    CONSTRAINT [PKLOTxLOCxID_B4Post] PRIMARY KEY ([CCKey], [Lot], [Loc], [Id])
);
GO
