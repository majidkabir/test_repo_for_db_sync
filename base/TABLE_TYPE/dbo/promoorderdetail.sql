CREATE TYPE [dbo].[promoorderdetail] AS TABLE
(
    [OrderKey] nvarchar(20) NULL,
    [OrderLine] nvarchar(5) NULL,
    [Storerkey] nvarchar(15) NULL,
    [SKU] nvarchar(20) NULL,
    [Qty] int NULL,
    [LineAmt] money NULL,
    [ProductCategory] nvarchar(20) NULL
);
GO