CREATE TABLE [dbo].[buildparmgroupcfg]
(
    [ParmGroupCfgID] bigint IDENTITY(1,1) NOT NULL,
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Type] nvarchar(30) NOT NULL DEFAULT (''),
    [ParmGroup] nvarchar(30) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [BuildDateField] nvarchar(50) NULL DEFAULT (''),
    CONSTRAINT [PK_BUILDPARMGROUPCFG] PRIMARY KEY ([ParmGroupCfgID])
);
GO

CREATE INDEX [IDX_BUILDPARMGROUPCFG] ON [dbo].[buildparmgroupcfg] ([Storerkey], [Facility], [Type], [ParmGroup]);
GO
CREATE UNIQUE INDEX [IDX_BUILDPARMGROUPCFG_UNIQ] ON [dbo].[buildparmgroupcfg] ([ParmGroup], [Storerkey], [Facility]);
GO