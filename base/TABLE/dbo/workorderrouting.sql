CREATE TABLE [dbo].[workorderrouting]
(
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [MasterWorkOrder] nvarchar(50) NOT NULL DEFAULT (''),
    [WorkOrderName] nvarchar(50) NOT NULL DEFAULT (''),
    [Descr] nvarchar(80) NOT NULL DEFAULT (''),
    [WorkOrderType] nvarchar(20) NOT NULL DEFAULT (''),
    [WorkOrderRelease] nvarchar(30) NOT NULL DEFAULT (''),
    [WOReference] nvarchar(50) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [QAType] nvarchar(20) NOT NULL DEFAULT (''),
    [QAValue] int NOT NULL DEFAULT ((0)),
    [QALocation] nvarchar(10) NULL DEFAULT (''),
    [UDF1] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF2] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF3] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF4] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF5] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WorkOrderRouting] PRIMARY KEY ([WorkOrderName], [MasterWorkOrder])
);
GO
