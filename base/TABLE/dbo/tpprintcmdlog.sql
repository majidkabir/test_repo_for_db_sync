CREATE TABLE [dbo].[tpprintcmdlog]
(
    [JobNo] bigint NOT NULL,
    [CartonNo] int NOT NULL,
    [PrintCMD] nvarchar(MAX) NULL,
    [PrintServerIP] nvarchar(20) NULL,
    [PrintServerPort] nvarchar(5) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_TPPRINTCMDLOG] PRIMARY KEY ([JobNo], [CartonNo])
);
GO
