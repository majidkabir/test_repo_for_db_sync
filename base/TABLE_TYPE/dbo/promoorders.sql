CREATE TYPE [dbo].[promoorders] AS TABLE
(
    [OrderKey] nvarchar(20) NULL,
    [Storerkey] nvarchar(15) NULL,
    [OrderDate] datetime NULL,
    [OrderAmt] money NULL,
    [OrderQty] int NULL,
    [City] nvarchar(20) NULL,
    [ShopCode] nvarchar(15) NULL
);
GO