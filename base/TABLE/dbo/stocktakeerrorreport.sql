CREATE TABLE [dbo].[stocktakeerrorreport]
(
    [SeqNo] bigint IDENTITY(1,1) NOT NULL,
    [StockTakeKey] nvarchar(10) NOT NULL,
    [ErrorNo] nvarchar(10) NOT NULL,
    [Type] nvarchar(15) NOT NULL,
    [LineText] nvarchar(MAX) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_StockTakeErrorReport] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_StockTakeErrorReport] ON [dbo].[stocktakeerrorreport] ([StockTakeKey], [ErrorNo]);
GO