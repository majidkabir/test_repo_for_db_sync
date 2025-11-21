CREATE TABLE [dbo].[pmtrn]
(
    [PMTranKey] nvarchar(10) NOT NULL DEFAULT (''),
    [TranType] nvarchar(10) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [AccountNo] nvarchar(30) NOT NULL DEFAULT (''),
    [PalletType] nvarchar(30) NOT NULL DEFAULT (''),
    [Sourcekey] nvarchar(20) NOT NULL DEFAULT (''),
    [Sourcetype] nvarchar(30) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [EffectiveDate] datetime NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_PMTRN] PRIMARY KEY ([PMTranKey])
);
GO
