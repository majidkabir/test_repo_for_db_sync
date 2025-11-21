CREATE TABLE [dbo].[autoallocbatchjob]
(
    [RowID] bigint IDENTITY(1,1) NOT NULL,
    [AllocBatchNo] bigint NOT NULL,
    [Priority] int NOT NULL DEFAULT ((9)),
    [Facility] nvarchar(5) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [StrategyKey] nvarchar(20) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [TotalOrders] int NOT NULL DEFAULT ((0)),
    [TotalQty] int NOT NULL DEFAULT ((0)),
    [TaskSeqNo] int NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_AutoAllocBatchJob] PRIMARY KEY ([RowID])
);
GO

CREATE INDEX [IDX_AutoAllocBatchJob_AllocBatchNo] ON [dbo].[autoallocbatchjob] ([AllocBatchNo], [Status]);
GO
CREATE INDEX [IDX_AutoAllocBatchJob_FacilityStorerKeySku] ON [dbo].[autoallocbatchjob] ([Facility], [Storerkey], [SKU]);
GO
CREATE INDEX [IDX_AutoAllocBatchJob_StorerKeySkuStatus] ON [dbo].[autoallocbatchjob] ([Storerkey], [SKU], [Status]);
GO