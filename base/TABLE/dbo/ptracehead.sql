CREATE TABLE [dbo].[ptracehead]
(
    [PTRACETYPE] nvarchar(30) NOT NULL,
    [PTRACEHEADKey] nvarchar(10) NOT NULL,
    [Userid] nvarchar(128) NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [ID] nvarchar(10) NULL,
    [PackKey] nvarchar(10) NOT NULL,
    [Qty] int NOT NULL,
    [PA_MultiProduct] int NULL,
    [PA_MultiLot] int NULL,
    [StartTime] datetime NULL,
    [EndTime] datetime NULL,
    [PA_LocsReviewed] int NULL,
    [PA_LocFound] nvarchar(10) NULL,
    CONSTRAINT [PKPTRACEHEAD] PRIMARY KEY ([PTRACEHEADKey])
);
GO
