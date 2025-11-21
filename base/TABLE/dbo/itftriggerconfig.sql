CREATE TABLE [dbo].[itftriggerconfig]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (' '),
    [ConfigKey] nvarchar(30) NOT NULL,
    [Tablename] nvarchar(30) NOT NULL,
    [RecordType] nvarchar(10) NOT NULL DEFAULT (' '),
    [RecordStatus] nvarchar(10) NOT NULL DEFAULT (' '),
    [sValue] nvarchar(10) NOT NULL DEFAULT (' '),
    [SourceTable] nvarchar(60) NOT NULL,
    [TargetTable] nvarchar(60) NOT NULL,
    [StoredProc] nvarchar(200) NOT NULL DEFAULT (' '),
    [UpdatedColumns] nvarchar(250) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [QCommanderSP] nvarchar(1024) NULL DEFAULT (' '),
    CONSTRAINT [PKITFTriggerConfig] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IDX_ITFTriggerConfig_CIdx] ON [dbo].[itftriggerconfig] ([StorerKey], [Facility], [ConfigKey], [Tablename], [SourceTable]);
GO
CREATE INDEX [IX_ITFTRIGGERCONFIG_SOURCETABLE] ON [dbo].[itftriggerconfig] ([SourceTable], [StorerKey], [sValue]);
GO