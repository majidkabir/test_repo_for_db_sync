CREATE TABLE [dbo].[gvdoceventlog]
(
    [Rowref] bigint IDENTITY(1,1) NOT NULL,
    [DocumentNo] nvarchar(10) NOT NULL,
    [Transdate] datetime NOT NULL,
    [Storerkey] nvarchar(15) NOT NULL,
    [DocStatus] nvarchar(10) NOT NULL DEFAULT (''),
    [Event_LOC] nvarchar(45) NULL DEFAULT (''),
    [Event_Country] nvarchar(30) NULL DEFAULT (''),
    [Source_Order] nvarchar(30) NULL DEFAULT (''),
    [Event_Code] nvarchar(30) NULL DEFAULT (''),
    [Status] nvarchar(10) NULL DEFAULT ('0'),
    [AddDate] datetime NULL DEFAULT (getdate()),
    [EditDate] datetime NULL DEFAULT (getdate()),
    [Source_LineNumber] nvarchar(20) NULL DEFAULT (''),
    CONSTRAINT [PK_gvdoceventlog] PRIMARY KEY ([Rowref])
);
GO
