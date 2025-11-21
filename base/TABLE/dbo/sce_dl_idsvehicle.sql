CREATE TABLE [dbo].[sce_dl_idsvehicle]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
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
    [AddWho] nvarchar(128) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_SCE_DL_IDSVEHICLE] PRIMARY KEY ([RowRefNo])
);
GO
