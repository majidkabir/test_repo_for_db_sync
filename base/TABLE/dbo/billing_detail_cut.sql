CREATE TABLE [dbo].[billing_detail_cut]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL,
    [EffectiveDate] datetime NOT NULL,
    [Flag] nvarchar(1) NOT NULL,
    [TranType] nvarchar(10) NOT NULL,
    [RunningTotal] int NOT NULL
);
GO
