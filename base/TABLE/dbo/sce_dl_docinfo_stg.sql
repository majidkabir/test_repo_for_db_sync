CREATE TABLE [dbo].[sce_dl_docinfo_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [TableName] nvarchar(20) NULL,
    [Key1] nvarchar(20) NULL,
    [Key2] nvarchar(20) NULL,
    [Key3] nvarchar(20) NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [LineSeq] int NULL,
    [Data] nvarchar(4000) NULL DEFAULT (''),
    [DataType] nvarchar(10) NULL DEFAULT (''),
    [StoredProc] nvarchar(200) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_DOCINFO_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_DOCINFO_STG_Idx01] ON [dbo].[sce_dl_docinfo_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_DOCINFO_STG_Idx02] ON [dbo].[sce_dl_docinfo_stg] ([STG_BatchNo], [STG_SeqNo]);
GO