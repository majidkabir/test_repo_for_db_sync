CREATE TABLE [dbo].[sce_dl_cartonization]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
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
    [CartonWeight] float NULL DEFAULT ((0)),
    [CartonLength] float NULL DEFAULT ((0)),
    [CartonWidth] float NULL DEFAULT ((0)),
    [CartonHeight] float NULL DEFAULT ((0)),
    [Barcode] nvarchar(30) NOT NULL DEFAULT (''),
    [FillTolerance] int NULL,
    CONSTRAINT [PK_SCE_DL_CARTONIZATION] PRIMARY KEY ([RowRefNo]),
    CONSTRAINT [CK_SCE_DL_CARTONIZATION_CartGroup_CartonType] UNIQUE ([CartonizationGroup], [CartonType]),
    CONSTRAINT [CK_SCE_DL_CARTONIZATION_CartGroup_UseSequence] UNIQUE ([CartonizationGroup], [UseSequence])
);
GO
