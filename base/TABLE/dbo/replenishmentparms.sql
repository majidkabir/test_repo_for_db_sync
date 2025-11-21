CREATE TABLE [dbo].[replenishmentparms]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [ReplenishStrategykey] nvarchar(10) NOT NULL DEFAULT (''),
    [ReplenishmentGroup] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone02] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone03] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone04] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone05] nvarchar(10) NOT NULL DEFAULT ((0)),
    [Zone06] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone07] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone08] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone09] nvarchar(10) NOT NULL DEFAULT (''),
    [Zone10] nvarchar(500) NULL DEFAULT (''),
    [Zone11] nvarchar(500) NULL DEFAULT (''),
    [Zone12] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_REPLENISHMENTPARMS] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_REPLENISHMENTPARMS_Storerkey] ON [dbo].[replenishmentparms] ([Storerkey], [Facility]);
GO