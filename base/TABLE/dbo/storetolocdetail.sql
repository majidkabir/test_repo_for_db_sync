CREATE TABLE [dbo].[storetolocdetail]
(
    [ConsigneeKey] nvarchar(15) NOT NULL,
    [LOC] nvarchar(10) NOT NULL,
    [Status] nvarchar(10) NOT NULL DEFAULT ('1'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [LocFull] nvarchar(10) NOT NULL DEFAULT ('N'),
    [StoreGroup] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_StoreToLocDetail] PRIMARY KEY ([ConsigneeKey], [LOC])
);
GO
