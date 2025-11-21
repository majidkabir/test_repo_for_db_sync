CREATE TABLE [dbo].[pbcatcol]
(
    [pbc_tnam] nvarchar(30) NULL,
    [pbc_tid] int NULL,
    [pbc_ownr] nvarchar(30) NULL,
    [pbc_cnam] nvarchar(30) NULL,
    [pbc_cid] smallint NULL,
    [pbc_labl] nvarchar(254) NULL,
    [pbc_lpos] smallint NULL,
    [pbc_hdr] nvarchar(254) NULL,
    [pbc_hpos] smallint NULL,
    [pbc_jtfy] smallint NULL,
    [pbc_mask] nvarchar(31) NULL,
    [pbc_case] smallint NULL,
    [pbc_hght] smallint NULL,
    [pbc_wdth] smallint NULL,
    [pbc_ptrn] nvarchar(31) NULL,
    [pbc_bmap] nvarchar(1) NULL,
    [pbc_init] nvarchar(254) NULL,
    [pbc_cmnt] nvarchar(254) NULL,
    [pbc_edit] nvarchar(31) NULL,
    [pbc_tag] nvarchar(254) NULL
);
GO

CREATE UNIQUE INDEX [pbcatcol_idx] ON [dbo].[pbcatcol] ([pbc_tnam], [pbc_ownr], [pbc_cnam]);
GO