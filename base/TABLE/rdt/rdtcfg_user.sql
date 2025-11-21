CREATE TABLE [rdt].[rdtcfg_user]
(
    [Function_ID] int NOT NULL,
    [Config] nvarchar(10) NOT NULL,
    [Description] nvarchar(80) NOT NULL,
    [Value] int NOT NULL DEFAULT ((0)),
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    CONSTRAINT [PK_RDTCfg_User] PRIMARY KEY ([Function_ID], [Config], [Storerkey])
);
GO
