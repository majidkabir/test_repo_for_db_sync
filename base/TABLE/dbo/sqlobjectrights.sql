CREATE TABLE [dbo].[sqlobjectrights]
(
    [Rowref] int IDENTITY(1,1) NOT NULL,
    [DBRole] nvarchar(20) NULL DEFAULT (''),
    [Schema] nvarchar(20) NULL DEFAULT ('dbo'),
    [OjbName] sysname NOT NULL,
    [RightFlag] varchar(4) NULL DEFAULT ('1000'),
    CONSTRAINT [PK_sqlobjectrights] PRIMARY KEY ([Rowref])
);
GO
