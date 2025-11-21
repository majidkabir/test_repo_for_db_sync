CREATE TABLE [dbo].[gtmtask]
(
    [SeqNo] int NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [TaskType] nvarchar(10) NOT NULL,
    [PalletID] nvarchar(18) NOT NULL,
    [Priority] nvarchar(10) NOT NULL,
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [WorkStation] nvarchar(10) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT (''),
    [ErrMsg] nvarchar(255) NOT NULL DEFAULT (''),
    [FromLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [ToLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [FinalLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [LogicalFromLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [LogicalToLoc] nvarchar(10) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_GTMTask] PRIMARY KEY ([TaskDetailKey])
);
GO
