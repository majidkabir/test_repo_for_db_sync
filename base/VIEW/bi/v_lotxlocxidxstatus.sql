SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/*[TW] LOR Create new BI view for Jreport										      */
/*https://jiralfl.atlassian.net/browse/WMS-16997               		      */				       
/*Date         Author      Ver.  Purposes								         	*/
/*12-May-2021  GuanYan     1.0   Created                                   */
/***************************************************************************/

CREATE   VIEW [BI].[V_LOTXLOCXIDXSTATUS] AS

select inv.storerkey, inv.sku,inv.lot,inv.id,inv.loc,inv.qty,
inv.qtyallocated,inv.qtypicked,loc.locationflag as LOCHOLD, 
loc.status as HOLDLOC, lot.status as HOLDLOT,ID.status as HOLDID  
from 
dbo.LOTxLOCxID inv with (nolock)
left join loc (nolock) on  loc.loc=inv.loc
left join lot  (nolock) on lot.lot=inv.lot
left join id  (nolock) on  id.id=inv.id and id.id<>'' and inv.id<>''


GO