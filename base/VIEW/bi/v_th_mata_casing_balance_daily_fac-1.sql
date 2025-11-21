SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MATA_Casing_Balance_Daily_fac-1] AS
SELECT
   IIB.storerkey,
   A.Lottable12 AS 'Facility',
   S.SKUGROUP,
   IIB.sku,
   SUBSTRING(S.DESCR,
   (
      CASE
         WHEN
            S.DESCR like '%;%'
         THEN
            CHARINDEX(';', S.DESCR) + 1
         ELSE
            1
      END
   )
, 250)AS 'Size', ' ' AS 'Sourcekey', A.Lottable07 AS 'Airline', A.Lottable06 AS 'Customer_Code', A.Lottable01 AS 'Prod/Pool',
   Case
      when
         Substring(A.Lottable08, 1, 2) like'%/%'
      then
         Substring(A.Lottable08, 1, 1)
      when
         Substring(A.Lottable08, 1, 3) like'%/%'
      then
         Substring(A.Lottable08, 1, 2)
      when
         Substring(A.Lottable08, 1, 4) like'%/%'
      then
         Substring(A.Lottable08, 1, 3)
      when
         Substring(A.Lottable08, 1, 5) like'%/%'
      then
         Substring(A.Lottable08, 1, 4)
      when
         Substring(A.Lottable08, 1, 6) like'%/%'
      then
         Substring(A.Lottable08, 1, 5)
      when
         Substring(A.Lottable08, 1, 7) like'%/%'
      then
         Substring(A.Lottable08, 1, 6)
      when
         Substring(A.Lottable08, 1, 8) like'%/%'
      then
         Substring(A.Lottable08, 1, 7)
      when
         Substring(A.Lottable08, 1, 9) like'%/%'
      then
         Substring(A.Lottable08, 1, 8)
      when
         Substring(A.Lottable08, 1, 9) like'%/%'
      then
         Substring(A.Lottable08, 1, 8)
      when
         Substring(A.Lottable08, 1, 10) like'%/%'
      then
         Substring(A.Lottable08, 1, 9)
      else
         A.Lottable08
   end AS 'Status'
, convert(varchar(18), isnull(rtrim(A.Lottable02), ''))AS 'SN#', substring(A.Lottable03, 1, 1) AS 'R_Level', A.Lottable09 AS 'RO No.', SUBSTRING(A.Lottable10, 1,
   CASE
      CHARINDEX('/', A.Lottable10)
      WHEN
         0
      THEN
         LEN(A.Lottable10)
      ELSE
         CHARINDEX('/', A.Lottable10) - 1
   END
) AS 'RGA No.', A.Lottable11 AS 'Remark', SUBSTRING(A.Lottable10,
   CASE
      CHARINDEX('/', A.Lottable10)
      WHEN
         0
      THEN
         LEN(A.Lottable10) + 1
      ELSE
         CHARINDEX('/', A.Lottable10) + 1
   END
, 1000) AS 'User Require', A.Lottable13 AS 'Status Change date for CSG', convert(datetime, convert(char(10), getdate(), 120)) AS 'Exportdate', A.Lottable03 AS 'R_Level2', convert(datetime, convert(char(10), A.Lottable05, 120)) AS 'Receipt Date', DATEDIFF ( day, A.Lottable05, getdate()) AS 'No Of Day',
   Case
      When
         IIB.qtypicked > 0
      Then
         ' R3STAGING '
      Else
         IIB.loc
   End AS 'Loc'
,
   CASE
      WHEN
         LOC.Status = 'Hold'
      THEN
         ''
      WHEN
         LOT.Status = 'Hold'
      THEN
         ''
      ELSE
         IIB.qty
   END AS 'AvaiableQty'
, IIB.qtyallocated + IIB.qtypicked AS 'On Process',
   CASE
      WHEN
         LOC.Status = 'Hold'
      THEN
         IIB.qty
      WHEN
         LOT.Status = 'Hold'
      THEN
         IIB.qty
      ELSE
         ''
   END AS 'Hold Qty'
,
   Case
      When
         A.Lottable12 = 'EANKE'
      Then
         'EMANKE'
      When
         A.Lottable12 = 'MCNKC'
      Then
         'MSCNKC'
      When
         A.Lottable12 = 'MCNKE'
      Then
         'MSCNKE'
      When
         A.Lottable12 = 'NKG'
      Then
         'NKG'
      When
         A.Lottable12 = 'NMNKC'
      Then
         'NAMNKC'
      When
         A.Lottable12 = 'NMNKE'
      Then
         'NAMNKE'
      When
         A.Lottable12 = 'MCCHC'
      Then
         'MSCCHC'
      When
         A.Lottable12 = 'MCCHE'
      Then
         'MSCCHE'
      When
         A.Lottable12 = 'MCNKR'
      Then
         'MSCNKR'
      When
         A.Lottable12 = 'EANKR'
      Then
         'EMANKR'
   End AS 'MATA Branch'
, A.Lottable01, IIB.lot,
   case
      when
         charindex('/', A.Lottable03, 3) = 0
      then
         ' '
      else
         case
            when
               charindex('/', A.Lottable03, 3) = 4
            then
               substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 1)
            else
               case
                  when
                     charindex('/', A.Lottable03, 3) = 5
                  then
                     substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 2)
                  else
                     case
                        when
                           charindex('/', A.Lottable03, 3) = 6
                        then
                           substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 3)
                        else
                           case
                              when
                                 charindex('/', A.Lottable03, 3) = 7
                              then
                                 substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 4)
                              else
                                 case
                                    when
                                       charindex('/', A.Lottable03, 3) = 8
                                    then
                                       substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 5)
                                    else
                                       case
                                          when
                                             charindex('/', A.Lottable03, 3) = 9
                                          then
                                             substring(A.Lottable03, charindex('/', A.Lottable03) + 1, 5)
                                       end
                                 end
                           end
                     end
               end
         end
   end AS 'Computed'
, A.Lottable06,
   case
      when
         Substring(A.Lottable08, 1, 2) like'%/%'
      then
         Substring(A.Lottable08, 3, 12)
      when
         Substring(A.Lottable08, 1, 3) like'%/%'
      then
         Substring(A.Lottable08, 4, 12)
      when
         Substring(A.Lottable08, 1, 4) like'%/%'
      then
         Substring(A.Lottable08, 5, 12)
      when
         Substring(A.Lottable08, 1, 5) like'%/%'
      then
         Substring(A.Lottable08, 6, 12)
      when
         Substring(A.Lottable08, 1, 6) like'%/%'
      then
         Substring(A.Lottable08, 7, 12)
      when
         Substring(A.Lottable08, 1, 7) like'%/%'
      then
         Substring(A.Lottable08, 8, 12)
      when
         Substring(A.Lottable08, 1, 8) like'%/%'
      then
         Substring(A.Lottable08, 9, 12)
      when
         Substring(A.Lottable08, 1, 9) like'%/%'
      then
         Substring(A.Lottable08, 10, 12)
      when
         Substring(A.Lottable08, 1, 10) like'%/%'
      then
         Substring(A.Lottable08, 11, 12)
      Else
         ' '
   end AS 'HoldGroup'
, A.Lottable14, LOT.Status AS 'StatusHold', S.MANUFACTURERSKU AS 'PartNo', IIB.id AS 'Pallet_ID',
   Case
      When
         IIB.qtypicked > 0
      Then
         'PICKED ORDER NO ' + O.ExternOrderKey
      Else
         Case
            When
               IIB.qtyallocated > 0
            Then
               'RESERVED ORDER NO ' + O.ExternOrderKey
            Else
               ''
         End
   End AS 'Order Number'
, O.AddDate AS 'Orderdate'
FROM
   dbo.ids_inventory_balance IIB with (nolock)
   LEFT OUTER JOIN
      dbo.SKU S with (nolock)
      ON (IIB.storerkey = S.StorerKey
      AND IIB.sku = S.Sku)
   LEFT OUTER JOIN
      dbo.LOTATTRIBUTE A with (nolock)
      ON (IIB.storerkey = A.StorerKey
      AND IIB.sku = A.Sku
      AND IIB.lot = A.Lot)
   LEFT OUTER JOIN
      dbo.LOC LOC with (nolock)
      ON (IIB.loc = LOC.Loc)
   LEFT OUTER JOIN
      dbo.LOT LOT with (nolock)
      ON (IIB.lot = LOT.Lot)
   LEFT OUTER JOIN
      dbo.PICKDETAIL PD with (nolock)
      ON (PD.Storerkey = IIB.storerkey
      AND PD.Sku = IIB.sku
      AND PD.Lot = IIB.lot)
   LEFT OUTER JOIN
      dbo.ORDERS O with (nolock)
      ON (O.OrderKey = PD.OrderKey)
WHERE
   (
(IIB.storerkey = 'MATA'
      AND LOC.Facility in
      (
         'NMNKC', 'MCNKC', 'NKG', 'EANKE', 'NMNKE', 'MCNKE'
      )
      AND IIB.exportdate >= convert(varchar(10), getdate(), 120))
   )

GO