CREATE TABLE [rdt].[rdtprintergroup]
(
    [PrinterID] nvarchar(10) NOT NULL,
    [PrinterGroup] nvarchar(10) NOT NULL,
    [DefaultPrinter] int NOT NULL DEFAULT ((0)),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdtPrinterGroup] PRIMARY KEY ([PrinterGroup], [PrinterID])
);
GO
