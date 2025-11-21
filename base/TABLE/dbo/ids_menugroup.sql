CREATE TABLE [dbo].[ids_menugroup]
(
    [GroupKey] nvarchar(10) NOT NULL DEFAULT (''),
    [GroupName] nvarchar(50) NULL,
    [FromGroupKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_IDS_MenuGroup] PRIMARY KEY ([GroupKey])
);
GO
