CREATE TABLE [rdt].[rdtsortcaselock]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LoadKey] nvarchar(10) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [OptimizeCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdtSortCaseLock] PRIMARY KEY ([RowRef])
);
GO
