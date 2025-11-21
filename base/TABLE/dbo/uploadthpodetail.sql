CREATE TABLE [dbo].[uploadthpodetail]
(
    [POkey] nvarchar(10) NULL,
    [PoLineNumber] nvarchar(5) NULL,
    [Storerkey] nvarchar(15) NULL,
    [ExternPOkey] nvarchar(20) NULL,
    [POGroup] nvarchar(10) NULL,
    [ExternLinenumber] nvarchar(20) NULL,
    [SKU] nvarchar(20) NULL,
    [QtyOrdered] int NULL,
    [UOM] nvarchar(10) NULL,
    [MODE] nvarchar(3) NULL,
    [STATUS] nvarchar(3) NULL,
    [REMARKS] nvarchar(150) NULL,
    [adddate] datetime NULL,
    [Best_bf_Date] datetime NULL
);
GO

CREATE INDEX [IX_UPLOADTHPODETAIL_ExternPOKeyPOLine] ON [dbo].[uploadthpodetail] ([ExternPOkey], [ExternLinenumber]);
GO
CREATE INDEX [IX_UPLOADTHPODETAIL_POKeyPOLine] ON [dbo].[uploadthpodetail] ([POkey], [PoLineNumber]);
GO