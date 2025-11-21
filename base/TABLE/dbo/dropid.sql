CREATE TABLE [dbo].[dropid]
(
    [Dropid] nvarchar(20) NOT NULL DEFAULT (''),
    [Droploc] nvarchar(10) NOT NULL DEFAULT (' '),
    [AdditionalLoc] nvarchar(30) NOT NULL DEFAULT (' '),
    [DropIDType] nvarchar(10) NOT NULL DEFAULT ('0'),
    [LabelPrinted] nvarchar(10) NOT NULL DEFAULT ('0'),
    [ManifestPrinted] nvarchar(10) NOT NULL DEFAULT ('0'),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Loadkey] nvarchar(10) NULL DEFAULT (' '),
    [PickSlipNo] nvarchar(10) NULL DEFAULT (' '),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PKDropid] PRIMARY KEY ([Dropid])
);
GO

CREATE INDEX [IDX_DROPID_LoadKey] ON [dbo].[dropid] ([Loadkey]);
GO
CREATE INDEX [IDX_DROPID_PickSlipNo] ON [dbo].[dropid] ([PickSlipNo]);
GO
CREATE INDEX [IX_DropID_DropLOC] ON [dbo].[dropid] ([Droploc]);
GO