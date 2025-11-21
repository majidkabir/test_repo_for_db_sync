CREATE TABLE [dbo].[codelkup_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [LISTNAME] nvarchar(10) NOT NULL,
    [Code] nvarchar(30) NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [code2] nvarchar(30) NOT NULL DEFAULT (''),
    [Description] nvarchar(250) NULL DEFAULT (''),
    [Short] nvarchar(10) NULL DEFAULT (''),
    [Long] nvarchar(250) NULL DEFAULT (''),
    [Notes] nvarchar(4000) NULL DEFAULT (''),
    [Notes2] nvarchar(4000) NULL DEFAULT (''),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    [UDF04] nvarchar(60) NULL DEFAULT (''),
    [UDF05] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PK_codelkup_dellog] PRIMARY KEY ([Rowref])
);
GO
