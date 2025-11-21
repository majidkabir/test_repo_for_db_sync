CREATE TABLE [dbo].[orders_tactivity]
(
    [Storerkey] nvarchar(15) NOT NULL DEFAULT (' '),
    [Facility] nvarchar(5) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT (' '),
    [OrderCnt] int NOT NULL,
    [Event_Hour] nvarchar(5) NULL,
    [Transmitflag] nvarchar(1) NULL DEFAULT ('0')
);
GO

CREATE INDEX [IX_ORDERS_TACTIVITY] ON [dbo].[orders_tactivity] ([Storerkey], [Facility]);
GO