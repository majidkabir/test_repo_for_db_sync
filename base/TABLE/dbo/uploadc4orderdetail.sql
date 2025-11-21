CREATE TABLE [dbo].[uploadc4orderdetail]
(
    [Orderkey] nvarchar(10) NOT NULL,
    [Orderlinenumber] nvarchar(5) NOT NULL,
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
    [RFF] nvarchar(10) NULL,
    [ExternPOKey] nvarchar(20) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_UPLOADC4ORDERDETAIL] PRIMARY KEY ([Orderkey], [Orderlinenumber])
);
GO

CREATE INDEX [IX_UPLOADC4ORDERDETAIL_ExtOrderKey] ON [dbo].[uploadc4orderdetail] ([ExternOrderkey], [ExternLineno]);
GO
CREATE INDEX [IX_UPLOADC4ORDERDETAIL_SKU] ON [dbo].[uploadc4orderdetail] ([Storerkey], [SKU]);
GO