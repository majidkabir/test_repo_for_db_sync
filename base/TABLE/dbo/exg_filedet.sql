CREATE TABLE [dbo].[exg_filedet]
(
    [file_key] int NOT NULL,
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [EXG_Hdr_ID] int NOT NULL,
    [FileName] nvarchar(255) NULL DEFAULT (''),
    [SheetName] nvarchar(125) NULL DEFAULT (''),
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [LineText1] nvarchar(MAX) NULL DEFAULT (''),
    [LineText2] nvarchar(MAX) NULL DEFAULT (''),
    [ErrMsg] nvarchar(255) NULL,
    [AddWho] nvarchar(255) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(255) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_EXG_FileDet] PRIMARY KEY ([file_key], [SeqNo])
);
GO
