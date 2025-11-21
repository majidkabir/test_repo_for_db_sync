CREATE TABLE [rdt].[rdteventlogdetail]
(
    [EventLogID] int NULL DEFAULT ((0)),
    [RowRef] int NULL DEFAULT ((0)),
    [Facility] nvarchar(5) NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NULL DEFAULT (''),
    [SKU] nvarchar(20) NULL DEFAULT (''),
    [UOM] nvarchar(10) NULL DEFAULT (''),
    [QTY] int NULL DEFAULT ((0)),
    [DocRefNo] nvarchar(20) NULL DEFAULT (''),
    [AddDate] datetime NULL,
    [ArchiveCop] nvarchar(1) NULL DEFAULT (''),
    CONSTRAINT [FK_RDTEventLogDetail_RowRef] FOREIGN KEY ([RowRef]) REFERENCES [RDT].[RDTEventLog] ([RowRef])
);
GO
