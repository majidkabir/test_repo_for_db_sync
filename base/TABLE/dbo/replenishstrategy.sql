CREATE TABLE [dbo].[replenishstrategy]
(
    [ReplenishStrategykey] nvarchar(10) NOT NULL DEFAULT (''),
    [Descr] nvarchar(60) NOT NULL DEFAULT (''),
    [Type] nvarchar(20) NOT NULL DEFAULT (''),
    [Remarks] nvarchar(200) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_REPLENISHSTRATEGY] PRIMARY KEY ([ReplenishStrategykey])
);
GO
