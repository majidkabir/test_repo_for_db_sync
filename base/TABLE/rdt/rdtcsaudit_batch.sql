CREATE TABLE [rdt].[rdtcsaudit_batch]
(
    [BatchID] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Batch] nvarchar(15) NOT NULL DEFAULT (''),
    [OpenWho] nvarchar(18) NOT NULL DEFAULT (suser_sname()),
    [OpenDate] datetime NOT NULL DEFAULT (getdate()),
    [CloseWho] nvarchar(18) NOT NULL DEFAULT (''),
    [CloseDate] datetime NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PKRDTCSAudit_BATCH] PRIMARY KEY ([BatchID])
);
GO

CREATE UNIQUE INDEX [Idx_RDTCSAudit_StorerKey_Batch] ON [rdt].[rdtcsaudit_batch] ([StorerKey], [Batch]);
GO