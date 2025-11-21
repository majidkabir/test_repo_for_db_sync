CREATE TABLE [rdt].[rdttmlog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [UserName] nvarchar(128) NULL DEFAULT (''),
    [TaskUserName] nvarchar(15) NULL DEFAULT (''),
    [MobileNo] int NULL DEFAULT ((0)),
    [AreaKey] nvarchar(10) NULL DEFAULT (''),
    [TaskType] nvarchar(10) NULL DEFAULT (''),
    [PrevTaskdetailkey] nvarchar(10) NULL DEFAULT (''),
    [Taskdetailkey] nvarchar(10) NULL DEFAULT (''),
    [PrevStatus] nvarchar(10) NULL DEFAULT (''),
    [CurrStatus] nvarchar(10) NULL DEFAULT (''),
    [Func] int NULL DEFAULT ((0)),
    [Scn] int NULL DEFAULT ((0)),
    [Step] int NULL DEFAULT ((0)),
    [DateTime] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtTMLog] PRIMARY KEY ([RowRef])
);
GO
