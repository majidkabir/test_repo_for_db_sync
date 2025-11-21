CREATE TABLE [dbo].[ids_vehicle]
(
    [VehicleNumber] nvarchar(10) NOT NULL,
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
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_IDS_VEHICLE] PRIMARY KEY ([VehicleNumber])
);
GO
