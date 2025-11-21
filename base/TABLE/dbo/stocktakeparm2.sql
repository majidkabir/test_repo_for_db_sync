CREATE TABLE [dbo].[stocktakeparm2]
(
    [StockTakeKey] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Tablename] nvarchar(30) NOT NULL,
    [Value] nvarchar(30) NOT NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Label01] nvarchar(60) NULL DEFAULT (' '),
    [Value01] nvarchar(30) NULL DEFAULT (' '),
    [Label02] nvarchar(60) NULL DEFAULT (' '),
    [Value02] nvarchar(30) NULL DEFAULT (' '),
    [Label03] nvarchar(60) NULL DEFAULT (' '),
    [Value03] nvarchar(30) NULL DEFAULT (' '),
    [Label04] nvarchar(60) NULL DEFAULT (' '),
    [Value04] nvarchar(30) NULL DEFAULT (' '),
    [Label05] nvarchar(60) NULL DEFAULT (' '),
    [Value05] nvarchar(30) NULL DEFAULT (' '),
    [Rowref] int IDENTITY(1,1) NOT NULL,
    CONSTRAINT [PK_stocktakeparm2] PRIMARY KEY ([Rowref])
);
GO

CREATE INDEX [IDX_StockTakeParm2_01] ON [dbo].[stocktakeparm2] ([StockTakeKey], [Storerkey], [Tablename], [Value]);
GO
CREATE INDEX [IX_stocktakeparm2_StockTakeKey] ON [dbo].[stocktakeparm2] ([StockTakeKey]);
GO