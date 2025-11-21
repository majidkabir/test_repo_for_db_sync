CREATE TABLE [dbo].[vasdetail]
(
    [VASKey] nvarchar(10) NOT NULL,
    [VASLineNumber] nvarchar(5) NOT NULL,
    [RefDescr] nvarchar(5) NULL,
    [Step] nvarchar(128) NOT NULL DEFAULT (' '),
    [UserDefine01] nvarchar(30) NULL,
    [UserDefine02] nvarchar(30) NULL,
    [UserDefine03] nvarchar(30) NULL,
    [UserDefine04] nvarchar(30) NULL,
    [UserDefine05] nvarchar(30) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(18) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(18) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_VASDetail] PRIMARY KEY ([VASKey], [VASLineNumber])
);
GO
