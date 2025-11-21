CREATE TABLE [dbo].[tpprintergroup]
(
    [TPPrinterGroup] nvarchar(20) NOT NULL,
    [PrinterPlatform] nvarchar(30) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [IPAddress] nvarchar(40) NOT NULL DEFAULT (''),
    [PortNo] nvarchar(5) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_TPPRINTERGROUP] PRIMARY KEY ([TPPrinterGroup], [PrinterPlatform])
);
GO
