CREATE TABLE [rdt].[rdtreporttoprinter]
(
    [Function_ID] int NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [ReportType] nvarchar(10) NOT NULL,
    [PrinterGroup] nvarchar(10) NOT NULL,
    [PrinterID] nvarchar(10) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ReportLineNo] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_rdtReportToPRinter] PRIMARY KEY ([Function_ID], [StorerKey], [ReportType], [PrinterGroup], [ReportLineNo])
);
GO
