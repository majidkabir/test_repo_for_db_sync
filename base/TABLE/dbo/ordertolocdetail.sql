CREATE TABLE [dbo].[ordertolocdetail]
(
    [OrderKey] nvarchar(10) NOT NULL,
    [LOC] nvarchar(10) NOT NULL DEFAULT (' '),
    [CartonID] nvarchar(20) NOT NULL DEFAULT (' '),
    [Wavekey] nvarchar(20) NOT NULL DEFAULT (' '),
    [PTSZone] nvarchar(10) NOT NULL DEFAULT (' '),
    [Status] nvarchar(10) NOT NULL DEFAULT ('1'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [StoreGroup] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_OrderToLocDetail] PRIMARY KEY ([OrderKey], [LOC])
);
GO
