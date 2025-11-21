CREATE TABLE [dbo].[autoallocbatch_log]
(
    [AllocBatchNo] bigint NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [BuildParmGroup] nvarchar(30) NOT NULL DEFAULT (''),
    [BuildParmCode] nvarchar(10) NOT NULL DEFAULT (''),
    [BuildParmString] nvarchar(MAX) NOT NULL DEFAULT (''),
    [StrategyKey] nvarchar(20) NOT NULL DEFAULT (''),
    [Duration] nvarchar(12) NOT NULL DEFAULT (''),
    [TotalOrderCnt] int NOT NULL DEFAULT ((0)),
    [Priority] int NULL DEFAULT ((0)),
    [UDF01] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF02] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF03] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF04] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF05] nvarchar(30) NOT NULL DEFAULT (''),
    [Status] nvarchar(30) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_AutoAllocBatch_Log] PRIMARY KEY ([AllocBatchNo])
);
GO
