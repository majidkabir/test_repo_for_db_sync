CREATE TABLE [dbo].[palletlabel]
(
    [PLID] int IDENTITY(1,1) NOT NULL,
    [ID] nvarchar(18) NOT NULL,
    [Tablename] nvarchar(18) NOT NULL DEFAULT (''),
    [HDKey] nvarchar(10) NOT NULL DEFAULT (''),
    [DTKey] nvarchar(5) NOT NULL DEFAULT (''),
    [PrintFlag] nvarchar(1) NOT NULL DEFAULT ('Y'),
    [PhotoFlag] nvarchar(1) NOT NULL DEFAULT ('Y'),
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [Parm1] nvarchar(60) NULL,
    [Parm2] nvarchar(60) NULL,
    [Parm3] nvarchar(60) NULL,
    [Parm4] nvarchar(60) NULL,
    [Parm5] nvarchar(60) NULL,
    [Parm6] nvarchar(60) NULL,
    [Parm7] nvarchar(60) NULL,
    [Parm8] nvarchar(60) NULL,
    [Parm9] nvarchar(60) NULL,
    [Parm10] nvarchar(60) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_PalletLabel] PRIMARY KEY ([PLID])
);
GO

CREATE INDEX [IX_PalletLabel_ID] ON [dbo].[palletlabel] ([ID]);
GO