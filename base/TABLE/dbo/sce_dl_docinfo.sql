CREATE TABLE [dbo].[sce_dl_docinfo]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [TableName] nvarchar(20) NULL,
    [Key1] nvarchar(20) NULL,
    [Key2] nvarchar(20) NULL,
    [Key3] nvarchar(20) NULL,
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [LineSeq] int NULL,
    [Data] nvarchar(4000) NULL DEFAULT (''),
    [DataType] nvarchar(10) NULL DEFAULT (''),
    [StoredProc] nvarchar(200) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_DOCINFO] PRIMARY KEY ([RowRefNo])
);
GO
