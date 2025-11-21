CREATE TABLE [dbo].[receiptserialno_dellog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ReceiptSerialNoKey] bigint NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_ReceiptSerialNo_DELLOG] PRIMARY KEY ([RowRef])
);
GO
