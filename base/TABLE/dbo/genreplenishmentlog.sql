CREATE TABLE [dbo].[genreplenishmentlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [ReplenishStrategykey] nvarchar(10) NOT NULL DEFAULT (''),
    [GenParmString] nvarchar(4000) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_GENREPLENISHMENTLOG] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_GENREPLENISHMENTLOG_Storerkey] ON [dbo].[genreplenishmentlog] ([Storerkey], [Facility]);
GO