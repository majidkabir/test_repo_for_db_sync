CREATE TABLE [dbo].[ncountertrace]
(
    [keyname] nvarchar(30) NOT NULL,
    [keycount] int NOT NULL,
    CONSTRAINT [PKNCOUNTERTRACE] PRIMARY KEY ([keyname])
);
GO
