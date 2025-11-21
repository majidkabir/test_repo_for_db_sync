CREATE TABLE [dbo].[codelkup]
(
    [LISTNAME] nvarchar(10) NOT NULL,
    [Code] nvarchar(30) NOT NULL,
    [Description] nvarchar(250) NULL,
    [Short] nvarchar(10) NULL,
    [Long] nvarchar(250) NULL,
    [Notes] nvarchar(4000) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [TrafficCop] nvarchar(1) NULL,
    [Timestamp] timestamp NOT NULL,
    [Notes2] nvarchar(4000) NULL,
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [UDF01] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF02] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF03] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF04] nvarchar(60) NOT NULL DEFAULT (' '),
    [UDF05] nvarchar(60) NOT NULL DEFAULT (' '),
    [code2] nvarchar(30) NOT NULL DEFAULT (''),
    CONSTRAINT [PKCODELKUP] PRIMARY KEY ([LISTNAME], [Code], [Storerkey], [code2]),
    CONSTRAINT [FK_CODELKUP_LISTNAME_01] FOREIGN KEY ([LISTNAME]) REFERENCES [dbo].[CODELIST] ([LISTNAME])
);
GO

CREATE INDEX [IX_CODELKUP_SHORT] ON [dbo].[codelkup] ([Short], [LISTNAME], [UDF01]);
GO
CREATE INDEX [IX_CODELKUP_STORERKEY] ON [dbo].[codelkup] ([Storerkey], [LISTNAME], [Short]);
GO