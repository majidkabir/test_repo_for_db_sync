CREATE TABLE [dbo].[sce_dl_putawayzone_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
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
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_PUTAWAYZONE_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_PUTAWAYZONE_STG_Idx01] ON [dbo].[sce_dl_putawayzone_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_PUTAWAYZONE_STG_Idx02] ON [dbo].[sce_dl_putawayzone_stg] ([STG_BatchNo], [STG_SeqNo]);
GO