CREATE TABLE [dbo].[masterairwaybilldetail]
(
    [MAWBKEY] nvarchar(15) NOT NULL,
    [MAWBLineNumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [HAWBKEY] nvarchar(15) NOT NULL DEFAULT (' '),
    [NumberOfPieces] int NOT NULL DEFAULT ((1)),
    [GrossWeight] float NOT NULL DEFAULT ((0)),
    [UOMWeight] nvarchar(10) NOT NULL DEFAULT (' '),
    [RateClass] nvarchar(10) NOT NULL DEFAULT (' '),
    [Sku] nvarchar(20) NOT NULL DEFAULT (' '),
    [SkuDescription] nvarchar(45) NOT NULL DEFAULT (' '),
    [ChargeableWeight] float NOT NULL DEFAULT ((0)),
    [Rate] float NOT NULL DEFAULT ((0)),
    [Extension] float NOT NULL DEFAULT ((0)),
    [UOMVolume] nvarchar(10) NOT NULL DEFAULT (' '),
    [Length] float NOT NULL DEFAULT ((0)),
    [Width] float NOT NULL DEFAULT ((0)),
    [Height] float NOT NULL DEFAULT ((0)),
    [Notes] nvarchar(4000) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] timestamp NULL,
    CONSTRAINT [PKMasterAirWayBillDetail] PRIMARY KEY ([MAWBKEY], [MAWBLineNumber])
);
GO
