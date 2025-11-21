CREATE TABLE [dbo].[uploadpodetail]
(
    [POkey] nvarchar(10) NULL,
    [PoLineNumber] nvarchar(5) NULL,
    [Storerkey] nvarchar(15) NULL,
    [ExternPOkey] nvarchar(20) NULL,
    [POGroup] nvarchar(10) NULL,
    [ExternLinenumber] nvarchar(20) NULL,
    [SKU] nvarchar(20) NULL,
    [QtyOrdered] int NULL,
    [UOM] nvarchar(10) NULL DEFAULT ('PIECE'),
    [MODE] nvarchar(3) NULL,
    [STATUS] nvarchar(3) NULL DEFAULT ('0'),
    [REMARKS] nvarchar(150) NULL,
    [adddate] datetime NULL DEFAULT (getdate()),
    [Best_bf_Date] datetime NULL DEFAULT (getdate()),
    [ExpiryDate] datetime NULL,
    [SerialLot] nvarchar(18) NULL
);
GO

CREATE INDEX [IX_externpokey] ON [dbo].[uploadpodetail] ([ExternPOkey]);
GO
CREATE INDEX [IX_status] ON [dbo].[uploadpodetail] ([STATUS]);
GO
CREATE INDEX [IX_storerkey_sku] ON [dbo].[uploadpodetail] ([SKU], [Storerkey]);
GO
CREATE UNIQUE INDEX [IX_primary] ON [dbo].[uploadpodetail] ([POkey], [PoLineNumber]);
GO