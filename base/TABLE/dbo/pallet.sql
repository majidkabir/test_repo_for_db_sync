CREATE TABLE [dbo].[pallet]
(
    [PalletKey] nvarchar(30) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    [Length] float NOT NULL DEFAULT ((0)),
    [Width] float NOT NULL DEFAULT ((0)),
    [Height] float NOT NULL DEFAULT ((0)),
    [GrossWgt] float NOT NULL DEFAULT ((0)),
    [PalletType] nvarchar(30) NULL DEFAULT (''),
    CONSTRAINT [PKPALLET] PRIMARY KEY ([PalletKey]),
    CONSTRAINT [CK_PALLET_Status] CHECK ([Status]='9' OR [Status]='0' OR [Status]='5' OR [Status]='3')
);
GO
