CREATE TABLE [dbo].[taskdetailkey]
(
    [TaskdetailKey] bigint IDENTITY(1,1) NOT NULL,
    [AddDate] datetime NULL,
    CONSTRAINT [PK_TASKDETAILKEY] PRIMARY KEY ([TaskdetailKey])
);
GO
