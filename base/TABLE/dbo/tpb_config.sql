CREATE TABLE [dbo].[tpb_config]
(
    [TPB_Key] int NOT NULL,
    [TPB_code] nvarchar(125) NOT NULL DEFAULT (''),
    [TPB_def_schedule] int NULL,
    [Category] nvarchar(50) NOT NULL DEFAULT (''),
    [Description] nvarchar(125) NULL,
    [Enabled] nchar(1) NOT NULL DEFAULT ('Y'),
    [SQL] nvarchar(4000) NULL,
    [SQLArgument] nvarchar(4000) NULL,
    [SQLCondition] nvarchar(1000) NULL,
    [LastRundate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [ADDDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [DataDuration] int NULL,
    CONSTRAINT [PK_tpb_config] PRIMARY KEY ([TPB_Key])
);
GO
