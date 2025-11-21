CREATE TABLE [dbo].[otmidtrack]
(
    [MUID] int IDENTITY(1,1) NOT NULL,
    [TrackingNo] nvarchar(30) NULL,
    [CaseID] nvarchar(20) NULL,
    [PalletKey] nvarchar(30) NULL,
    [Principal] nvarchar(45) NULL,
    [MUStatus] nvarchar(5) NULL,
    [OrderID] nvarchar(10) NULL,
    [ShipmentID] nvarchar(60) NULL,
    [Length] float NULL,
    [Width] float NULL,
    [Height] float NULL,
    [GrossWeight] float NULL,
    [GrossVolume] float NULL,
    [TruckID] nvarchar(60) NULL,
    [MUType] nvarchar(10) NULL,
    [DropLoc] nvarchar(10) NULL,
    [ExternOrderKey] nvarchar(50) NULL,
    [ConsigneeKey] nvarchar(15) NULL,
    [LocationName] nvarchar(60) NULL,
    [UserDefine01] nvarchar(30) NULL,
    [UserDefine02] nvarchar(30) NULL,
    [UserDefine03] nvarchar(30) NULL,
    [UserDefine04] nvarchar(30) NULL,
    [UserDefine05] nvarchar(30) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [CartonGID] nvarchar(50) NULL DEFAULT (''),
    [CartonQty] float NULL DEFAULT ((0)),
    CONSTRAINT [PK_OTMIDTrack_MUID] PRIMARY KEY ([MUID])
);
GO

CREATE INDEX [IX_OTMIDTrack_MUID_OrderID] ON [dbo].[otmidtrack] ([MUID], [OrderID]);
GO