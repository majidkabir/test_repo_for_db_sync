CREATE TABLE [dbo].[wcs_sortation]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [LP_LaneNumber] nvarchar(10) NULL DEFAULT (''),
    [SeqNo] int NOT NULL,
    [LabelNo] nvarchar(20) NOT NULL,
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [ErrMsg] nvarchar(60) NULL DEFAULT (''),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_WCS_SORTATION] PRIMARY KEY ([RowRef])
);
GO
