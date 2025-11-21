CREATE TABLE [dbo].[ncounter]
(
    [keyname] nvarchar(30) NOT NULL,
    [keycount] int NOT NULL,
    [AlphaCount] nvarchar(10) NOT NULL DEFAULT (''),
    [EditDate] datetime NULL DEFAULT (getdate()),
    CONSTRAINT [PKNCOUNTER] PRIMARY KEY ([keyname])
);
GO
