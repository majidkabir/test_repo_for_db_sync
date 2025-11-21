SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-00_Alert wrong MFG Date] as
select x.StorerKey, x.loc, x.sku, x.qty, x.lotNo, x.MFGDate, x.EXPDate, x.ReceivedDate
from (
	select X.StorerKey, X.loc, X.sku, X.qty, A.lottable02 as lotNo, 
		A.lottable03 as MFGDate, convert(varchar, A.lottable04, 120) as EXPDate, 
		convert(varchar, A.lottable05, 120) as ReceivedDate
	from LOTxLOCxID X with (nolock)
	JOIN LOTAttribute A with (nolock) ON X.StorerKey = A.StorerKey 
			and X.Lot = A.Lot 
			and X.Sku = A.Sku 
	where X.storerkey = 'YVESR' 
	and len(A.lottable03) <> 10 and A.lottable03 is not null 
	and A.lottable03 <> '' 
	and (substring(A.lottable03,1,2) not in ('01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31')
			or substring(A.lottable03,4,2) not in ('01','02','03','04','05','06','07','08','09','10','11','12')
			or substring(A.lottable03,7,2) in ('00')
			or substring(A.lottable03,3,1) = '/' or substring(A.lottable03,6,2) = '/' 
		)
	and X.qty > 0 
	union all
	select X.StorerKey, X.loc, X.sku, X.qty, A.lottable02 as lotNo, 
		A.lottable03 as MFGDate, convert(varchar, A.lottable04, 120) as EXPDate, 
		convert(varchar, A.lottable05, 120) as ReceivedDate
	from LOTxLOCxID X with (nolock)
	JOIN LOTAttribute A with (nolock) ON X.StorerKey = A.StorerKey 
			and X.Lot = A.Lot 
			and X.Sku = A.Sku 
	where X.storerkey = 'YVESR' 
	and A.lottable03 <> '' 
	and substring(A.lottable03,4,2) not in ('01','02','03','04','05','06','07','08','09','10','11','12')
	and X.qty > 0
) x 

GO