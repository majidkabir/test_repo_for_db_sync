CREATE TABLE [dbo].[buildparm]
(
    [ParmGroup] nvarchar(30) NOT NULL DEFAULT (''),
    [BuildParmKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [Priority] nvarchar(10) NULL DEFAULT (''),
    [Strategy] nvarchar(60) NULL DEFAULT (''),
    [BatchSize] int NULL DEFAULT ((0)),
    [Active] nvarchar(10) NULL DEFAULT (''),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [Restriction01] nvarchar(30) NOT NULL DEFAULT (''),
    [Restriction02] nvarchar(30) NOT NULL DEFAULT (''),
    [Restriction03] nvarchar(30) NOT NULL DEFAULT (''),
    [Restriction04] nvarchar(30) NOT NULL DEFAULT (''),
    [Restriction05] nvarchar(30) NOT NULL DEFAULT (''),
    [RestrictionValue01] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionValue02] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionValue03] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionValue04] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionValue05] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionBuildValue01] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionBuildValue02] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionBuildValue03] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionBuildValue04] nvarchar(10) NOT NULL DEFAULT (''),
    [RestrictionBuildValue05] nvarchar(10) NOT NULL DEFAULT (''),
    [MaxDoc] int NOT NULL DEFAULT ((0)),
    [MaxOrder] int NOT NULL DEFAULT ((0)),
    [MaxQty] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_BUILDPARM] PRIMARY KEY ([BuildParmKey])
);
GO

CREATE INDEX [IDX_BUILDPARM] ON [dbo].[buildparm] ([ParmGroup], [BuildParmKey]);
GO