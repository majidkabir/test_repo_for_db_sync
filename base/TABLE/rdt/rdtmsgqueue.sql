CREATE TABLE [rdt].[rdtmsgqueue]
(
    [MsgQueueNo] int IDENTITY(1,1) NOT NULL,
    [Mobile] int NULL,
    [Status] nvarchar(1) NULL DEFAULT ('0'),
    [Line01] nvarchar(125) NULL,
    [Line02] nvarchar(125) NULL,
    [Line03] nvarchar(125) NULL,
    [Line04] nvarchar(125) NULL,
    [Line05] nvarchar(125) NULL,
    [Line06] nvarchar(125) NULL,
    [Line07] nvarchar(125) NULL,
    [Line08] nvarchar(125) NULL,
    [Line09] nvarchar(125) NULL,
    [Line10] nvarchar(125) NULL,
    [Line11] nvarchar(125) NULL,
    [Line12] nvarchar(125) NULL,
    [Line13] nvarchar(125) NULL,
    [Line14] nvarchar(125) NULL,
    [Line15] nvarchar(125) NULL,
    [AddDate] datetime NULL DEFAULT (getdate()),
    [DisplayMsg] int NULL,
    CONSTRAINT [PK_rdtMsgQueue] PRIMARY KEY ([MsgQueueNo])
);
GO
