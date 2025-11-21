CREATE TABLE [rdt].[rdtpafswaptasklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [FromTaskKey] nvarchar(10) NOT NULL,
    [FromLOC] nvarchar(10) NOT NULL,
    [FromID] nvarchar(18) NOT NULL,
    [NewTaskKey] nvarchar(10) NOT NULL,
    [NewFromLOC] nvarchar(10) NOT NULL,
    [NewFromID] nvarchar(18) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPAFSwapTaskLog] PRIMARY KEY ([RowRef])
);
GO
