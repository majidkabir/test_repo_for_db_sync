CREATE TABLE [rdt].[rdtspoolerlog]
(
    [RowID] bigint IDENTITY(1,1) NOT NULL,
    [JobId] int NULL,
    [Notes] nvarchar(250) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdt.rdtSpoolerLog] PRIMARY KEY ([RowID])
);
GO
