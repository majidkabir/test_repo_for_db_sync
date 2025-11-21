CREATE TABLE [dbo].[ids_lp_vehicle_dellog]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [Loadkey] nvarchar(10) NOT NULL,
    [VehicleNumber] nvarchar(10) NOT NULL,
    [Status] char(1) NOT NULL DEFAULT ('0'),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] varchar(128) NOT NULL DEFAULT (suser_sname()),
    [ArchiveCop] char(1) NULL,
    [MBOLKey] nvarchar(10) NOT NULL,
    CONSTRAINT [PK_ids_lp_vehicle_dellog] PRIMARY KEY ([Rowref])
);
GO
