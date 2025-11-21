CREATE TABLE [dbo].[equipmentprofile]
(
    [EquipmentProfileKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [MaximumWeight] float NOT NULL DEFAULT ((9999999.0)),
    [WeightReductionPerLevel] float NOT NULL DEFAULT ((0.0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [MaximumLevel] int NOT NULL DEFAULT ((0)),
    [MaximumHeight] float NOT NULL DEFAULT ((0.0)),
    [MaximumPallet] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PKEquipmentProfile] PRIMARY KEY ([EquipmentProfileKey])
);
GO
