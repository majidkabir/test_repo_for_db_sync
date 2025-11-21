CREATE TABLE [dbo].[ids_menuitem]
(
    [ObjCode] nvarchar(40) NOT NULL DEFAULT (''),
    [ObjDesc] nvarchar(50) NULL,
    [ObjType] nvarchar(10) NULL,
    [ObjPicture] nvarchar(50) NULL,
    CONSTRAINT [PK_LF_MenuItem] PRIMARY KEY ([ObjCode])
);
GO
