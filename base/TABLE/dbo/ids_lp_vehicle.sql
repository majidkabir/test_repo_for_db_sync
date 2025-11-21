CREATE TABLE [dbo].[ids_lp_vehicle]
(
    [Loadkey] nvarchar(10) NOT NULL,
    [VehicleNumber] nvarchar(10) NOT NULL,
    [Linenumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [MBOLKey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_IDS_LP_VEHICLE] PRIMARY KEY ([Loadkey], [VehicleNumber], [MBOLKey])
);
GO
