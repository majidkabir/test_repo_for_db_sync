CREATE TABLE [rdt].[rdtmessage]
(
    [SeqNo] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NOT NULL,
    [Message] nvarchar(MAX) NULL,
    [MessageOut] nvarchar(MAX) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [InFunc] int NULL,
    [InScn] int NULL,
    [InStep] int NULL,
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    [HashValue] tinyint NOT NULL DEFAULT (abs(checksum(newid())%(256))),
    CONSTRAINT [PKRDTMESSAGE] PRIMARY KEY ([SeqNo])
);
GO

CREATE INDEX [IX_RDTMessage_HashValue] ON [rdt].[rdtmessage] ([HashValue], [SeqNo]);
GO