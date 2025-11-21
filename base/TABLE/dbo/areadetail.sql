CREATE TABLE [dbo].[areadetail]
(
    [AreaKey] nvarchar(10) NOT NULL DEFAULT (' '),
    [PutawayZone] nvarchar(10) NOT NULL DEFAULT (' '),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    CONSTRAINT [PKAreaDetail] PRIMARY KEY ([AreaKey], [PutawayZone])
);
GO
