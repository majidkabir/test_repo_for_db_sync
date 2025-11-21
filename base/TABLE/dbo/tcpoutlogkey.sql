CREATE TABLE [dbo].[tcpoutlogkey]
(
    [TCPOUTLogKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_TCPOUTLogKey] PRIMARY KEY ([TCPOUTLogKey])
);
GO
