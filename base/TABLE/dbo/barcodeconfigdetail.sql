CREATE TABLE [dbo].[barcodeconfigdetail]
(
    [DecodeCode] nvarchar(30) NOT NULL,
    [DecodeLineNumber] nvarchar(5) NOT NULL,
    [Description] nvarchar(20) NOT NULL DEFAULT (''),
    [FieldIdentifier] nvarchar(10) NOT NULL DEFAULT (''),
    [LengthType] nvarchar(10) NOT NULL DEFAULT (''),
    [MaxLength] int NOT NULL DEFAULT ((0)),
    [TerminateChar] tinyint NOT NULL DEFAULT ((0)),
    [DataType] nvarchar(10) NOT NULL DEFAULT (''),
    [MapTo] nvarchar(30) NOT NULL DEFAULT (''),
    [FormatSP] nvarchar(50) NOT NULL DEFAULT (''),
    [ProcessSP] nvarchar(50) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [Type] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_BarcodeConfigDetail] PRIMARY KEY ([DecodeCode], [DecodeLineNumber]),
    CONSTRAINT [CK_BarcodeConfigDetail_LengthType] CHECK ([LengthType] = 'VARIABLE' OR [LengthType] = 'FIXED'),
    CONSTRAINT [CK_BarcodeConfigDetail_MaxLength] CHECK ([MaxLength]>(0)),
    CONSTRAINT [CK_BarcodeConfigDetail_DataType] CHECK ([DataType] = 'DECIMAL' OR [DataType] = 'INTEGER' OR [DataType] = 'DATE' OR [DataType] = 'STRING')
);
GO
