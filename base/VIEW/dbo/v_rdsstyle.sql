SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

create view [dbo].[V_RDSStyle]
as
SElect
Storerkey	,
Style	,
StyleDescr	,
GarmentType	,
HangFlat	,
SeasonCode	,
PO	,
Gender	,
Division	,
NMFCClass	,
NMFCCode	,
Remarks	,
Status	,
AddDate	,
AddWho	,
EditDate	,
EditWho	,
ArchiveCop	,
TrafficCop	
FROM RDSStyle with (NOLOCK)


GO