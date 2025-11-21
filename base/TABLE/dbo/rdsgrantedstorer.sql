CREATE TABLE [dbo].[rdsgrantedstorer]
(
    [UserId] nvarchar(128) NOT NULL,
    [StorerKey] nvarchar(15) NOT NULL,
    [AddDate] datetime NOT NULL DEFAULT (getdate()),
    [AddWho] nvarchar(128) NOT NULL DEFAULT (suser_sname()),
    CONSTRAINT [PK_lrdsGrantedStorer] PRIMARY KEY ([UserId], [StorerKey])
);
GO
