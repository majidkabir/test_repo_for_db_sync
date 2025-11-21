CREATE TABLE [dbo].[ids_lp_driver]
(
    [Loadkey] nvarchar(10) NOT NULL,
    [DriverCode] nvarchar(10) NOT NULL,
    [Linenumber] nvarchar(5) NOT NULL DEFAULT (' '),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [MBOLKey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_IDS_LP_Driver] PRIMARY KEY ([Loadkey], [DriverCode], [MBOLKey])
);
GO
