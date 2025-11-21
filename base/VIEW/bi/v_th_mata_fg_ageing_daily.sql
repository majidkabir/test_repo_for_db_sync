SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MATA_FG_Ageing_Daily] AS
select
   a.Storerkey,
   a.Facility,
   a.SKU,
   a.Qty,
   a.Inprocess,
   a.Customer,
   a.Serial,
   a.Rethread,
   a.ProducedDate,
   a.Age_Month,
   a.RO_NO,
   'Hold_Status' = b.status,
   b.description,
   a.WH_Facility
from
   (
      select
         ll.Storerkey,
         l.Facility,
         ll.SKU,
         ll.Qty,
         Inprocess = QtyAllocated + QtyPicked,
         Customer =
         case
            when
               lota.lottable01 = 'MICHELIN'
            then
               'MICHELIN'
            else
               substring (lota.lottable01, 5, 4)
         end
, Serial = lota.lottable02 , Rethread = substring(lota.lottable03, 1, 1) , 'ProducedDate' =
         case
            when
               lota.lottable01 = 'MICHELIN'
            then
               YMD
            else
               convert(varchar(10), lota.lottable05, 111)
         end
, 'Age_Month' =
         case
            when
               lota.lottable01 = 'MICHELIN'
            then
               isnull(datediff(mm, YMD, getdate()), '9999')
            else
               isnull(datediff(mm, convert(varchar(10), lota.lottable05, 111), getdate()), '9999')
         end
, RO_NO = substring(lota.Lottable03, 20 - charindex('/', REVERSE(substring(lota.Lottable03, 1, 18))), 12) , WH_Facility = lota.lottable12
      from
         lotattribute lota with (nolock)
		 JOIN lotxlocxid ll with (nolock) ON lota.lot = ll.lot
         JOIN loc l with (nolock) ON ll.loc = l.loc
         left outer join
            (
               select
                  *,
                  YMD = yy + '/' + mth + '/' + right(str(dt), 2)
               from
                  (
                     select
                        *,
                        dt =
                        case
                           when
                              Mth = '01'
                           then
                              dy
                           when
                              Mth = '02'
                           then
                              dy - 31
                           when
                              Mth = '03'
                           then
                              dy - 59
                           when
                              Mth = '04'
                           then
                              dy - 90
                           when
                              Mth = '05'
                           then
                              dy - 120
                           when
                              Mth = '06'
                           then
                              dy - 151
                           when
                              Mth = '07'
                           then
                              dy - 181
                           when
                              Mth = '08'
                           then
                              dy - 212
                           when
                              Mth = '09'
                           then
                              dy - 243
                           when
                              Mth = '10'
                           then
                              dy - 273
                           when
                              Mth = '11'
                           then
                              dy - 304
                           when
                              Mth = '12'
                           then
                              dy - 334
                        end
                     from
                        (
                           select
                              *,
                              Mth =
                              case
                                 when
                                    dy between '001' and '031'
                                 then
                                    '01'
                                 when
                                    dy between '032' and '059'
                                 then
                                    '02'
                                 when
                                    dy between '060' and '090'
                                 then
                                    '03'
                                 when
                                    dy between '091' and '120'
                                 then
                                    '04'
                                 when
                                    dy between '121' and '151'
                                 then
                                    '05'
                                 when
                                    dy between '152' and '181'
                                 then
                                    '06'
                                 when
                                    dy between '182' and '212'
                                 then
                                    '07'
                                 when
                                    dy between '213' and '243'
                                 then
                                    '08'
                                 when
                                    dy between '244' and '273'
                                 then
                                    '09'
                                 when
                                    dy between '274' and '304'
                                 then
                                    '10'
                                 when
                                    dy between '305' and '334'
                                 then
                                    '11'
                                 when
                                    dy between '335' and '366'
                                 then
                                    '12'
                              end
                           from
                              (
                                 select
                                    lot,
                                    lottable02,
                                    YY =
                                    Case
                                       when
                                          substring(lottable02, 1, 1) between 0 and 9
                                          and substring(lottable02, 5, 1) in
                                          (
                                             'c',
                                             'r',
                                             's',
                                             'j',
                                             'n'
                                          )
                                          --('b','f','k','t','n','p')
                                       then
                                          '201' + substring(lottable02, 1, 1)
                                       when
                                          substring(lottable02, 1, 1) between 0 and 9
                                          and substring(lottable02, 5, 1) in
                                          (
                                             'b', 'f', 'p', 't', 'k', 'e'
                                          )
                                       then
                                          '199' + substring(lottable02, 1, 1)
                                       else
                                          '200' + substring(lottable02, 1, 1)
                                    end
, DY = substring(lottable02, 2, 3)
                                 from
                                    lotattribute with (nolock)
                                 where
                                    storerkey = 'MATA'
                                    and lot in
                                    (
                                       select
                                          lot
                                       from
                                          lotxlocxid with (nolock)
                                       where
                                          storerkey = 'MATA'
                                          and qty <> 0
                                    )
                                    and substring(lottable02, 1, 1) between '0' and '9'
                                    and substring(lottable02, 2, 1) between '0' and '9'
                                    and substring(lottable02, 3, 1) between '0' and '9'
                                    and substring(lottable02, 4, 1) between '0' and '9'
                                    and substring(lottable02, 5, 1) in
                                    (
                                       'c',
                                       'r',
                                       's',
                                       'j',
                                       'n',
                                       'w',
                                       'u',
                                       'b',
                                       'f',
                                       'p',
                                       't',
                                       'k',
                                       'e',
                                       'a',
                                       'g',
                                       'l',
                                       'm'
                                    )
                                    --('b','f','k','t','n','p','a','g','l','w','u')
                              )
                              PD
                        )
                        YYMMDD
                  )
                  YYYYMMDD
            )
            live
            on ll.lot = live.lot
      where
         ll.storerkey = 'MATA'
         and ll.qty <> 0
         --and ll.lot = lota.lot
         --and ll.loc = l.loc
         and l.facility in
         (
            'IND',
            'MCNKA',
            'MCNKF'
         )
   )
   a
   left outer join
      (
         select
            'INVSKU' = inh.sku,
            inh.lottable02,
            inh.status,
            cdk.description
         from
            inventoryhold inh with (nolock)
         JOIN codelkup cdk with (nolock) ON inh.status = cdk.code
         where
            inh.storerkey = 'MATA'
            and cdk.code like 'MATA%'
            and cdk.listname = 'INVHOLD'
      )
      b
      on a.serial = b.lottable02
--order by
--   a.serial

GO