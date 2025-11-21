CREATE TABLE [dbo].[orders_alert]
(
    [Storerkey] nvarchar(15) NULL DEFAULT (' '),
    [Facility] nvarchar(5) NULL DEFAULT (' '),
    [Status] nvarchar(10) NULL DEFAULT (' '),
    [OrderCnt] int NOT NULL,
    [Aging_Hours] nvarchar(5) NULL,
    [Transmitflag] nvarchar(1) NULL DEFAULT ('0')
);
GO

CREATE INDEX [IX_ORDERS_ALERT] ON [dbo].[orders_alert] ([Storerkey], [Facility]);
GO