CREATE TABLE [dbo].[skuxloc]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [Loc] nvarchar(10) NOT NULL DEFAULT (' '),
    [Qty] int NOT NULL DEFAULT ((0)),
    [QtyAllocated] int NOT NULL DEFAULT ((0)),
    [QtyPicked] int NOT NULL DEFAULT ((0)),
    [QtyExpected] int NOT NULL DEFAULT ((0)),
    [QtyLocationLimit] int NOT NULL DEFAULT ((0)),
    [QtyLocationMinimum] int NOT NULL DEFAULT ((0)),
    [QtyPickInProcess] int NOT NULL DEFAULT ((0)),
    [QtyReplenishmentOverride] int NOT NULL DEFAULT ((0)),
    [ReplenishmentPriority] nvarchar(5) NOT NULL DEFAULT ('9'),
    [ReplenishmentSeverity] int NOT NULL DEFAULT ((0)),
    [ReplenishmentCasecnt] int NOT NULL DEFAULT ((0)),
    [LocationType] nvarchar(10) NOT NULL DEFAULT (' '),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKSKUxLOC] PRIMARY KEY ([StorerKey], [Sku], [Loc]),
    CONSTRAINT [FK_SKUxLOC_LOC_01] FOREIGN KEY ([Loc]) REFERENCES [dbo].[LOC] ([Loc]),
    CONSTRAINT [FK_SKUxLOC_SKU_01] FOREIGN KEY ([StorerKey], [Sku]) REFERENCES [dbo].[SKU] ([StorerKey], [Sku]),
    CONSTRAINT [CK_SKUxLOC_01] CHECK (([Qty]+[QtyExpected])>=([QtyAllocated]+[QtyPicked])),
    CONSTRAINT [CK_SKUxLOC_Qty] CHECK ([Qty]>=(0)),
    CONSTRAINT [CK_SKUxLOC_QtyAllocated] CHECK ([QtyAllocated]>=(0)),
    CONSTRAINT [CK_SKUxLOC_QtyPicked] CHECK ([QtyPicked]>=(0))
);
GO

CREATE INDEX [IDX_Loc_Includes] ON [dbo].[skuxloc] ([Loc]);
GO
CREATE INDEX [IDX_SKUxLOC_LOCTYPE] ON [dbo].[skuxloc] ([LocationType]);
GO
CREATE INDEX [IDX_SKUxLOC_REPSEV] ON [dbo].[skuxloc] ([ReplenishmentSeverity]);
GO
CREATE INDEX [SKUxLOC1] ON [dbo].[skuxloc] ([StorerKey], [Sku], [Loc]);
GO
CREATE INDEX [SKUxLOC2] ON [dbo].[skuxloc] ([StorerKey], [Loc]);
GO