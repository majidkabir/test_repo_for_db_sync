CREATE TABLE [dbo].[bill_stockmovement]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL,
    [EffectiveDate] datetime NOT NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_BillStockMovement] PRIMARY KEY ([Lot], [EffectiveDate])
);
GO
