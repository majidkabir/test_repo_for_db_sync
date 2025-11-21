CREATE TABLE [dbo].[gwptrack]
(
    [GiftCode] nvarchar(10) NOT NULL DEFAULT (''),
    [RefNo] nvarchar(50) NOT NULL DEFAULT (''),
    [GiftFlag] nvarchar(5) NOT NULL DEFAULT (''),
    [Status] nvarchar(5) NOT NULL DEFAULT ('0'),
    [Sku] nvarchar(30) NOT NULL DEFAULT (''),
    [UPC] nvarchar(30) NOT NULL DEFAULT (''),
    [GiftDetail] nvarchar(100) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ('0'),
    [ReceivedQty] int NOT NULL DEFAULT ('0'),
    [Price] nvarchar(20) NOT NULL DEFAULT (''),
    [Source] nvarchar(20) NOT NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_GWPTrack] PRIMARY KEY ([GiftCode], [RefNo], [GiftFlag])
);
GO

CREATE INDEX [IX_GWPTrack_RefNo] ON [dbo].[gwptrack] ([RefNo]);
GO