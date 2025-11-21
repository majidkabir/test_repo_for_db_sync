CREATE TABLE [dbo].[stocktakeparmstrategy]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [StockTakeKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [Loc] nvarchar(10) NOT NULL DEFAULT (''),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_STOCKTAKEPARMSTRATEGY] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IDX_STOCKTAKEPARMSTRATEGY_Sku] ON [dbo].[stocktakeparmstrategy] ([StockTakeKey], [Loc]);
GO
CREATE INDEX [IDX_STOCKTAKEPARMSTRATEGY_SkuxLoc] ON [dbo].[stocktakeparmstrategy] ([StockTakeKey], [Storerkey], [Sku], [Loc]);
GO