CREATE TABLE [rdt].[rdtstdeventloglookup]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Category] nvarchar(30) NOT NULL DEFAULT (''),
    [CategoryDescr] nvarchar(60) NULL DEFAULT (''),
    [SubCategory] nvarchar(30) NULL DEFAULT (''),
    [SubCategoryDescr] nvarchar(60) NULL DEFAULT (''),
    [FunctionID] int NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtSTDEventLogLookUp] PRIMARY KEY ([RowRef])
);
GO
