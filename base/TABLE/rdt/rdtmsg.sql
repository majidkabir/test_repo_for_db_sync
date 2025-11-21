CREATE TABLE [rdt].[rdtmsg]
(
    [Message_ID] int NOT NULL,
    [Lang_Code] nvarchar(3) NOT NULL,
    [Message_Type] nvarchar(3) NOT NULL,
    [Message_Text] nvarchar(125) NOT NULL,
    [StoredProcName] nvarchar(45) NULL DEFAULT (''),
    [EventType] int NOT NULL DEFAULT ((0)),
    [Func] int NULL DEFAULT ((0)),
    [URL] nvarchar(100) NULL DEFAULT (''),
    [Message_Text_Long] nvarchar(250) NOT NULL DEFAULT (''),
    CONSTRAINT [PK_RDTMsg] PRIMARY KEY ([Message_ID], [Lang_Code], [Message_Type])
);
GO
