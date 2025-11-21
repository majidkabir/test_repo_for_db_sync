CREATE TABLE [dbo].[palletimage]
(
    [Receiptkey] nvarchar(10) NOT NULL DEFAULT (''),
    [PermitNo] nvarchar(18) NULL DEFAULT (''),
    [LotNo] nvarchar(18) NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Sku] nvarchar(20) NOT NULL DEFAULT (''),
    [Descr] nvarchar(60) NOT NULL DEFAULT (''),
    [UOM] nvarchar(10) NOT NULL DEFAULT (''),
    [QtyReceived] int NULL DEFAULT ((0)),
    [ReceiptDate] datetime NOT NULL DEFAULT (''),
    [ImageUrl01] nvarchar(150) NOT NULL DEFAULT (''),
    [ImageUrl02] nvarchar(150) NOT NULL DEFAULT (''),
    [ImageUrl03] nvarchar(150) NOT NULL DEFAULT (''),
    [ImageUrl04] nvarchar(150) NOT NULL DEFAULT (''),
    [ImageUrl05] nvarchar(150) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL
);
GO

CREATE INDEX [IX_PALLETIMAGE_Adddate] ON [dbo].[palletimage] ([AddDate], [ID]);
GO
CREATE INDEX [IX_PALLETIMAGE_LotNo] ON [dbo].[palletimage] ([LotNo], [ID]);
GO
CREATE INDEX [IX_PALLETIMAGE_PermitNo] ON [dbo].[palletimage] ([PermitNo], [ID]);
GO
CREATE INDEX [IX_PALLETIMAGE_ReceiptDate] ON [dbo].[palletimage] ([ReceiptDate], [ID]);
GO
CREATE INDEX [IX_PALLETIMAGE_Receiptkey] ON [dbo].[palletimage] ([Receiptkey], [LotNo], [ID]);
GO