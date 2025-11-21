CREATE TABLE [dbo].[wms_connection_sum]
(
    [SEQ] int IDENTITY(1,1) NOT NULL,
    [datetime] datetime NOT NULL DEFAULT (getdate()),
    [the_database] nvarchar(50) NOT NULL,
    [is_user_process] nvarchar(5) NOT NULL,
    [total_database_connections] int NOT NULL,
    CONSTRAINT [PK_wms_connection_sum] PRIMARY KEY ([SEQ])
);
GO
