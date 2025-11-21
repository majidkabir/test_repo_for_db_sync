CREATE TABLE [rdt].[rdtsortandpackloc]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (''),
    [ConsigneeKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SortLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [OptimizeCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtSortAndPackLOC] PRIMARY KEY ([RowRef])
);
GO
