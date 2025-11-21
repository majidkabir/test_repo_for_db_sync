CREATE TABLE [dbo].[leaf_chart_det]
(
    [RowRefNo] bigint IDENTITY(1,1) NOT NULL,
    [ChartName] nvarchar(100) NOT NULL DEFAULT (''),
    [Param] nvarchar(30) NOT NULL DEFAULT (''),
    [DataType] nvarchar(30) NOT NULL DEFAULT (''),
    [Label] nvarchar(50) NULL DEFAULT (''),
    [OperationType] nvarchar(5) NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_LEAF_Chart_DET] PRIMARY KEY ([RowRefNo]),
    CONSTRAINT [FK_LEAF_Chart_DET] FOREIGN KEY ([ChartName]) REFERENCES [dbo].[LEAF_Chart_HDR] ([ChartName])
);
GO
