CREATE TABLE [dbo].[ids_menulink]
(
    [Parent_ObjCode] nvarchar(40) NOT NULL DEFAULT (''),
    [Child_ObjCode] nvarchar(40) NOT NULL DEFAULT (''),
    [Sequence] int NULL,
    [Groupkey] nvarchar(10) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_LF_MenuLink] PRIMARY KEY ([Parent_ObjCode], [Child_ObjCode], [Groupkey])
);
GO
