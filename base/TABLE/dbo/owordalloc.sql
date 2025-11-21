CREATE TABLE [dbo].[owordalloc]
(
    [ExternOrderkey] nvarchar(50) NOT NULL,
    [ExternOrderkey2] nvarchar(50) NOT NULL,
    [ExternOrderKey3] nvarchar(50) NOT NULL,
    [ExternLineNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [UOM] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Lottable02] nvarchar(18) NOT NULL,
    [Status] nvarchar(10) NOT NULL,
    [PickCode] nvarchar(10) NOT NULL,
    [LoadKey] nvarchar(10) NOT NULL,
    [Qty] int NULL,
    [Loc] nvarchar(10) NOT NULL,
    [Deliverydate] datetime NULL,
    [NewLineNo] nvarchar(10) NOT NULL,
    [TableName] nvarchar(30) NOT NULL,
    [DiscreteFlag] nvarchar(10) NULL,
    [ActionCode] nvarchar(1) NOT NULL,
    [TLDate] datetime NOT NULL,
    [TransmitFlag] nvarchar(1) NULL,
    [TransmitLogKey] nvarchar(10) NULL,
    [AddDate] datetime NULL DEFAULT (getdate())
);
GO

CREATE INDEX [IX_OWOrdAlloc_ExtOrdKey] ON [dbo].[owordalloc] ([ExternOrderkey], [ExternLineNo]);
GO
CREATE INDEX [IX_OWOrdAlloc_TrnKey] ON [dbo].[owordalloc] ([TransmitLogKey], [TransmitFlag]);
GO