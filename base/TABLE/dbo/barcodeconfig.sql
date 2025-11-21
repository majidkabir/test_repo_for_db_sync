CREATE TABLE [dbo].[barcodeconfig]
(
    [DecodeCode] nvarchar(30) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Function_ID] int NOT NULL,
    [Sequence] int NOT NULL,
    [Description] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [AllowGap] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_BarcodeConfig] PRIMARY KEY ([DecodeCode]),
    CONSTRAINT [CK_BarcodeConfig_DecodeCode] CHECK ([DecodeCode]<>''),
    CONSTRAINT [CK_BarcodeConfig_StorerKey] CHECK ([StorerKey]<>'')
);
GO

CREATE UNIQUE INDEX [IX_BarcodeConfig_StorerKey_Function_ID_Sequence] ON [dbo].[barcodeconfig] ([StorerKey], [Function_ID], [Sequence]);
GO