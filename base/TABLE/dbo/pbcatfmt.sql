CREATE TABLE [dbo].[pbcatfmt]
(
    [pbf_name] nvarchar(30) NOT NULL,
    [pbf_frmt] nvarchar(254) NOT NULL,
    [pbf_type] smallint NOT NULL,
    [pbf_cntr] int NULL
);
GO

CREATE UNIQUE INDEX [pbcatfmt_idx] ON [dbo].[pbcatfmt] ([pbf_name]);
GO