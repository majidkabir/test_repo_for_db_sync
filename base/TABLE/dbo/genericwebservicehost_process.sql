CREATE TABLE [dbo].[genericwebservicehost_process]
(
    [RequestMessageName] nvarchar(30) NOT NULL,
    [ResponseMessageName] nvarchar(30) NOT NULL,
    [SprocName] nvarchar(50) NOT NULL,
    [DESCR] nvarchar(100) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [StorerKey] nvarchar(15) NULL,
    [Recipient1] nvarchar(125) NULL,
    [Recipient2] nvarchar(125) NULL,
    [Recipient3] nvarchar(125) NULL,
    [Recipient4] nvarchar(125) NULL,
    [Recipient5] nvarchar(125) NULL,
    CONSTRAINT [PK_WebServiceHost_Process] PRIMARY KEY ([RequestMessageName])
);
GO
