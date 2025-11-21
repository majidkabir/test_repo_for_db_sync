CREATE TABLE [dbo].[rfputawaynmv]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [FromLOC] nvarchar(10) NOT NULL,
    [FromID] nvarchar(18) NOT NULL,
    [SuggestedLOC] nvarchar(10) NOT NULL,
    [Func] int NOT NULL DEFAULT ((0)),
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_RFPutawayNMV] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_RFPutawayNMV_SuggestedLOC] ON [dbo].[rfputawaynmv] ([SuggestedLOC]);
GO