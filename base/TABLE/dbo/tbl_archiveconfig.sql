CREATE TABLE [dbo].[tbl_archiveconfig]
(
    [RowRefNo] int NOT NULL,
    [Arc_code] nvarchar(125) NOT NULL DEFAULT (''),
    [Arc_def_schedule] int NOT NULL DEFAULT ('0'),
    [Category] nvarchar(10) NULL DEFAULT ('WMS'),
    [Description] nvarchar(500) NULL,
    [Enabled] nvarchar(1) NOT NULL DEFAULT (''),
    [Type] int NOT NULL DEFAULT ('0'),
    [StoredProcedure] nvarchar(150) NOT NULL DEFAULT (''),
    [StoredProcedure2] nvarchar(150) NULL DEFAULT (''),
    [ArchiveKey] nvarchar(10) NULL DEFAULT (''),
    [SourceDB] nvarchar(20) NOT NULL DEFAULT (''),
    [ArchiveDB] nvarchar(20) NOT NULL DEFAULT (''),
    [TableSchema] nvarchar(5) NOT NULL DEFAULT ('dbo'),
    [SrcTableName] nvarchar(125) NOT NULL DEFAULT (''),
    [TgtTableName] nvarchar(128) NULL DEFAULT (''),
    [DateColumn] nvarchar(20) NOT NULL DEFAULT (''),
    [Threshold] int NOT NULL DEFAULT ('30'),
    [SQLCondition] nvarchar(4000) NULL DEFAULT (''),
    [Key1Name] nvarchar(128) NOT NULL DEFAULT (''),
    [Key2Name] nvarchar(128) NULL DEFAULT (''),
    [Key3Name] nvarchar(128) NULL DEFAULT (''),
    [Key4Name] nvarchar(128) NULL DEFAULT (''),
    [Key5Name] nvarchar(128) NULL DEFAULT (''),
    [Key6Name] nvarchar(128) NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    CONSTRAINT [PK_TBL_ArchiveConfig] PRIMARY KEY ([RowRefNo])
);
GO

CREATE UNIQUE INDEX [IDX_TBL_ArchiveConfig_ArcCode] ON [dbo].[tbl_archiveconfig] ([Arc_code], [Arc_def_schedule], [Type]);
GO