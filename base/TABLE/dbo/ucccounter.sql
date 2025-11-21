CREATE TABLE [dbo].[ucccounter]
(
    [StorerKey] nvarchar(15) NOT NULL DEFAULT (''),
    [KeyCount] int NOT NULL DEFAULT ((0)),
    [STARTUCC] nvarchar(9) NULL DEFAULT (''),
    [ENDUCC] nvarchar(9) NULL DEFAULT (''),
    [STARTUSEDATE] datetime NULL,
    CONSTRAINT [PK_UCCCounter] PRIMARY KEY ([StorerKey])
);
GO
