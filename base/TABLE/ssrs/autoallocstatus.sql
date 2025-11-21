CREATE TABLE [ssrs].[autoallocstatus]
(
    [Storerkey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Company] nvarchar(60) NULL,
    [Batched] int NULL DEFAULT ((0)),
    [NotSubmit] int NULL DEFAULT ((0)),
    [Allocated] int NULL DEFAULT ((0)),
    [PartialAlloc] int NULL DEFAULT ((0)),
    [NoStock] int NULL DEFAULT ((0)),
    [TotalOrders] int NULL DEFAULT ((0)),
    [TotalQTask] int NULL DEFAULT ((0)),
    [QTaskWIP] int NULL DEFAULT ((0)),
    [QTaskError] int NULL DEFAULT ((0)),
    [SafetyAllocOrders] int NULL DEFAULT ((0)),
    [SafetyAllocPerctg] int NULL DEFAULT ((0)),
    [AllocPerctg] int NULL DEFAULT ((0)),
    [AllocPriority] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_AutoAllocStatus] PRIMARY KEY ([Storerkey], [Facility])
);
GO
