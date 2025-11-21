SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE   view [BI].[V_TH_YVSER-08_Remaining Day Lessthan 18M] as
SELECT
   Convert(varchar, GetDate() - 1, 103) as 'Date now',
   'PRODUCTS' as 'Products',
   S.SUSR3,
   S.SUSR4,
   S.SUSR5,
   S.Sku,
   S.MANUFACTURERSKU,
   S.DESCR,
   X.Qty - (X.QtyAllocated + X.QtyPicked + X.QtyExpected + X.QtyPickInProcess)  as 'Qty Avl'
FROM
   dbo.LOTxLOCxID X with (nolock)
JOIN dbo.LOTATTRIBUTE A with (nolock) ON X.StorerKey = A.StorerKey 
      AND X.Sku = A.Sku 
      AND X.Lot = A.Lot 
JOIN dbo.LOC L with (nolock) ON X.Loc = L.Loc
JOIN dbo.SKU S with (nolock) ON X.StorerKey = S.StorerKey 
      AND X.Sku = S.Sku 
WHERE
   (
(S.StorerKey = 'YVESR' 
      AND L.Loc NOT IN 
      (
         'EXPSTG',
         'LOSSWH',
         'SPOILSTG',
         'VARCOUNT',
         'VARRECIMP',
         'VARRECLOC',
         'VARRETURN'
      )
      AND A.Lottable04 < GetDate() - 540 
      AND X.Qty <> 0)
   )

GO