SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSColor]
as
SElect
RDSColorLine	,
Storerkey	,
ColorCode	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSColor with (NOLOCK)


GO