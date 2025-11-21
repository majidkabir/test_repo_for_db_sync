CREATE TABLE [rdt].[rdtconreceivelog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtConReceiveLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtConReceiveLog_ReceiptKey_Mobile] ON [rdt].[rdtconreceivelog] ([ReceiptKey], [Mobile]);
GO