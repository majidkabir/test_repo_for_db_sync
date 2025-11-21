CREATE TABLE [dbo].[tcpsocket_process]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [MessageName] nvarchar(50) NOT NULL,
    [SprocName] nvarchar(100) NULL,
    [DESCR] nvarchar(100) NULL,
    [Recipient1] nvarchar(125) NULL,
    [Recipient2] nvarchar(125) NULL,
    [Recipient3] nvarchar(125) NULL,
    [Recipient4] nvarchar(125) NULL,
    [Recipient5] nvarchar(125) NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [EditDate] datetime NOT NULL DEFAULT (getdate()),
    [EditWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    [MessageGroup] nvarchar(20) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_TCPSocket_Process] PRIMARY KEY ([MessageName], [MessageGroup], [StorerKey])
);
GO
