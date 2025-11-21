CREATE TABLE [rdt].[rdtcfg_sys]
(
    [Function_ID] int NOT NULL,
    [Config] nvarchar(10) NOT NULL,
    [Description] nvarchar(80) NOT NULL,
    [Value] int NOT NULL DEFAULT ((0)),
    CONSTRAINT [PK_RDTCfg_SYS] PRIMARY KEY ([Function_ID], [Config])
);
GO
