CREATE TABLE [rdt].[rdtprinter]
(
    [PrinterID] nvarchar(10) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL,
    [WinPrinter] nvarchar(128) NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [PrinterGroup] nvarchar(20) NULL DEFAULT (''),
    [VoicePrinterNo] int NULL DEFAULT ((0)),
    [SpoolerGroup] nvarchar(20) NOT NULL DEFAULT (''),
    [SCEPrinterGroup] nvarchar(20) NOT NULL DEFAULT (''),
    [TPPrinterGroup] nvarchar(20) NULL DEFAULT (''),
    [CloudPrintClientID] nvarchar(100) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_RDTPrinter] PRIMARY KEY ([PrinterID])
);
GO

CREATE INDEX [IDX_RDTPrinter_PrinterGroup_PrinterID] ON [rdt].[rdtprinter] ([PrinterGroup], [PrinterID]);
GO