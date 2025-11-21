CREATE TABLE [dbo].[pbsrpt_reports]
(
    [rpt_id] nvarchar(8) NOT NULL,
    [rpt_datawindow] nvarchar(40) NULL,
    [rpt_library] nvarchar(80) NULL,
    [rpt_title] nvarchar(100) NULL,
    [rpt_purpose] nvarchar(255) NULL,
    [rpt_descr] nvarchar(255) NULL,
    [rpt_header] nvarchar(1) NULL,
    [rpt_active] nvarchar(1) NULL,
    [rpt_type] int NULL,
    [rpt_where] nvarchar(255) NULL,
    [rpt_filter] nvarchar(255) NULL,
    [rpt_sort] nvarchar(255) NULL,
    [enable_filter] nvarchar(1) NULL,
    [enable_sort] nvarchar(1) NULL,
    [autoretrieve] nvarchar(1) NULL,
    [category_id] int NULL,
    [show_criteria] nvarchar(1) NULL,
    [query_mode] nvarchar(1) NULL,
    [shared_rpt_id] nvarchar(8) NULL,
    [HeaderFlag] nvarchar(1) NULL DEFAULT ('N'),
    [FooterFlag] nvarchar(1) NULL DEFAULT ('N'),
    [SCEPrintType] nvarchar(30) NULL DEFAULT (''),
    CONSTRAINT [rpt_id_ndx] PRIMARY KEY ([rpt_id])
);
GO
