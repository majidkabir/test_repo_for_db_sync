CREATE TABLE [dbo].[wmsexpmbolbk]
(
    [ExternOrderkey] nvarchar(50) NOT NULL,
    [Consigneekey] nvarchar(15) NOT NULL,
    [ExternLineNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [OriginalQty] int NOT NULL,
    [ShippedQty] int NOT NULL,
    [Shortqty] int NULL,
    [TRANSFLAG] nvarchar(1) NOT NULL,
    [MBOLKey] nvarchar(10) NOT NULL
);
GO
