SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSColorDetail]
as
SElect
RDSColorLine	,
Storerkey	,
SeqNo	,
ColorCode	,
ColorAbbrev	,
Descr	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSColorDetail with (NOLOCK)


GO