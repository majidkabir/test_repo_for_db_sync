CREATE TABLE [dbo].[palletmgmt]
(
    [PMKey] nvarchar(10) NOT NULL DEFAULT (''),
    [Sourcekey] nvarchar(20) NOT NULL DEFAULT (''),
    [Sourcetype] nvarchar(30) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Status] nvarchar(10) NOT NULL DEFAULT ('0'),
    [DispatchDate] datetime NULL,
    [DeliveryDate] datetime NULL,
    [EffectiveDate] datetime NULL,
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_PALLETMGMT] PRIMARY KEY ([PMKey])
);
GO
