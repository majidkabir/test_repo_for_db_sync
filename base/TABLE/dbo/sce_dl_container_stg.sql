CREATE TABLE [dbo].[sce_dl_container_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [ContainerKey] nvarchar(20) NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [Vessel] nvarchar(30) NULL DEFAULT (' '),
    [Voyage] nvarchar(30) NULL DEFAULT (' '),
    [CarrierKey] nvarchar(10) NULL,
    [Carrieragent] nvarchar(30) NULL,
    [ETA] datetime NULL,
    [ETADestination] datetime NULL,
    [BookingReference] nvarchar(30) NULL,
    [OtherReference] nvarchar(30) NULL,
    [Seal01] nvarchar(30) NULL DEFAULT (' '),
    [Seal02] nvarchar(30) NULL DEFAULT (' '),
    [Seal03] nvarchar(30) NULL DEFAULT (' '),
    [ContainerType] nvarchar(10) NULL DEFAULT (' '),
    [HEffectiveDate] datetime NULL DEFAULT (getdate()),
    [TimeStamp] nvarchar(18) NULL,
    [MBOLKey] nvarchar(10) NULL DEFAULT (' '),
    [ExternContainerKey] nvarchar(30) NULL DEFAULT (''),
    [HUserDefine01] nvarchar(30) NULL DEFAULT (''),
    [HUserDefine02] nvarchar(30) NULL DEFAULT (''),
    [HUserDefine03] nvarchar(30) NULL DEFAULT (''),
    [HUserDefine04] nvarchar(30) NULL DEFAULT (''),
    [HUserDefine05] nvarchar(30) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL DEFAULT (''),
    [ContainerSize] nvarchar(10) NULL DEFAULT (''),
    [Loadkey] nvarchar(10) NULL DEFAULT (''),
    [ContainerLineNumber] nvarchar(5) NULL,
    [PalletKey] nvarchar(30) NULL,
    [DEffectiveDate] datetime NULL DEFAULT (getdate()),
    [DUserDefine01] nvarchar(30) NULL DEFAULT (''),
    [DUserDefine02] nvarchar(30) NULL DEFAULT (''),
    [DUserDefine03] nvarchar(30) NULL DEFAULT (''),
    [DUserDefine04] nvarchar(30) NULL DEFAULT (''),
    [DUserDefine05] nvarchar(30) NULL DEFAULT (''),
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_CONTAINER_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_CONTAINER_STG_Idx01] ON [dbo].[sce_dl_container_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_CONTAINER_STG_Idx02] ON [dbo].[sce_dl_container_stg] ([STG_BatchNo], [STG_SeqNo]);
GO