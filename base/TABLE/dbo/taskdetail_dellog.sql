CREATE TABLE [dbo].[taskdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_taskdetail_dellog] PRIMARY KEY ([Rowref])
);
GO
