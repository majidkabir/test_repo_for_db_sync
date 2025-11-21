CREATE TABLE [dbo].[pbsrpt_set_reports]
(
    [rpt_set_id] tinyint NOT NULL,
    [rpt_seq] tinyint NOT NULL,
    [rpt_id] nvarchar(8) NULL,
    CONSTRAINT [rpt_set_reports_ndx] PRIMARY KEY ([rpt_set_id], [rpt_seq])
);
GO
