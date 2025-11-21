CREATE TABLE [dbo].[cartonization]
(
    [CartonizationKey] nvarchar(10) NOT NULL,
    [CartonizationGroup] nvarchar(10) NOT NULL DEFAULT (' '),
    [CartonType] nvarchar(10) NOT NULL DEFAULT (' '),
    [CartonDescription] nvarchar(60) NOT NULL DEFAULT (' '),
    [UseSequence] int NOT NULL DEFAULT ((1)),
    [Cube] float NOT NULL DEFAULT ((0)),
    [MaxWeight] float NOT NULL DEFAULT ((0)),
    [MaxCount] int NOT NULL DEFAULT ((0)),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [ArchiveCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [CartonWeight] float NULL DEFAULT ((0)),
    [CartonLength] float NULL DEFAULT ((0)),
    [CartonWidth] float NULL DEFAULT ((0)),
    [CartonHeight] float NULL DEFAULT ((0)),
    [Barcode] nvarchar(30) NOT NULL DEFAULT (''),
    [FillTolerance] int NULL,
    CONSTRAINT [PKCartonization] PRIMARY KEY ([CartonizationKey]),
    CONSTRAINT [CK_Cartonization_CartGroup_CartonType] UNIQUE ([CartonizationGroup], [CartonType]),
    CONSTRAINT [CK_Cartonization_CartGroup_UseSequence] UNIQUE ([CartonizationGroup], [UseSequence])
);
GO

CREATE INDEX [IDX_Cartonization_01] ON [dbo].[cartonization] ([CartonizationGroup], [CartonType], [UseSequence]);
GO