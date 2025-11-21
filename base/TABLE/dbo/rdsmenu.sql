CREATE TABLE [dbo].[rdsmenu]
(
    [MenuID] int NOT NULL,
    [SeqNo] int NOT NULL DEFAULT ((0)),
    [Type] nvarchar(50) NOT NULL,
    [Descr] nvarchar(60) NOT NULL DEFAULT (''),
    [ObjectName] nvarchar(50) NOT NULL DEFAULT (''),
    [BitMap] nvarchar(20) NOT NULL DEFAULT (''),
    [PrevMenuID] int NOT NULL DEFAULT ((0)),
    [NextMenuID] int NOT NULL DEFAULT ((0)),
    [Visible] nvarchar(1) NULL DEFAULT ('Y'),
    [Enable] nvarchar(1) NULL DEFAULT ('Y'),
    CONSTRAINT [PK_rdsMenu] PRIMARY KEY ([MenuID], [SeqNo])
);
GO
