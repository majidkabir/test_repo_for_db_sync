CREATE TABLE [rdt].[rdtmenu]
(
    [MenuNo] int NOT NULL,
    [Heading] nvarchar(30) NOT NULL,
    [OP1] int NULL DEFAULT ((0)),
    [OP2] int NULL DEFAULT ((0)),
    [OP3] int NULL DEFAULT ((0)),
    [OP4] int NULL DEFAULT ((0)),
    [OP5] int NULL DEFAULT ((0)),
    [OP6] int NULL DEFAULT ((0)),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [OP7] int NULL DEFAULT ((0)),
    [OP8] int NULL DEFAULT ((0)),
    [OP9] int NULL DEFAULT ((0)),
    CONSTRAINT [PK_RDTMenu] PRIMARY KEY ([MenuNo])
);
GO
