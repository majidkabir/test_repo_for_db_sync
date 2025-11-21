CREATE TABLE [dbo].[kitdetail_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [KITKey] nvarchar(10) NOT NULL,
    [KITLineNumber] nvarchar(5) NOT NULL,
    [Type] nvarchar(5) NOT NULL DEFAULT ('F'),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_kitdetail_dellog] PRIMARY KEY ([Rowref])
);
GO
