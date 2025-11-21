CREATE TABLE [dbo].[pickorderlog]
(
    [Orderkey] nvarchar(10) NOT NULL,
    [Zone] nvarchar(10) NOT NULL,
    [SPID] int NOT NULL,
    [Status] nvarchar(1) NOT NULL DEFAULT ('0'),
    [AddWho] nvarchar(128) NOT NULL,
    CONSTRAINT [PK_PICKORDERLOG] PRIMARY KEY ([Orderkey], [Zone])
);
GO
