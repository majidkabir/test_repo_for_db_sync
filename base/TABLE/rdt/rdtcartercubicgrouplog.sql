CREATE TABLE [rdt].[rdtcartercubicgrouplog]
(
    [RowRef] int IDENTITY(1,1) NOT NULL,
    [CartonGroup] nvarchar(10) NOT NULL DEFAULT (''),
    [BUSR3] nvarchar(30) NOT NULL DEFAULT (''),
    [Style] nvarchar(20) NOT NULL DEFAULT (''),
    [Size] nvarchar(10) NOT NULL DEFAULT (''),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    CONSTRAINT [PK_rdtCarterCubicGroupLog] PRIMARY KEY ([RowRef])
);
GO

CREATE INDEX [IX_rdtCarterCubicGroupLog_CartonGroup_BUSR3_Style_Size] ON [rdt].[rdtcartercubicgrouplog] ([CartonGroup], [BUSR3], [Style], [Size]);
GO