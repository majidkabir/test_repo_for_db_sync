CREATE TABLE [dbo].[sce_dl_cartonization_stg]
(
    [RowRefNo] int IDENTITY(1,1) NOT NULL,
    [STG_BatchNo] int NOT NULL,
    [STG_SeqNo] int NOT NULL,
    [STG_Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [STG_ErrMsg] nvarchar(250) NOT NULL DEFAULT (''),
    [STG_AddDate] datetime NOT NULL DEFAULT (getdate()),
    [CartonizationKey] nvarchar(10) NULL,
    [CartonizationGroup] nvarchar(10) NULL DEFAULT (' '),
    [CartonType] nvarchar(10) NULL DEFAULT (' '),
    [CartonDescription] nvarchar(60) NULL DEFAULT (' '),
    [UseSequence] int NULL DEFAULT ((1)),
    [Cube] float NULL DEFAULT ((0)),
    [MaxWeight] float NULL DEFAULT ((0)),
    [MaxCount] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [CartonWeight] float NULL DEFAULT ((0)),
    [CartonLength] float NULL DEFAULT ((0)),
    [CartonWidth] float NULL DEFAULT ((0)),
    [CartonHeight] float NULL DEFAULT ((0)),
    [Barcode] nvarchar(30) NULL DEFAULT (''),
    [FillTolerance] int NULL,
    CONSTRAINT [PK_SCE_DL_CARTONIZATION_STG] PRIMARY KEY ([RowRefNo])
);
GO

CREATE INDEX [SCE_DL_CARTONIZATION_STG_Idx01] ON [dbo].[sce_dl_cartonization_stg] ([STG_BatchNo]);
GO
CREATE INDEX [SCE_DL_CARTONIZATION_STG_Idx02] ON [dbo].[sce_dl_cartonization_stg] ([STG_BatchNo], [STG_SeqNo]);
GO