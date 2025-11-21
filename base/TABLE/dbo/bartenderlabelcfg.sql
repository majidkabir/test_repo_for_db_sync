CREATE TABLE [dbo].[bartenderlabelcfg]
(
    [LabelSerialNo] int IDENTITY(1,1) NOT NULL,
    [LabelType] nvarchar(30) NOT NULL,
    [Key01] nvarchar(60) NOT NULL DEFAULT (''),
    [Key02] nvarchar(60) NOT NULL DEFAULT (''),
    [Key03] nvarchar(60) NOT NULL DEFAULT (''),
    [Key04] nvarchar(60) NOT NULL DEFAULT (''),
    [Key05] nvarchar(60) NOT NULL DEFAULT (''),
    [TemplatePath] nvarchar(1000) NOT NULL DEFAULT (''),
    [StoreProcedure] nvarchar(1000) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [FilePath] nvarchar(1000) NOT NULL DEFAULT (''),
    [LOGFILE] nvarchar(1) NOT NULL DEFAULT ('N'),
    [Field01] nvarchar(100) NULL,
    [Field02] nvarchar(100) NULL,
    [Field03] nvarchar(100) NULL,
    [BTPrinterID] nvarchar(10) NULL,
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ZPLPRINTING] nvarchar(2) NULL DEFAULT ('0'),
    CONSTRAINT [PK_BartenderLabelCfg] PRIMARY KEY ([LabelSerialNo])
);
GO
