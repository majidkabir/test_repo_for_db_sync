CREATE TABLE [dbo].[taskmanageruserdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [UserKey] nvarchar(18) NOT NULL DEFAULT (' '),
    [UserLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_taskmanageruserdetail_dellog] PRIMARY KEY ([Rowref])
);
GO
