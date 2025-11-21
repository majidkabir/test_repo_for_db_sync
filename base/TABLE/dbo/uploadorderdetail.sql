CREATE TABLE [dbo].[uploadorderdetail]
(
    [Orderkey] nvarchar(10) NULL,
    [Orderlinenumber] nvarchar(5) NULL,
    [ExternOrderkey] nvarchar(50) NULL,
    [OrderGroup] nvarchar(10) NULL,
    [SKU] nvarchar(20) NULL,
    [Storerkey] nvarchar(15) NULL,
    [Openqty] int NULL,
    [Packkey] nvarchar(10) NULL,
    [UOM] nvarchar(10) NULL DEFAULT ('PIECE'),
    [ExternLineno] nvarchar(10) NULL,
    [ExtendedPrice] float NULL,
    [UnitPrice] float NULL,
    [Facility] nvarchar(5) NULL,
    [Mode] nvarchar(3) NULL,
    [status] nvarchar(1) NULL DEFAULT ('0'),
    [remarks] nvarchar(150) NULL,
    [adddate] datetime NULL DEFAULT (getdate()),
    [Lottable01] nvarchar(18) NULL DEFAULT (' '),
    [Lottable02] nvarchar(18) NULL DEFAULT (' '),
    [Lottable03] nvarchar(18) NULL DEFAULT (' '),
    [Lottable04] datetime NULL,
    [Lottable05] datetime NULL
);
GO

CREATE INDEX [IX_externorderkey] ON [dbo].[uploadorderdetail] ([ExternOrderkey]);
GO
CREATE INDEX [IX_status] ON [dbo].[uploadorderdetail] ([status]);
GO
CREATE INDEX [IX_storerkey_sku] ON [dbo].[uploadorderdetail] ([SKU], [Storerkey]);
GO
CREATE UNIQUE INDEX [IX_primary] ON [dbo].[uploadorderdetail] ([Orderkey], [Orderlinenumber]);
GO