CREATE TABLE [dbo].[wmsexpmbol]
(
    [ExternOrderkey] nvarchar(50) NOT NULL,
    [Consigneekey] nvarchar(15) NOT NULL,
    [ExternLineNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [OriginalQty] int NOT NULL,
    [ShippedQty] int NOT NULL,
    [Shortqty] int NULL,
    [TRANSFLAG] nvarchar(1) NOT NULL,
    [MBOLKey] nvarchar(10) NOT NULL,
    [AddDate] datetime NULL,
    [EditDate] datetime NULL,
    [TotalCarton] int NULL DEFAULT ((0)),
    [StorerKey] nvarchar(15) NULL DEFAULT (' ')
);
GO

CREATE INDEX [IDX_WMSEXPMBOL_TransFlag] ON [dbo].[wmsexpmbol] ([TRANSFLAG]);
GO
CREATE UNIQUE INDEX [WMSEXPMBOL_Index_1] ON [dbo].[wmsexpmbol] ([ExternOrderkey], [ExternLineNo]);
GO