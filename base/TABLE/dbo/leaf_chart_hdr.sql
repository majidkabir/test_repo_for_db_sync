CREATE TABLE [dbo].[leaf_chart_hdr]
(
    [ChartName] nvarchar(100) NOT NULL DEFAULT (''),
    [RDLC] nvarchar(100) NULL DEFAULT (''),
    [URL] nvarchar(200) NULL DEFAULT (''),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_LEAF_Chart_HDR] PRIMARY KEY ([ChartName])
);
GO
