CREATE TABLE [api].[appprinter]
(
    [APPName] nvarchar(30) NOT NULL DEFAULT (''),
    [Workstation] nvarchar(30) NOT NULL DEFAULT (''),
    [PrinterID] nvarchar(20) NOT NULL DEFAULT (''),
    [PrinterType] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_AppPrinter] PRIMARY KEY ([Workstation], [PrinterID])
);
GO
