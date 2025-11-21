CREATE TABLE [dbo].[taskmanageruserdetail]
(
    [UserKey] nvarchar(18) NOT NULL DEFAULT (' '),
    [UserLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [PermissionType] nvarchar(10) NOT NULL DEFAULT (' '),
    [AreaKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Permission] nvarchar(10) NOT NULL DEFAULT ('1'),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_TaskManagerUserDetail] PRIMARY KEY ([UserKey], [UserLineNumber])
);
GO

CREATE INDEX [IXTaskManagerUserDetail_Area] ON [dbo].[taskmanageruserdetail] ([AreaKey]);
GO