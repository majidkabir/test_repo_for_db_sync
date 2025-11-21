CREATE TABLE [dbo].[ids_inventory_balance]
(
    [exportdate] datetime NOT NULL DEFAULT (getdate()),
    [storerkey] nvarchar(15) NOT NULL,
    [sku] nvarchar(20) NOT NULL,
    [lot] nvarchar(10) NOT NULL,
    [id] nvarchar(18) NOT NULL,
    [loc] nvarchar(10) NOT NULL,
    [putawayzone] nvarchar(10) NULL,
    [qty] int NOT NULL,
    [qtyallocated] int NOT NULL,
    [qtypicked] int NOT NULL,
    [archivecop] nchar(1) NULL,
    [inventorydate] date NULL
);
GO
