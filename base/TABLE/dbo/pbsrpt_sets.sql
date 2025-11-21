CREATE TABLE [dbo].[pbsrpt_sets]
(
    [rpt_set_id] tinyint NOT NULL,
    [name] nvarchar(100) NOT NULL,
    CONSTRAINT [rpt_set_id_ndx] PRIMARY KEY ([rpt_set_id])
);
GO
