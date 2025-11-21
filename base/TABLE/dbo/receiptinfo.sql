CREATE TABLE [dbo].[receiptinfo]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [EcomReceiveId] nvarchar(45) NOT NULL DEFAULT (''),
    [EcomOrderId] nvarchar(45) NOT NULL DEFAULT (''),
    [ReceiptAmount] float NOT NULL DEFAULT ((0)),
    [Notes] nvarchar(500) NOT NULL DEFAULT (''),
    [Notes2] nvarchar(500) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL DEFAULT (''),
    [ArchiveCop] nvarchar(1) NULL DEFAULT (''),
    [StoreName] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_receiptinfo] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IDX_ReceiptInfo_Receiptkey] ON [dbo].[receiptinfo] ([ReceiptKey]);
GO