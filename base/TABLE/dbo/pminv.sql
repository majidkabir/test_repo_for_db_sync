CREATE TABLE [dbo].[pminv]
(
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (''),
    [AccountNo] nvarchar(30) NOT NULL DEFAULT (''),
    [PalletType] nvarchar(30) NOT NULL DEFAULT (''),
    [Qty] int NOT NULL DEFAULT ((0)),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Trafficcop] nvarchar(1) NULL,
    [Archivecop] nvarchar(1) NULL,
    CONSTRAINT [PK_PMINV] PRIMARY KEY ([Facility], [Storerkey], [AccountNo], [PalletType]),
    CONSTRAINT [CK_PMINV_Qty] CHECK ([Qty]>=(0))
);
GO
