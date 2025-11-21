CREATE TABLE [dbo].[sce_dl_putawayzone]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [PutawayZone] nvarchar(10) NULL,
    [Descr] nvarchar(60) NULL,
    [InLoc] nvarchar(10) NULL,
    [OutLoc] nvarchar(10) NULL,
    [Uom1PickMethod] nvarchar(1) NULL,
    [Uom2PickMethod] nvarchar(1) NULL,
    [Uom3PickMethod] nvarchar(1) NULL,
    [Uom4PickMethod] nvarchar(1) NULL,
    [Uom5PickMethod] nvarchar(1) NULL,
    [Uom6PickMethod] nvarchar(1) NULL,
    [facility] nvarchar(5) NULL,
    [No_Pallet] int NULL,
    [ZoneCategory] nvarchar(10) NULL,
    [Pallet_type] nvarchar(10) NULL,
    [Floor] nvarchar(3) NULL,
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_PUTAWAYZONE] PRIMARY KEY ([RowRefNo])
);
GO
