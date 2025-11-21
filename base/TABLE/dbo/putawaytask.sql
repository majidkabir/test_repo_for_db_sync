CREATE TABLE [dbo].[putawaytask]
(
    [Transkey] nvarchar(10) NOT NULL,
    [TaskDetailKey] nvarchar(10) NULL,
    [ID] nvarchar(10) NULL,
    [SKU] nvarchar(20) NULL,
    [FromLoc] nvarchar(10) NULL,
    [ToLoc] nvarchar(10) NULL,
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_PutawayTask] PRIMARY KEY ([Transkey])
);
GO

CREATE INDEX [IX_PutawayTask] ON [dbo].[putawaytask] ([ID], [FromLoc], [ToLoc]);
GO
CREATE INDEX [IX_PutawayTask_1] ON [dbo].[putawaytask] ([ID], [SKU]);
GO