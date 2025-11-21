CREATE TABLE [dbo].[rdsorderdetailsize]
(
    [rdsOrderNo] int NOT NULL,
    [rdsOrderLineNo] nvarchar(10) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [Style] nvarchar(20) NOT NULL,
    [Color] nvarchar(10) NOT NULL,
    [Measurement] nvarchar(5) NOT NULL DEFAULT (''),
    [Size] nvarchar(5) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] nvarchar(1) NULL,
    [TrafficCop] nvarchar(1) NULL,
    CONSTRAINT [PK_rdsOrderDetailSize_1] PRIMARY KEY ([rdsOrderNo], [rdsOrderLineNo], [SKU])
);
GO
