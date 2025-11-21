CREATE TABLE [dbo].[packtask]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [Orderkey] nvarchar(10) NOT NULL DEFAULT (''),
    [TaskBatchNo] nvarchar(10) NOT NULL DEFAULT (''),
    [DevicePosition] nvarchar(10) NOT NULL DEFAULT (''),
    [LogicalName] nvarchar(10) NOT NULL DEFAULT (''),
    [OrderMode] nvarchar(10) NOT NULL DEFAULT (''),
    [UDF01] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF02] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF03] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF04] nvarchar(30) NOT NULL DEFAULT (''),
    [UDF05] nvarchar(30) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [ReplenishmentGroup] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_packtask] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_PACKTASK_Orderkey] ON [dbo].[packtask] ([Orderkey]);
GO
CREATE INDEX [IDX_PACKTASK_TASKBATCHNO] ON [dbo].[packtask] ([TaskBatchNo], [Orderkey]);
GO