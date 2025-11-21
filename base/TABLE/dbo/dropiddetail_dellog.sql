CREATE TABLE [dbo].[dropiddetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [Dropid] nvarchar(20) NOT NULL,
    [ChildId] nvarchar(20) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_dropiddetail_dellog] PRIMARY KEY ([Rowref])
);
GO
