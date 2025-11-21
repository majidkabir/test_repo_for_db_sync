CREATE TABLE [dbo].[cartonlistdetail]
(
    [CartonKey] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Qty] int NULL,
    [PickDetailKey] nvarchar(18) NOT NULL,
    [Orderkey] nvarchar(20) NULL DEFAULT (''),
    [LabelNo] nvarchar(20) NULL,
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PKCartonListDetail] PRIMARY KEY ([CartonKey], [SKU], [PickDetailKey])
);
GO

CREATE INDEX [IX_CartonListDetail_Orderkey] ON [dbo].[cartonlistdetail] ([Orderkey], [SKU]);
GO
CREATE INDEX [IX_CartonListDetail_PDkey] ON [dbo].[cartonlistdetail] ([PickDetailKey], [SKU]);
GO