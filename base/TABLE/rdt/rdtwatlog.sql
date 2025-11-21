CREATE TABLE [rdt].[rdtwatlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Module] nvarchar(10) NOT NULL,
    [UserName] nvarchar(128) NOT NULL,
    [Location] nvarchar(30) NOT NULL DEFAULT (''),
    [StartDate] datetime NOT NULL DEFAULT (getdate()),
    [TaskCode] nvarchar(20) NULL,
    [Description] nvarchar(40) NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [EndDate] datetime NOT NULL,
    [Comments] nvarchar(250) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [QTY] nvarchar(5) NOT NULL DEFAULT (''),
    [GroupKey] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKrdtWATLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_rdtWATLog_01] ON [rdt].[rdtwatlog] ([UserName], [Status], [Location]);
GO