CREATE TABLE [dbo].[sce_dl_codelkup_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [LISTNAME] nvarchar(10) NULL,
    [Code] nvarchar(30) NULL,
    [Description] nvarchar(250) NULL,
    [Short] nvarchar(10) NULL,
    [Long] nvarchar(250) NULL,
    [Notes] nvarchar(4000) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Notes2] nvarchar(4000) NULL,
    [Storerkey] nvarchar(15) NULL DEFAULT (' '),
    [UDF01] nvarchar(60) NULL,
    [UDF02] nvarchar(60) NULL,
    [UDF03] nvarchar(60) NULL,
    [UDF04] nvarchar(60) NULL,
    [UDF05] nvarchar(60) NULL,
    [code2] nvarchar(30) NULL,
    CONSTRAINT [PK_SCE_DL_CODELKUP_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_CODELKUP_STG_Idx01] ON [dbo].[sce_dl_codelkup_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_CODELKUP_STG_Idx02] ON [dbo].[sce_dl_codelkup_stg] ([STG_BatchNo], [STG_SeqNo]);
GO