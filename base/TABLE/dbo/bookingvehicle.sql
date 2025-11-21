CREATE TABLE [dbo].[bookingvehicle]
(
    [BookingNo] int NOT NULL DEFAULT (''),
    [VehicleNo] int NOT NULL DEFAULT (''),
    [BookingType] nvarchar(5) NOT NULL DEFAULT (''),
    [SCAC] nvarchar(10) NOT NULL DEFAULT (''),
    [DriverName] nvarchar(30) NOT NULL DEFAULT (''),
    [LicenseNo] nvarchar(20) NOT NULL DEFAULT (''),
    [VehicleContainer] nvarchar(30) NOT NULL DEFAULT (''),
    [VehicleType] nvarchar(20) NOT NULL DEFAULT (''),
    [CarrierKey] nvarchar(18) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_BookingVehicle] PRIMARY KEY ([BookingNo], [VehicleNo])
);
GO
