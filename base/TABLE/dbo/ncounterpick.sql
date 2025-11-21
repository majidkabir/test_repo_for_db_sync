CREATE TABLE [dbo].[ncounterpick]
(
    [keyname] nvarchar(30) NOT NULL,
    [keycount] int NOT NULL,
    CONSTRAINT [PKNCOUNTERPICK] PRIMARY KEY ([keyname])
);
GO
