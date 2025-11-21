CREATE TABLE [dbo].[replenishment_lock]
(
    [PTCID] nvarchar(10) NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [Sku] nvarchar(20) NOT NULL,
    [FromLoc] nvarchar(10) NOT NULL,
    [ToLoc] nvarchar(10) NOT NULL,
    [Lot] nvarchar(10) NOT NULL,
    [Id] nvarchar(18) NOT NULL,
    [adddate] datetime NOT NULL DEFAULT (getdate()),
    [UserID] nvarchar(128) NULL
);
GO
