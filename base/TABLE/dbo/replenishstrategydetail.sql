CREATE TABLE [dbo].[replenishstrategydetail]
(
    [ReplenishStrategykey] nvarchar(10) NOT NULL DEFAULT (''),
    [ReplenishStrategyLineNumber] nvarchar(5) NOT NULL DEFAULT (''),
    [Descr] nvarchar(60) NOT NULL DEFAULT (''),
    [UOM] nvarchar(10) NOT NULL DEFAULT (''),
    [ReplenCode] nvarchar(500) NOT NULL DEFAULT (''),
    [StrategyType] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_REPLENISHSTRATEGYDETAIL] PRIMARY KEY ([ReplenishStrategykey], [ReplenishStrategyLineNumber])
);
GO
