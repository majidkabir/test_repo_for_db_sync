CREATE TABLE [dbo].[putawayzone]
(
    [PutawayZone] nvarchar(10) NOT NULL DEFAULT (' '),
    [Descr] nvarchar(60) NOT NULL DEFAULT (' '),
    [InLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [OutLoc] nvarchar(10) NOT NULL DEFAULT (' '),
    [Uom1PickMethod] nvarchar(1) NOT NULL DEFAULT ('1'),
    [Uom2PickMethod] nvarchar(1) NOT NULL DEFAULT ('3'),
    [Uom3PickMethod] nvarchar(1) NOT NULL DEFAULT ('3'),
    [Uom4PickMethod] nvarchar(1) NOT NULL DEFAULT ('1'),
    [Uom5PickMethod] nvarchar(1) NOT NULL DEFAULT ('3'),
    [Uom6PickMethod] nvarchar(1) NOT NULL DEFAULT ('3'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [facility] nvarchar(5) NULL,
    [No_Pallet] int NULL,
    [ZoneCategory] nvarchar(10) NULL DEFAULT ('N'),
    [Pallet_type] nvarchar(10) NOT NULL DEFAULT (' '),
    [Floor] nvarchar(3) NULL DEFAULT (''),
    CONSTRAINT [PKPutawayZone] PRIMARY KEY ([PutawayZone])
);
GO
