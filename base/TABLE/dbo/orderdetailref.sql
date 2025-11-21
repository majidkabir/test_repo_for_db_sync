CREATE TABLE [dbo].[orderdetailref]
(
    [RowREF ] int IDENTITY(1,1) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL,
    [OrderLineNumber] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [ParentSKU] nvarchar(20) NOT NULL DEFAULT (' '),
    [ComponentSKU] nvarchar(20) NOT NULL DEFAULT (' '),
    [RetailSKU] nvarchar(20) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Note1] nvarchar(1000) NULL,
    [BOMQty] int NOT NULL DEFAULT ((0)),
    [RefType] nvarchar(10) NULL DEFAULT (''),
    [PackCnt] int NULL DEFAULT ((0)),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PKOrderDetailRef] PRIMARY KEY ([RowREF ])
);
GO

CREATE INDEX [IX_OrderDetailRef_BOM] ON [dbo].[orderdetailref] ([StorerKey], [ParentSKU], [ComponentSKU]);
GO
CREATE INDEX [IX_OrderDetailRef_OrderLine] ON [dbo].[orderdetailref] ([Orderkey], [OrderLineNumber]);
GO
CREATE INDEX [IX_OrderDetailRef_SKU] ON [dbo].[orderdetailref] ([StorerKey], [ParentSKU]);
GO