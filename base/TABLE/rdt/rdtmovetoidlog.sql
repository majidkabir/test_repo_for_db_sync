CREATE TABLE [rdt].[rdtmovetoidlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [ToID] nvarchar(18) NOT NULL DEFAULT (''),
    [FromLOT] nvarchar(10) NOT NULL DEFAULT (''),
    [FromLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [FromID] nvarchar(18) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [QTY] int NOT NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_name()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [UCC] nvarchar(20) NOT NULL DEFAULT (''),
    [SerialNo] nvarchar(30) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_rdtMoveToIDLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtMoveToIDLog_StorerKey_ToID] ON [rdt].[rdtmovetoidlog] ([StorerKey], [ToID]);
GO