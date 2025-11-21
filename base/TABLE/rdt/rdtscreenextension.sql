CREATE TABLE [rdt].[rdtscreenextension]
(
    [RowRef] bigint IDENTITY(1,1) NOT NULL,
    [Func] bigint NOT NULL,
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    [StorerKey] nvarchar(15) NOT NULL,
    [CurrentStep] int NOT NULL,
    [CurrentScreen] int NOT NULL,
    [ConditionCode] nvarchar(15) NOT NULL,
    [NextStep] int NOT NULL,
    [NextScreen] int NOT NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_rdtScreenExtension] PRIMARY KEY ([RowRef])
);
GO
