CREATE TABLE [dbo].[ids_favoritemenu]
(
    [UserId] nvarchar(128) NOT NULL,
    [MenuItemObjName] nvarchar(40) NOT NULL,
    [MenuItemText] nvarchar(50) NULL,
    CONSTRAINT [PK_IDS_FavoriteMenu] PRIMARY KEY ([UserId], [MenuItemObjName])
);
GO
