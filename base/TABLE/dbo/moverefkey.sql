CREATE TABLE [dbo].[moverefkey]
(
    [MoveRefKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NOT NULL,
    CONSTRAINT [PKMoveRefKey] PRIMARY KEY ([MoveRefKey])
);
GO
