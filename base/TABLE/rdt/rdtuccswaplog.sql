CREATE TABLE [rdt].[rdtuccswaplog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [ReceiptKey] nvarchar(10) NOT NULL DEFAULT (''),
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [SKU] nvarchar(20) NOT NULL DEFAULT (''),
    [QTY] int NOT NULL DEFAULT (''),
    [ExternKey] nvarchar(20) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdtUCCSwapLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtUCCSwapLog_ReceiptKey_LOC_SKU_QTY] ON [rdt].[rdtuccswaplog] ([ReceiptKey], [LOC], [SKU], [QTY]);
GO