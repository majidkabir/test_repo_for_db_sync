CREATE TABLE [dbo].[physical]
(
    [Team] nvarchar(1) NOT NULL DEFAULT ('A'),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT ('UNKNOWN'),
    [Lot] nvarchar(10) NOT NULL DEFAULT (' '),
    [Id] nvarchar(18) NOT NULL DEFAULT (' '),
    [InventoryTag] nvarchar(18) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL DEFAULT ((0)),
    [PackKey] nvarchar(10) NULL DEFAULT (' '),
    [UOM] nvarchar(10) NULL DEFAULT (' '),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [SheetNoKey] nvarchar(10) NULL DEFAULT (' '),
    CONSTRAINT [PKPhysical] PRIMARY KEY ([Team], [StorerKey], [Sku], [Lot], [Loc], [Id], [InventoryTag]),
    CONSTRAINT [FK_PHYSICAL_ID_01] FOREIGN KEY ([Id]) REFERENCES [dbo].[ID] ([Id]),
    CONSTRAINT [FK_PHYSICAL_LOC_01] FOREIGN KEY ([Loc]) REFERENCES [dbo].[LOC] ([Loc]),
    CONSTRAINT [FK_PHYSICAL_SKU_01] FOREIGN KEY ([StorerKey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku])
);
GO
