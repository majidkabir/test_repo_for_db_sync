CREATE TABLE [dbo].[sce_dl_routemaster_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Route] nvarchar(10) NULL,
    [Descr] nvarchar(60) NULL,
    [TruckType] nvarchar(10) NULL,
    [Volume] float NULL,
    [Weight] float NULL,
    [CarrierKey] nvarchar(15) NULL,
    [CarrierDesc] nvarchar(60) NULL,
    [ZipCodeFrom] nvarchar(15) NULL DEFAULT (' '),
    [ZipCodeTo] nvarchar(15) NULL DEFAULT (' '),
    [SelfDelivery] nvarchar(1) NULL,
    [HandledByWH] nvarchar(1) NULL,
    [NoOfDrops] int NULL,
    [TMS_Type] nvarchar(10) NULL,
    [TMS_Interface] nvarchar(1) NULL DEFAULT (' '),
    [ScheduleKey] nvarchar(30) NULL DEFAULT (' '),
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_ROUTEMASTER_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_ROUTEMASTER_STG_Idx01] ON [dbo].[sce_dl_routemaster_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_ROUTEMASTER_STG_Idx02] ON [dbo].[sce_dl_routemaster_stg] ([STG_BatchNo], [STG_SeqNo]);
GO