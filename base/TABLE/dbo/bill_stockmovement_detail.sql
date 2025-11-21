CREATE TABLE [dbo].[bill_stockmovement_detail]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Company] nvarchar(45) NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Descr] nvarchar(60) NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL,
    [EffectiveDate] datetime NOT NULL,
    [Flag] nvarchar(2) NULL,
    [TranType] nvarchar(10) NOT NULL,
    [RunningTotal] int NULL,
    [record_number] int NULL
);
GO
