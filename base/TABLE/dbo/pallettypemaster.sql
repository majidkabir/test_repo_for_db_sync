CREATE TABLE [dbo].[pallettypemaster]
(
    [PalletTypeMasterKey] nvarchar(10) NOT NULL,
    [Facility] nvarchar(5) NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [PalletType] nvarchar(10) NULL DEFAULT (''),
    [PalletTypeName] nvarchar(50) NULL DEFAULT (''),
    [Length] float NOT NULL DEFAULT ((0)),
    [Width] float NOT NULL DEFAULT ((0)),
    [Height] float NOT NULL DEFAULT ((0)),
    [LoadBearingCapacity] decimal(10, 2) NOT NULL DEFAULT ((0)),
    [ExtraLoad] decimal(10, 2) NOT NULL DEFAULT ((0)),
    [DeadLoad] decimal(10, 2) NOT NULL DEFAULT ((0)),
    [Region] nvarchar(50) NULL,
    [ISOStandard] nvarchar(1) NULL,
    [PalletTypeInUse] nvarchar(1) NULL,
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PKPALLETTYPEMASTER] PRIMARY KEY ([PalletTypeMasterKey])
);
GO
