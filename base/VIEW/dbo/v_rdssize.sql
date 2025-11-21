SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSSize]
as
SElect
RDSSizeLine	,
Storerkey	,
SizeCode	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSSize with (NOLOCK)


GO