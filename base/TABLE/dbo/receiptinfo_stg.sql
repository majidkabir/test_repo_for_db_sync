CREATE TABLE [dbo].[receiptinfo_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [ReceiptKey] nvarchar(10) NULL,
    [EcomReceiveId] nvarchar(45) NULL DEFAULT (''),
    [EcomOrderId] nvarchar(45) NULL DEFAULT (''),
    [ReceiptAmount] float NULL DEFAULT ((0)),
    [Notes] nvarchar(500) NULL DEFAULT (''),
    [Notes2] nvarchar(500) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL DEFAULT (''),
    [ArchiveCop] nvarchar(1) NULL DEFAULT (''),
    [StoreName] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_ReceiptInfo_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [ReceiptInfo_STG_Idx01] ON [dbo].[receiptinfo_stg] ([STG_BatchNo]);
GO
CREATE INDEX [ReceiptInfo_STG_Idx02] ON [dbo].[receiptinfo_stg] ([STG_BatchNo], [STG_SeqNo]);
GO