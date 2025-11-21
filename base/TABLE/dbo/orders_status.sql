CREATE TABLE [dbo].[orders_status]
(
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Facility] nvarchar(5) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT (' '),
    [OrderCnt] int NOT NULL,
    [Delivery_Flag] nvarchar(1) NULL,
    [Full_Fill] nvarchar(1) NULL,
    [OriginalQty] bigint NOT NULL,
    [ShippedQty] bigint NOT NULL,
    [EarlierDelivery] nvarchar(1) NULL,
    [Transmitflag] nvarchar(1) NULL DEFAULT ('0')
);
GO

CREATE INDEX [IX_ORDERS_STATUS] ON [dbo].[orders_status] ([Storerkey], [Facility]);
GO