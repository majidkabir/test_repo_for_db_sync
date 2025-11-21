CREATE TABLE [dbo].[sce_dl_idsvehicle_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [VehicleNumber] nvarchar(10) NULL,
    [VehicleDescr] nvarchar(40) NULL,
    [VehicleType] nvarchar(20) NULL,
    [Weight] float NULL,
    [Volume] float NULL,
    [Method] nvarchar(10) NULL,
    [Carrierkey] nvarchar(18) NULL,
    [Agent] nvarchar(60) NULL,
    [UserDefine01] nvarchar(30) NULL,
    [UserDefine02] nvarchar(30) NULL,
    [UserDefine03] nvarchar(30) NULL,
    [UserDefine04] nvarchar(30) NULL,
    [UserDefine05] nvarchar(30) NULL,
    [UserDefine06] nvarchar(30) NULL,
    [UserDefine07] nvarchar(30) NULL,
    [UserDefine08] nvarchar(30) NULL,
    [UserDefine09] nvarchar(30) NULL,
    [UserDefine10] nvarchar(30) NULL,
    [AddWho] nvarchar(128) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_IDSVEHICLE_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_IDSVEHICLE_STG_Idx01] ON [dbo].[sce_dl_idsvehicle_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_IDSVEHICLE_STG_Idx02] ON [dbo].[sce_dl_idsvehicle_stg] ([STG_BatchNo], [STG_SeqNo]);
GO