CREATE TABLE [dbo].[taskmanagerskiptasks]
(
    [USERID] nvarchar(128) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL,
    [TaskType] nvarchar(10) NOT NULL,
    [Caseid] nvarchar(20) NULL,
    [Lot] nvarchar(10) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [ToLoc] nvarchar(10) NOT NULL,
    [FromId] nvarchar(18) NOT NULL,
    [ToId] nvarchar(18) NOT NULL,
    [adddate] datetime NOT NULL DEFAULT (getdate())
);
GO

CREATE INDEX [IDX_TMSKIPTASKS_TASKDETAILKEY] ON [dbo].[taskmanagerskiptasks] ([TaskDetailKey]);
GO
CREATE INDEX [IDX_TMSKIPTASKS_USERID] ON [dbo].[taskmanagerskiptasks] ([USERID], [TaskDetailKey]);
GO
CREATE INDEX [TASKMANAGERSKIPTASKS_adddate] ON [dbo].[taskmanagerskiptasks] ([adddate]);
GO