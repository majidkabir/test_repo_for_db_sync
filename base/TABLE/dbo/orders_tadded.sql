CREATE TABLE [dbo].[orders_tadded]
(
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Facility] nvarchar(5) NULL DEFAULT (' '),
    [Adddate] nvarchar(5) NULL,
    [OrderCnt] int NOT NULL,
    [Transmitflag] nvarchar(1) NULL DEFAULT ('0')
);
GO

CREATE INDEX [IX_ORDERS_TADDED] ON [dbo].[orders_tadded] ([Storerkey], [Facility]);
GO