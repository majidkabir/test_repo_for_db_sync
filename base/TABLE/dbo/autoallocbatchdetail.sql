CREATE TABLE [dbo].[autoallocbatchdetail]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [AllocBatchNo] bigint NOT NULL DEFAULT ((0)),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nchar(1) NULL DEFAULT ('0'),
    [TotalSKU] int NULL DEFAULT ((0)),
    [SKUAllocated] int NULL DEFAULT ((0)),
    [NoStockFound] bit NULL DEFAULT ((0)),
    [AllocErrorFound] bit NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_AutoAllocBatchDetail] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_AutoAllocBatchDetail_BatchNo] ON [dbo].[autoallocbatchdetail] ([AllocBatchNo], [TotalSKU]);
GO