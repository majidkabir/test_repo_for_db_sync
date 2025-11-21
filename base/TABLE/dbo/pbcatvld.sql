CREATE TABLE [dbo].[pbcatvld]
(
    [pbv_name] nvarchar(30) NOT NULL,
    [pbv_vald] nvarchar(254) NOT NULL,
    [pbv_type] smallint NOT NULL,
    [pbv_cntr] int NULL,
    [pbv_msg] nvarchar(254) NULL
);
GO

CREATE UNIQUE INDEX [pbcatvld_idx] ON [dbo].[pbcatvld] ([pbv_name]);
GO