CREATE TABLE [dbo].[th_customerlotinfo]
(
    [CustomerLotInfoKey] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [SKU] nvarchar(20) NOT NULL DEFAULT (' '),
    [CustomerLot] nvarchar(50) NOT NULL DEFAULT (' '),
    [LineNumber] nvarchar(10) NOT NULL DEFAULT (' '),
    [Description] nvarchar(100) NULL DEFAULT (' '),
    [AreaUses] nvarchar(100) NULL DEFAULT (' '),
    [Directions] nvarchar(100) NULL DEFAULT (' '),
    [Warning] nvarchar(100) NULL DEFAULT (' '),
    [Qty] nvarchar(20) NULL DEFAULT (''),
    [ManufacturingDate] datetime NOT NULL DEFAULT (' '),
    [ExpiryDate] datetime NOT NULL DEFAULT (' '),
    [ProductDetail] nvarchar(100) NULL DEFAULT (' '),
    [FDACode] nvarchar(100) NULL DEFAULT (' '),
    [FDAExpiryDate] datetime NULL DEFAULT (' '),
    [StickerSize] nvarchar(100) NULL DEFAULT (' '),
    [VendorName] nvarchar(100) NULL DEFAULT (' '),
    [VendorAddress] nvarchar(100) NULL DEFAULT (' '),
    [VendorCountry] nvarchar(100) NULL DEFAULT (' '),
    [LocationName] nvarchar(100) NULL DEFAULT (' '),
    [LocationAddress] nvarchar(100) NULL DEFAULT (' '),
    [LocationAddress2] nvarchar(100) NULL DEFAULT (' '),
    [LocationAddress3] nvarchar(100) NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKTH_CustomerLotInfo] PRIMARY KEY ([CustomerLotInfoKey])
);
GO

CREATE INDEX [IDX_TH_CustomerLotInfo_CustomerLot] ON [dbo].[th_customerlotinfo] ([StorerKey], [SKU], [CustomerLot]);
GO