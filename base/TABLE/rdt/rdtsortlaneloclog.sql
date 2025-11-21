CREATE TABLE [rdt].[rdtsortlaneloclog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [Lane] nvarchar(10) NOT NULL DEFAULT (''),
    [LOC] nvarchar(10) NOT NULL DEFAULT (''),
    [ID] nvarchar(18) NOT NULL DEFAULT (''),
    [OrderKey] nvarchar(10) NOT NULL DEFAULT (''),
    [ConsigneeKey] nvarchar(15) NOT NULL DEFAULT (''),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [LoadKey] nvarchar(10) NULL DEFAULT (''),
    CONSTRAINT [PK_rdtSortLaneLocLog] PRIMARY KEY ([RowRef])
);
GO

CREATE UNIQUE INDEX [IX_rdtSortLaneLocLog_Lane_LOC] ON [rdt].[rdtsortlaneloclog] ([Lane], [LOC]);
GO