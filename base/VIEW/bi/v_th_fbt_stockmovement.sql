SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_FBT_Stockmovement] AS
  SELECT
   AL5.storerkey AS ' StorerKey',
   AL5.fromfacility AS 'Fromfacility',
   AL5.tofacility AS 'Tofacility',
   AL5.effectivedate AS 'Effectivedate',
   AL5.orderdate AS 'OrderDate',
   case
      when
         Sourcetype = 'ntrReceiptDetailAdd'
      then
         R.ExternReceiptKey
      else
         case
            when
               Sourcetype = 'ntrReceiptDetailUpdate'
            then
               R.ExternReceiptKey
            else
               case
                  when
                     Sourcetype = 'ntrTransferDetailUpdate'
                  then
                     T.TransferKey
                  else
(AL5.itrnexternorderkey)
               end
         end
   end AS 'Externorderkey'
, R.POKey, R.WarehouseReference, AL5.sku, SUM ( AL5.qty ) AS 'Sum(Qty)', AL5.expirydate AS 'ExpiryDate', R.RECType, AL5.trantype AS 'Trantype', AL5.sourcetype AS 'Sourcetype', AL5.adddate AS 'Adddate', AL5.addwho AS 'Addwho',
   case
      when
         sourcetype = 'ntrAdjustmentDetailUpdate'
      then
         A.Remarks
      else
         case
            when
               sourcetype = 'ntrKitDetailAdd'
            then
               K.Remarks
            else
               case
                  when
                     sourcetype = 'ntrKitDetailUpdate'
                  then
                     K.Remarks
                  else
                     case
                        when
                           sourcetype = 'ntrReceiptDetailUpdate'
                        then
                           R.Notes
                        else
                           case
                              when
                                 sourcetype = 'ntrTransferDetailUpdate'
                              then
                                 T.Remarks
                              else
                                 AL5.notes
                           end
                     end
               end
         end
   end AS 'Remark'
, AL5.itrnexternorderkey, R.CarrierName, AL5.consigneekey, AL5.c_company, AL5.c_address1, R.CarrierAddress1, R.CarrierKey, R.ExternReceiptKey, AL5.lottable06, AL5.lottable07
FROM dbo.RECEIPT R with (nolock)
   RIGHT OUTER JOIN
      (
         SELECT
            Case
               when
                  D4R.TranType = 'DP'
               then
                  'Receive IN'
               when
                  D4R.TranType = 'WD'
               then
                  'Ship OUT'
               when
                  D4R.TranType = 'MV'
               then
                  'Move'
               when
                  D4R.TranType = 'ADJ'
               then
                  'Adjust'
               else
                  D4R.TranType
            end
, D4R.Sku, D4R.FromLoc, D4R.ToLoc, D4R.SourceKey, D4R.SourceType, D4R.LOTTABLE01, D4R.Qty, convert(varchar, D4R.EffectiveDate, 103), convert(varchar, D4R.AddDate, 103), D4R.AddWho,
            case
               when
                  D4R.SourceType = 'ntrInventoryQCDetailUpdate'
               then
                  SUBSTRING ( D4R.SourceKey, 1, 10 )
               else
                  case
                     when
                        D4R.SourceType = 'ntrKitDetailAdd'
                     then
                        SUBSTRING ( D4R.SourceKey, 1, 10 )
                     else
                        case
                           when
                              D4R.SourceType = 'ntrKitDetailUpdate'
                           then
                              SUBSTRING ( D4R.SourceKey, 1, 10 )
                           else
                              case
                                 when
                                    D4R.SourceType = 'ntrAdjustmentDetailUpdate'
                                 then
                                    SUBSTRING ( D4R.SourceKey, 1, 10 )
                                 else
                                    D4K.ExternOrderKey
                              end
                        end
                  end
            end
, D4AL5.Facility, D4AL6.Facility,
            case
               when
                  D4R.SourceType = 'ntrPickDetailUpdate'
               then
                  D4R.SourceKey
               else
                  SUBSTRING ( D4R.SourceKey, 1, 10 )
            end
, D4R.StorerKey, convert(varchar, D4R.LOTTABLE04, 103), convert(varchar, D4R.LOTTABLE05, 103), D4A.Notes, convert(varchar, D4K.OrderDate, 103), D4K.ConsigneeKey, D4K.C_Company, D4K.C_Address1, D4R.Lottable06, D4R.Lottable07
         FROM
            dbo.ITRN D4R
            LEFT OUTER JOIN
               dbo.PICKDETAIL D4A with (nolock)
               ON (D4A.PickDetailKey = D4R.SourceKey)
            LEFT OUTER JOIN
               dbo.ORDERS D4K with (nolock)
               ON (D4K.OrderKey = D4A.OrderKey)
            LEFT OUTER JOIN
               dbo.LOC D4AL5 with (nolock)
               ON (D4AL5.Loc = D4R.FromLoc)
            LEFT OUTER JOIN
               dbo.LOC D4AL6 with (nolock)
               ON (D4AL6.Loc = D4R.ToLoc)
         WHERE
            (
(D4R.StorerKey = 'FBT'
               AND convert(varchar, D4R.AddDate, 112) > convert(varchar, DATEADD(MONTH, DATEDIFF(MONTH, 0, getdate()), 0), 112)
               and convert(varchar, D4R.AddDate, 112) <= convert(varchar, getdate() + 1, 112)
               AND
               (
                  NOT D4R.TranType = 'MV'
               )
)
            )
      )
      AL5 (trantype, sku, fromloc, toloc, sourcekey, sourcetype, wh_code, qty, effectivedate, adddate, addwho, itrnexternorderkey, fromfacility, tofacility, sourcekey2, storerkey, expirydate, receiptdate_, notes, orderdate, consigneekey, c_company, c_address1, lottable06, lottable07)
      ON (R.ReceiptKey = AL5.sourcekey2)
   LEFT OUTER JOIN
      dbo.TRANSFER T with (nolock)
      ON (T.TransferKey = AL5.sourcekey2)
   LEFT OUTER JOIN
      dbo.ADJUSTMENT A with (nolock)
      ON (AL5.sourcekey2 = A.AdjustmentKey)
   LEFT OUTER JOIN
      dbo.KIT K with (nolock)
      ON (AL5.sourcekey2 = K.KITKey)
GROUP BY
   AL5.storerkey, AL5.fromfacility, AL5.tofacility, AL5.effectivedate, AL5.orderdate,
   case
      when
         Sourcetype = 'ntrReceiptDetailAdd'
      then
         R.ExternReceiptKey
      else
         case
            when
               Sourcetype = 'ntrReceiptDetailUpdate'
            then
               R.ExternReceiptKey
            else
               case
                  when
                     Sourcetype = 'ntrTransferDetailUpdate'
                  then
                     T.TransferKey
                  else
(AL5.itrnexternorderkey)
               end
         end
   end
, R.POKey, R.WarehouseReference, AL5.sku, AL5.expirydate, R.RECType, AL5.trantype, AL5.sourcetype, AL5.adddate, AL5.addwho,
   case
      when
         sourcetype = 'ntrAdjustmentDetailUpdate'
      then
         A.Remarks
      else
         case
            when
               sourcetype = 'ntrKitDetailAdd'
            then
               K.Remarks
            else
               case
                  when
                     sourcetype = 'ntrKitDetailUpdate'
                  then
                     K.Remarks
                  else
                     case
                        when
                           sourcetype = 'ntrReceiptDetailUpdate'
                        then
                           R.Notes
                        else
                           case
                              when
                                 sourcetype = 'ntrTransferDetailUpdate'
                              then
                                 T.Remarks
                              else
                                 AL5.notes
                           end
                     end
               end
         end
   end
, AL5.itrnexternorderkey, R.CarrierName, AL5.consigneekey, AL5.c_company, AL5.c_address1, R.CarrierAddress1, R.CarrierKey, R.ExternReceiptKey, AL5.lottable06, AL5.lottable07

GO