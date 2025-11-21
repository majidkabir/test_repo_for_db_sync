CREATE TABLE [rdt].[rdtscnheader]
(
    [scn] int NOT NULL,
    [scndescr] nvarchar(50) NOT NULL,
    [lang_code] nvarchar(3) NOT NULL,
    [adddate] datetime NULL DEFAULT (getdate()),
    [addwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    [editddate] datetime NULL DEFAULT (getdate()),
    [editwho] nvarchar(128) NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_RDTSCNHeader] PRIMARY KEY ([scn])
);
GO
