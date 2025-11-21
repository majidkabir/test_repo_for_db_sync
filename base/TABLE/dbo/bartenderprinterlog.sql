CREATE TABLE [dbo].[bartenderprinterlog]
(
    [ID] int IDENTITY(1,1) NOT NULL,
    [SerialNo] nvarchar(30) NULL,
    [RowID] int NULL,
    [Field01] nvarchar(100) NOT NULL DEFAULT (''),
    [Field02] nvarchar(100) NOT NULL DEFAULT (''),
    [Field03] nvarchar(100) NOT NULL DEFAULT (''),
    [LogDate] datetime NULL DEFAULT (getdate()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_BartenderPrinterLog] PRIMARY KEY ([ID])
);
GO
