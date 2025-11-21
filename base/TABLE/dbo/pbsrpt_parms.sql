CREATE TABLE [dbo].[pbsrpt_parms]
(
    [rpt_id] nvarchar(8) NOT NULL,
    [parm_no] tinyint NOT NULL,
    [parm_datatype] nvarchar(20) NULL,
    [parm_label] nvarchar(30) NULL,
    [parm_default] nvarchar(30) NULL,
    [style] nvarchar(10) NULL,
    [name] nvarchar(40) NULL,
    [display] nvarchar(40) NULL,
    [data] nvarchar(40) NULL,
    [attributes] nvarchar(100) NULL,
    [visible] nvarchar(1) NULL,
    CONSTRAINT [rpt_parms_id_ndx] PRIMARY KEY ([rpt_id], [parm_no])
);
GO
