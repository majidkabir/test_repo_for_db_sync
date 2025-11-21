CREATE TABLE [dbo].[op_cartonlines]
(
    [Cartonbatch] nvarchar(10) NOT NULL,
    [PickDetailKey] nvarchar(10) NOT NULL,
    [PickHeaderKey] nvarchar(10) NULL,
    [OrderKey] nvarchar(10) NULL,
    [OrderLineNumber] nvarchar(10) NULL,
    [Storerkey] nvarchar(15) NULL,
    [Sku] nvarchar(20) NULL,
    [Loc] nvarchar(10) NULL,
    [lot] nvarchar(10) NULL,
    [id] nvarchar(18) NULL,
    [caseid] nvarchar(10) NULL,
    [uom] nvarchar(10) NULL,
    [uomqty] int NULL,
    [qty] int NULL,
    [packkey] nvarchar(10) NULL,
    [cartongroup] nvarchar(10) NULL,
    [cartontype] nvarchar(10) NULL,
    [DoReplenish] nvarchar(1) NULL,
    [ReplenishZone] nvarchar(10) NULL,
    [DoCartonize] nvarchar(1) NULL,
    [PickMethod] nvarchar(1) NULL,
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [Archivecop] nvarchar(1) NULL,
    [Channel_ID] bigint NULL DEFAULT ((0)),
    CONSTRAINT [PKOP_CARTONLINES] PRIMARY KEY ([Cartonbatch], [PickDetailKey])
);
GO

CREATE INDEX [OP_CARTONLINES4] ON [dbo].[op_cartonlines] ([OrderKey]);
GO