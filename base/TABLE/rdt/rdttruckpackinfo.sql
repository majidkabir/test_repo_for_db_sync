CREATE TABLE [rdt].[rdttruckpackinfo]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Destination] nvarchar(20) NOT NULL DEFAULT (''),
    [VehicleNum] nvarchar(20) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [TrackingNo] nvarchar(40) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [CartonType] nvarchar(10) NULL DEFAULT (''),
    [Type] nvarchar(10) NULL DEFAULT (''),
    [PalletID] nvarchar(20) NULL DEFAULT (''),
    [ReturnPalletID] nvarchar(20) NULL DEFAULT (''),
    [IsReturn] nvarchar(5) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtTruckPackInfo] PRIMARY KEY ([RowRef])
);
GO
