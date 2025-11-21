CREATE TABLE [dbo].[container]
(
    [ContainerKey] nvarchar(20) NOT NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [Vessel] nvarchar(30) NULL DEFAULT (' '),
    [Voyage] nvarchar(30) NULL DEFAULT (' '),
    [CarrierKey] nvarchar(10) NULL,
    [Carrieragent] nvarchar(30) NULL,
    [ETA] datetime NULL,
    [ETADestination] datetime NULL,
    [BookingReference] nvarchar(30) NULL,
    [OtherReference] nvarchar(30) NULL,
    [Seal01] nvarchar(30) NOT NULL DEFAULT (' '),
    [Seal02] nvarchar(30) NOT NULL DEFAULT (' '),
    [Seal03] nvarchar(30) NOT NULL DEFAULT (' '),
    [ContainerType] nvarchar(10) NULL DEFAULT (' '),
    [EffectiveDate] datetime NOT NULL DEFAULT (getdate()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [TimeStamp] nvarchar(18) NULL,
    [Archivecop] nvarchar(1) NULL,
    [MBOLKey] nvarchar(10) NULL DEFAULT (' '),
    [ExternContainerKey] nvarchar(30) NULL DEFAULT (''),
    [UserDefine01] nvarchar(30) NULL DEFAULT (''),
    [UserDefine02] nvarchar(30) NULL DEFAULT (''),
    [UserDefine03] nvarchar(30) NULL DEFAULT (''),
    [UserDefine04] nvarchar(30) NULL DEFAULT (''),
    [UserDefine05] nvarchar(30) NULL DEFAULT (''),
    [Loc] nvarchar(10) NULL DEFAULT (''),
    [ContainerSize] nvarchar(10) NULL DEFAULT (''),
    [Loadkey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PKCONTAINER] PRIMARY KEY ([ContainerKey]),
    CONSTRAINT [CK_CONTAINER_Status] CHECK ([Status]='9' OR [Status]='0' OR [Status]='5' OR [Status]='3')
);
GO

CREATE INDEX [IDX_Container_mbolkey] ON [dbo].[container] ([MBOLKey]);
GO