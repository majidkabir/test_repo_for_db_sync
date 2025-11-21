CREATE TABLE [rdt].[rdtcsaudit_batchpo]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(10) NOT NULL,
    [Batch] nvarchar(15) NOT NULL,
    [PO_No] nvarchar(15) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKRDTCSAudit_BatchPO] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_RDTCSAudit_BatchPO] ON [rdt].[rdtcsaudit_batchpo] ([Batch], [PO_No], [OrderKey]);
GO
CREATE INDEX [IX_RDTCSAudit_BatchPO_Batch] ON [rdt].[rdtcsaudit_batchpo] ([Batch]);
GO