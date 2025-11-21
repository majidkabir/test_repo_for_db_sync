CREATE TABLE [dbo].[dropiddetail]
(
    [Dropid] nvarchar(20) NOT NULL DEFAULT (''),
    [ChildId] nvarchar(20) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [LabelPrinted] nvarchar(10) NULL DEFAULT (''),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    CONSTRAINT [PKDropidDetail] PRIMARY KEY ([Dropid], [ChildId])
);
GO

CREATE INDEX [IX_DropIDDetail_ChildID] ON [dbo].[dropiddetail] ([ChildId]);
GO