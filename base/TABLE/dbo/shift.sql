CREATE TABLE [dbo].[shift]
(
    [Sequence] nvarchar(5) NOT NULL,
    [ShiftDescr] nvarchar(20) NOT NULL DEFAULT (''),
    [Day] nvarchar(20) NOT NULL DEFAULT (''),
    [ShiftNumber] int NOT NULL,
    [TimeFrom] datetime NOT NULL,
    [TimeTo] datetime NOT NULL,
    [Labour] int NULL,
    [Addwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [Editwho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [Productivity] numeric(8, 2) NULL,
    CONSTRAINT [PK_SHIFT] PRIMARY KEY ([Sequence])
);
GO
