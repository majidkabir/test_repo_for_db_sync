CREATE TABLE [dbo].[uploadc4podetail]
(
    [POkey] nvarchar(10) NOT NULL,
    [PoLineNumber] nvarchar(5) NOT NULL,
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
    [RFF] nvarchar(10) NULL,
    [StoreOrderNo] nvarchar(9) NULL,
    [StoreID] nvarchar(3) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_UploadC4PODetail] PRIMARY KEY ([POkey], [PoLineNumber])
);
GO

CREATE INDEX [IX_UploadC4PODetail_ExtOrdKey] ON [dbo].[uploadc4podetail] ([ExternPOkey], [ExternLinenumber]);
GO
CREATE INDEX [IX_UploadC4PODetail_SKU] ON [dbo].[uploadc4podetail] ([Storerkey], [SKU]);
GO