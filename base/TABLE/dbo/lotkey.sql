CREATE TABLE [dbo].[lotkey]
(
    [LOTKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NOT NULL,
    CONSTRAINT [PK_LOTKEY] PRIMARY KEY ([LOTKey])
);
GO
