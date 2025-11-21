CREATE TABLE [rdt].[rdttrace]
(
    [Mobile] int NOT NULL,
    [InFunc] int NOT NULL DEFAULT ((0)),
    [InScn] int NOT NULL DEFAULT ((0)),
    [InStep] int NOT NULL DEFAULT ((0)),
    [OutFunc] int NOT NULL DEFAULT ((0)),
    [OutScn] int NOT NULL DEFAULT ((0)),
    [OutStep] int NOT NULL DEFAULT ((0)),
    [Usr] nvarchar(128) NULL DEFAULT (suser_sname()),
    [StartTime] datetime NOT NULL DEFAULT (getdate()),
    [EndTime] datetime NOT NULL DEFAULT (getdate()),
    [TimeTaken] int NULL DEFAULT ((0)),
    [ROWREF] int IDENTITY(1,1) NOT NULL,
    [ScnTime] int NULL DEFAULT ((0)),
    CONSTRAINT [PKRDTTRace] PRIMARY KEY ([ROWREF])
);
GO
