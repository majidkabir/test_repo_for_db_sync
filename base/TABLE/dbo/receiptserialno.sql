CREATE TABLE [dbo].[receiptserialno]
(
    [ReceiptSerialNoKey] bigint IDENTITY(1,1) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [ReceiptLineNumber] nvarchar(5) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [SerialNo] nvarchar(50) NULL,
    [QTYExpected] int NOT NULL,
    [QTY] int NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [UCCNo] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_ReceiptSerialNo] PRIMARY KEY ([ReceiptSerialNoKey])
);
GO

CREATE INDEX [IX_ReceiptSerialNo_ReceiptKey_ReceiptLineNumber] ON [dbo].[receiptserialno] ([ReceiptKey], [ReceiptLineNumber]);
GO
CREATE INDEX [IX_ReceiptSerialNo_SerialNo] ON [dbo].[receiptserialno] ([SerialNo]);
GO