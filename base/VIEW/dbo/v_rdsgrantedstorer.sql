SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_rdsGrantedStorer]
as
SElect
UserId	,
StorerKey	,
AddDate	,
AddWho	
from rdsGrantedStorer with (NOLOCK)



GO