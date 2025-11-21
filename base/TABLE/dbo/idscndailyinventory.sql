CREATE TABLE [dbo].[idscndailyinventory]
(
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [Lot] nvarchar(20) NOT NULL,
    [Id] nvarchar(18) NOT NULL,
    [Qty] int NOT NULL,
    [Lottable02] nvarchar(18) NULL,
    [Lottable04] datetime NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [InventoryDate] datetime NULL
);
GO
