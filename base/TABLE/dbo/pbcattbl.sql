CREATE TABLE [dbo].[pbcattbl]
(
    [pbt_tnam] nvarchar(30) NULL,
    [pbt_tid] int NULL,
    [pbt_ownr] nvarchar(30) NULL,
    [pbd_fhgt] smallint NULL,
    [pbd_fwgt] smallint NULL,
    [pbd_fitl] nvarchar(1) NULL,
    [pbd_funl] nvarchar(1) NULL,
    [pbd_fchr] smallint NULL,
    [pbd_fptc] smallint NULL,
    [pbd_ffce] nvarchar(18) NULL,
    [pbh_fhgt] smallint NULL,
    [pbh_fwgt] smallint NULL,
    [pbh_fitl] nvarchar(1) NULL,
    [pbh_funl] nvarchar(1) NULL,
    [pbh_fchr] smallint NULL,
    [pbh_fptc] smallint NULL,
    [pbh_ffce] nvarchar(18) NULL,
    [pbl_fhgt] smallint NULL,
    [pbl_fwgt] smallint NULL,
    [pbl_fitl] nvarchar(1) NULL,
    [pbl_funl] nvarchar(1) NULL,
    [pbl_fchr] smallint NULL,
    [pbl_fptc] smallint NULL,
    [pbl_ffce] nvarchar(18) NULL,
    [pbt_cmnt] nvarchar(254) NULL
);
GO

CREATE UNIQUE INDEX [pbcattbl_idx] ON [dbo].[pbcattbl] ([pbt_tnam], [pbt_ownr]);
GO