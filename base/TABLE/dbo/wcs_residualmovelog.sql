CREATE TABLE [dbo].[wcs_residualmovelog]
(
    [SerialNo] int IDENTITY(1,1) NOT NULL,
    [WaveKey] nvarchar(10) NOT NULL,
    [Loc] nvarchar(10) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [SKU] nvarchar(20) NOT NULL,
    [ResidualQty] int NULL DEFAULT ((0)),
    [QtyPutawayed] int NULL DEFAULT ((0)),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [PreMoveQty] int NULL DEFAULT ((0)),
    [ActualMoveQty] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_WCS_ResidualMoveLog_PK] PRIMARY KEY ([SerialNo])
);
GO
