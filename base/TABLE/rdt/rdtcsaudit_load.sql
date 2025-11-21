CREATE TABLE [rdt].[rdtcsaudit_load]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [GroupID] int NOT NULL DEFAULT ((0)),
    [Vehicle] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ConsigneeKey] nvarchar(15) NULL,
    [CaseID] nvarchar(18) NOT NULL,
    [Seal] nvarchar(20) NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [RefNo1] nvarchar(20) NULL,
    [RefNo2] nvarchar(20) NULL,
    [RefNo3] nvarchar(20) NULL,
    [RefNo4] nvarchar(20) NULL,
    [RefNo5] nvarchar(20) NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TripID] int NOT NULL DEFAULT ((0)),
    [CloseWho] nvarchar(18) NOT NULL DEFAULT (' '),
    [CloseDate] datetime NULL,
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKRDTCSAudit_Load] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [Idx_RDTCSAudit_Load_GroupID] ON [rdt].[rdtcsaudit_load] ([GroupID]);
GO
CREATE INDEX [Idx_RDTCSAudit_Load_StorerKey_ConsigneeKey] ON [rdt].[rdtcsaudit_load] ([StorerKey], [ConsigneeKey]);
GO
CREATE INDEX [Idx_RDTCSAudit_Load_Vehicle_CaseID] ON [rdt].[rdtcsaudit_load] ([Vehicle], [CaseID]);
GO