CREATE TABLE [dbo].[tmpermissionprofiledetail]
(
    [ProfileKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [ProfileLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [PermissionType] nvarchar(10) NOT NULL DEFAULT (' '),
    [AreaKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Permission] nvarchar(10) NOT NULL DEFAULT ('1'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_TaskManagerProfileDetail] PRIMARY KEY ([ProfileKey], [ProfileLineNumber])
);
GO
