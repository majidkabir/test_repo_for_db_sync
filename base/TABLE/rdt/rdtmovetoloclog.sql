CREATE TABLE [rdt].[rdtmovetoloclog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [FromLOC] nvarchar(10) NOT NULL,
    [FromID] nvarchar(18) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [QTY] int NOT NULL,
    [ToLOC] nvarchar(10) NOT NULL,
    [ToID] nvarchar(18) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtMoveToLOCLog] PRIMARY KEY ([RowRef])
);
GO
