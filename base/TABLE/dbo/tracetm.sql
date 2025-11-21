CREATE TABLE [dbo].[tracetm]
(
    [Seqno] int IDENTITY(1,1) NOT NULL,
    [SP] nvarchar(20) NULL,
    [TaskDetailKey] nvarchar(10) NULL,
    [UserKey] nvarchar(18) NULL,
    [AddDate] datetime NOT NULL
);
GO
