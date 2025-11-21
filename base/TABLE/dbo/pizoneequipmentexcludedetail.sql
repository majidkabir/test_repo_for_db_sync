CREATE TABLE [dbo].[pizoneequipmentexcludedetail]
(
    [PickZone] nvarchar(10) NOT NULL DEFAULT (' '),
    [EquipmentProfileKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKPIZoneEquipmentExcludeDetail] PRIMARY KEY ([PickZone], [EquipmentProfileKey])
);
GO
