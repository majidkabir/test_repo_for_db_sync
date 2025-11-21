CREATE TABLE [rdt].[rdtdynamicpicklog_dellog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Zone] nvarchar(10) NULL,
    [Loc] nvarchar(10) NULL,
    [PickSlipNo] nvarchar(10) NULL,
    [CartonNo] int NULL,
    [LabelNo] nvarchar(20) NULL,
    [AddDate] datetime NULL,
    [AddWho] nvarchar(128) NULL,
    [DelDate] datetime NULL DEFAULT (getdate()),
    [DelWho] nvarchar(128) NULL DEFAULT (suser_sname())
);
GO
