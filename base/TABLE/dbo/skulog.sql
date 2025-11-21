CREATE TABLE [dbo].[skulog]
(
    [Person] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [ActionTime] datetime NOT NULL DEFAULT (getdate()),
    [ActionDescr] nvarchar(100) NOT NULL DEFAULT (' ')
);
GO
