CREATE TABLE [dbo].[tabledeletelog]
(
    [Seq_No] int IDENTITY(1,1) NOT NULL,
    [DeleteDate] datetime NOT NULL DEFAULT (getdate()),
    [DeleteBy] nvarchar(128) NULL DEFAULT (suser_sname()),
    [TableName] nvarchar(50) NOT NULL,
    [Col1] nvarchar(30) NULL DEFAULT (''),
    [Col2] nvarchar(30) NULL DEFAULT (''),
    [Col3] nvarchar(30) NULL DEFAULT (''),
    [Col4] nvarchar(30) NULL DEFAULT (''),
    [Col5] nvarchar(30) NULL DEFAULT (''),
    [Remarks] nvarchar(1024) NULL DEFAULT (''),
    CONSTRAINT [PK_TableDeleteLog] PRIMARY KEY ([Seq_No])
);
GO
