CREATE TABLE [dbo].[workorderpackets]
(
    [WkOrdPacketsKey] nvarchar(10) NOT NULL DEFAULT (''),
    [MasterWorkOrder] nvarchar(50) NULL DEFAULT (''),
    [WorkOrderName] nvarchar(50) NULL DEFAULT (''),
    [FileName] nvarchar(255) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_WorkOrderPackets] PRIMARY KEY ([WkOrdPacketsKey])
);
GO

CREATE INDEX [IX_WorkOrderPackets] ON [dbo].[workorderpackets] ([MasterWorkOrder], [WorkOrderName]);
GO