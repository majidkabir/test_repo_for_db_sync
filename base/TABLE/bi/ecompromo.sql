CREATE TABLE [bi].[ecompromo]
(
    [PromoID] smallint IDENTITY(1,1) NOT NULL,
    [PromoType] nvarchar(30) NOT NULL,
    [Descr] nvarchar(500) NOT NULL,
    [StartDate] smalldatetime NOT NULL,
    [EndDate] smalldatetime NOT NULL,
    [DaysAgo] smallint NOT NULL,
    [IncludeArchive] bit NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] sysname NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] sysname NOT NULL DEFAULT (suser_sname()),
    [FreqInterval] smallint NOT NULL DEFAULT ((10)),
    CONSTRAINT [PK_eComPromo] PRIMARY KEY ([PromoID])
);
GO
