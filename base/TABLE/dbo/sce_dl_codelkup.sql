CREATE TABLE [dbo].[sce_dl_codelkup]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [LISTNAME] nvarchar(10) NOT NULL,
    [Code] nvarchar(30) NOT NULL,
    [Description] nvarchar(250) NULL,
    [Short] nvarchar(10) NULL,
    [Long] nvarchar(250) NULL,
    [Notes] nvarchar(4000) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Notes2] nvarchar(4000) NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [UDF01] nvarchar(60) NULL,
    [UDF02] nvarchar(60) NULL,
    [UDF03] nvarchar(60) NULL,
    [UDF04] nvarchar(60) NULL,
    [UDF05] nvarchar(60) NULL,
    [code2] nvarchar(30) NULL,
    CONSTRAINT [PK_SCE_DL_CODELKUP] PRIMARY KEY ([RowRefNo])
);
GO
