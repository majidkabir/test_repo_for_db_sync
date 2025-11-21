CREATE TABLE [rdt].[rdtcsaudit]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [GroupID] int NOT NULL DEFAULT ((0)),
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL,
    [Workstation] nvarchar(15) NOT NULL,
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [Type] nvarchar(1) NOT NULL,
    [PalletID] nvarchar(18) NULL,
    [CaseID] nvarchar(18) NULL,
    [SKU] nvarchar(20) NULL,
    [Descr] nvarchar(60) NULL,
    [CountQTY_A] int NOT NULL DEFAULT ((0)),
    [CountQTY_B] int NOT NULL DEFAULT ((0)),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [RefNo1] nvarchar(20) NULL,
    [RefNo2] nvarchar(20) NULL,
    [RefNo3] nvarchar(20) NULL,
    [RefNo4] nvarchar(20) NULL,
    [RefNo5] nvarchar(20) NULL,
    [OriginalQTY] int NOT NULL DEFAULT ((0)),
    [AdjustedQTY] int NOT NULL DEFAULT ((0)),
    [AdjustReason] nvarchar(10) NULL,
    [AdjustWho] nvarchar(18) NULL,
    [AdjustDate] datetime NULL,
    [BatchID] int NOT NULL,
    CONSTRAINT [PKRDTCSAudit] PRIMARY KEY ([RowRef]),
    CONSTRAINT [CK_RDTCSAudit_01] CHECK ([Status]='0' OR [Status]='5' OR [Status]='9')
);
GO

CREATE INDEX [Idx_RDTCSAudit_BatchID] ON [rdt].[rdtcsaudit] ([BatchID]);
GO
CREATE INDEX [Idx_RDTCSAudit_GroupID] ON [rdt].[rdtcsaudit] ([GroupID]);
GO
CREATE INDEX [Idx_RDTCSAudit_PalletID_CaseID_SKU] ON [rdt].[rdtcsaudit] ([PalletID], [CaseID], [SKU]);
GO
CREATE INDEX [Idx_RDTCSAudit_StorerKey_Workstation_ConsigneeKey_Status] ON [rdt].[rdtcsaudit] ([StorerKey], [Workstation], [ConsigneeKey], [Status]);
GO