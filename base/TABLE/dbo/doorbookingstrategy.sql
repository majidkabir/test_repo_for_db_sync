CREATE TABLE [dbo].[doorbookingstrategy]
(
    [DoorBookingStrategyKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Description] nvarchar(60) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [ShipmentGroupProfile] nvarchar(100) NOT NULL DEFAULT (''),
    [Active] nvarchar(5) NOT NULL DEFAULT (''),
    [SPCode] nvarchar(30) NOT NULL DEFAULT (''),
    [Priority] nvarchar(5) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PK_DoorBookingStrategy] PRIMARY KEY ([DoorBookingStrategyKey])
);
GO
