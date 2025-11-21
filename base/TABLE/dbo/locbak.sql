CREATE TABLE [dbo].[locbak]
(
    [Loc] nvarchar(10) NOT NULL,
    [LocationType] nvarchar(10) NOT NULL,
    [PutawayZone] nvarchar(10) NOT NULL,
    [InventoryDate] datetime NOT NULL,
    [Adddate] datetime NULL DEFAULT (getdate()),
    [Addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [Editdate] datetime NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_locbak] PRIMARY KEY ([InventoryDate], [Loc])
);
GO
