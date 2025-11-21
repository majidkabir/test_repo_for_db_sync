CREATE TABLE [dbo].[voiceconfig]
(
    [ModuleNo] int NOT NULL,
    [ProfileNo] int NOT NULL,
    [ParameterCode] nvarchar(30) NOT NULL,
    [ParameterLineNo] int NOT NULL,
    [ParameterDescr] nvarchar(60) NOT NULL DEFAULT (''),
    [ParameterValue] nvarchar(50) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(20) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(20) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_VoiceConfig] PRIMARY KEY ([ModuleNo], [ProfileNo], [ParameterCode])
);
GO
