CREATE TABLE [dbo].[ncountertrigantic]
(
    [keyname] nvarchar(30) NOT NULL,
    [keycount] int NOT NULL,
    CONSTRAINT [PKnCounterTrigantic] PRIMARY KEY ([keyname])
);
GO
