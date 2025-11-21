CREATE TABLE [dbo].[rfputaway]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [SuggestedLoc] nvarchar(10) NOT NULL,
    [Id] nvarchar(18) NULL,
    [ptcid] nvarchar(18) NOT NULL,
    [qty] int NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [CaseID] nvarchar(20) NOT NULL DEFAULT (''),
    [FromID] nvarchar(18) NOT NULL DEFAULT (''),
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [TaskDetailKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Func] int NOT NULL DEFAULT ((0)),
    [PABookingKey] int NOT NULL DEFAULT ((0)),
    [QTYPrinted] int NOT NULL DEFAULT ((0)),
    [EditDate] datetime NULL,
    [EditWho] nvarchar(128) NULL,
    [Receiptkey] nvarchar(10) NULL DEFAULT (''),
    [ReceiptLineNumber] nvarchar(5) NULL DEFAULT (''),
    [UDF01] nvarchar(60) NULL DEFAULT (''),
    [UDF02] nvarchar(60) NULL DEFAULT (''),
    [UDF03] nvarchar(60) NULL DEFAULT (''),
    CONSTRAINT [PK_RFPutaway] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_RFPutaway_01] ON [dbo].[rfputaway] ([ptcid], [Sku], [SuggestedLoc]);
GO
CREATE INDEX [IX_RFPutaway_SKUFROMLOC] ON [dbo].[rfputaway] ([Sku], [FromLoc]);
GO