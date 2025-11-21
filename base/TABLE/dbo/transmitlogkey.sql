CREATE TABLE [dbo].[transmitlogkey]
(
    [TransmitlogKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_TRANSMITLOGKEY] PRIMARY KEY ([TransmitlogKey])
);
GO
