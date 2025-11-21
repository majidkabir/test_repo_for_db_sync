CREATE TABLE [rdt].[rdtdynamicpicklog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Zone] nvarchar(10) NOT NULL,
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [PickSlipNo] nvarchar(10) NOT NULL DEFAULT (''),
    [CartonNo] int NOT NULL DEFAULT ((0)),
    [LabelNo] nvarchar(20) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (user_name()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [FromLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [ToLOC] nvarchar(10) NOT NULL DEFAULT (''),
    [Facility] nvarchar(5) NOT NULL DEFAULT (''),
    CONSTRAINT [PKrdtDynamicPickLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [Idx_RDTDynamicPickLog_Zone_LOC_PickSlipNo] ON [rdt].[rdtdynamicpicklog] ([Zone], [LOC], [PickSlipNo]);
GO