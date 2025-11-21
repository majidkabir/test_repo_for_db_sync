CREATE TABLE [dbo].[pickingvoice]
(
    [PickingVoiceKey] int IDENTITY(1,1) NOT NULL,
    [Pickslipno] nvarchar(10) NOT NULL DEFAULT (''),
    [UserID] nvarchar(128) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Orderkey] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [Pickdetailkey] nvarchar(18) NOT NULL,
    [LOC] nvarchar(10) NOT NULL,
    [QTY] int NOT NULL DEFAULT ((0)),
    [StartTime] datetime NOT NULL DEFAULT (getdate()),
    [EndTime] datetime NOT NULL DEFAULT (getdate()),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Source] nvarchar(20) NOT NULL DEFAULT (''),
    [SourceKey] nvarchar(20) NOT NULL DEFAULT (''),
    [BizType] nvarchar(20) NOT NULL DEFAULT (''),
    [BizStatus] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF01] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF02] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF03] nvarchar(20) NOT NULL DEFAULT (''),
    [UDF04] nvarchar(40) NOT NULL DEFAULT (''),
    [UDF05] nvarchar(40) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_PickingVoice] PRIMARY KEY ([PickingVoiceKey])
);
GO

CREATE INDEX [IDX_PickingVoice_OrderKey] ON [dbo].[pickingvoice] ([Orderkey], [Storerkey], [Facility]);
GO
CREATE INDEX [IDX_PickingVoice_PickDetailKey] ON [dbo].[pickingvoice] ([Pickdetailkey], [Storerkey], [Facility]);
GO
CREATE INDEX [IX_PickingVoice_Pickslipno] ON [dbo].[pickingvoice] ([Pickslipno], [UserID], [SKU], [LOC]);
GO