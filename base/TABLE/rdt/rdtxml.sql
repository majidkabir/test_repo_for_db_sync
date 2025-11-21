CREATE TABLE [rdt].[rdtxml]
(
    [Mobile] int NOT NULL,
    [Type] nvarchar(3) NOT NULL,
    [XML] nvarchar(MAX) NULL,
    CONSTRAINT [PK_RDTXML] PRIMARY KEY ([Mobile], [Type])
);
GO
