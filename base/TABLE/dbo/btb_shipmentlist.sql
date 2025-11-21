CREATE TABLE [dbo].[btb_shipmentlist]
(
    [BTB_ShipmentKey] nvarchar(10) NOT NULL,
    [BTB_ShipmentListNo] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [COO] nvarchar(20) NOT NULL DEFAULT (''),
    [BTBFNo] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nchar(1) NULL,
    [ArchiveCop] nchar(1) NULL,
    CONSTRAINT [PK_btb_shipmentlist] PRIMARY KEY ([BTB_ShipmentKey], [BTB_ShipmentListNo])
);
GO

CREATE INDEX [IDX_BTB_ShipmentList_COO] ON [dbo].[btb_shipmentlist] ([BTB_ShipmentKey], [BTB_ShipmentListNo], [Storerkey], [COO]);
GO