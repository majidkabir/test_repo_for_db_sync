CREATE TABLE [dbo].[exg_filehdr]
(
    [file_key] int IDENTITY(1,1) NOT NULL,
    [EXG_Hdr_ID] int NOT NULL,
    [TargetFolder] nvarchar(200) NULL DEFAULT (''),
    [filename] nvarchar(255) NULL DEFAULT (''),
    [status] char(1) NOT NULL DEFAULT ((0)),
    [try] int NOT NULL DEFAULT ((0)),
    [ParamVal1] nvarchar(200) NULL DEFAULT (''),
    [ParamVal2] nvarchar(200) NULL DEFAULT (''),
    [ParamVal3] nvarchar(200) NULL DEFAULT (''),
    [ParamVal4] nvarchar(200) NULL DEFAULT (''),
    [ParamVal5] nvarchar(200) NULL DEFAULT (''),
    [ParamVal6] nvarchar(200) NULL DEFAULT (''),
    [ParamVal7] nvarchar(200) NULL DEFAULT (''),
    [ParamVal8] nvarchar(200) NULL DEFAULT (''),
    [ParamVal9] nvarchar(200) NULL DEFAULT (''),
    [ParamVal10] nvarchar(200) NULL DEFAULT (''),
    [Delimiter] nvarchar(2) NOT NULL,
    [RetryFlag] bit NULL DEFAULT ((0)),
    [AddWho] nvarchar(255) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(255) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_EXG_FileHdr] PRIMARY KEY ([file_key])
);
GO
