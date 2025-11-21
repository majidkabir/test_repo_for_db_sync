CREATE TABLE [dbo].[buildparmdetail]
(
    [BuildParmKey] nvarchar(10) NOT NULL DEFAULT (''),
    [BuildParmLineNo] nvarchar(5) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    [ConditionLevel] int NULL DEFAULT ((0)),
    [FieldName] nvarchar(100) NULL DEFAULT (''),
    [OrAnd] nvarchar(10) NULL DEFAULT (''),
    [Operator] nvarchar(60) NULL DEFAULT (''),
    [Value] nvarchar(4000) NULL DEFAULT (''),
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
    [BuildValue] nvarchar(4000) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_BUILDPARMDETAIL] PRIMARY KEY ([BuildParmKey], [BuildParmLineNo])
);
GO
