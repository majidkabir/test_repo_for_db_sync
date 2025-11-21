SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[v_NIKECN_ChkLOTMinMaxApart90Days] as

select loc.facility, lli.loc, lli.sku, lli.lot,
   convert( char( 10), la.lottable05, 120) AS lottable05,
   (lli.qty + lli.qtyallocated) AS QTY,
   la.lottable01, la.lottable02, la.lottable03, la.lottable04
from lotxlocxid lli (nolock)
   inner join lotattribute la (nolock) on (lli.lot = la.lot)
   inner join loc (nolock) on (lli.loc = loc.loc)
   inner join
   (
      select lli.loc, lli.storerkey, lli.sku
      from lotxlocxid lli (nolock)
         inner join lotattribute la (nolock) on (lli.lot = la.lot)
         inner join loc (nolock) on (lli.loc = loc.loc)
      where lli.storerkey = 'NIKECN'
         and (lli.qty + lli.qtyallocated) > 0
         and loc.facility = 'NGZ01'
      group by lli.loc, lli.storerkey, lli.sku
      having datediff( dd, min( lottable05), max( lottable05)) > 90
   ) a on (a.loc = lli.loc and a.storerkey = lli.storerkey and a.sku = lli.sku)
--order by loc.facility, lli.loc, lli.sku, la.lottable05


GO