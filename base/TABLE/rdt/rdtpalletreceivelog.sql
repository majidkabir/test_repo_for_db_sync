CREATE TABLE [rdt].[rdtpalletreceivelog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtPalletReceiveLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtPalletReceiveLog_ReceiptKey_Mobile] ON [rdt].[rdtpalletreceivelog] ([ReceiptKey], [Mobile]);
GO