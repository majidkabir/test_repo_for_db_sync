CREATE TABLE [dbo].[mbolshiplog]
(
    [StorerKey] nvarchar(15) NOT NULL,
    [MBOLKey] nvarchar(10) NOT NULL,
    [Status] nvarchar(1) NOT NULL,
    CONSTRAINT [PKMBOLShipLog] PRIMARY KEY ([MBOLKey])
);
GO
