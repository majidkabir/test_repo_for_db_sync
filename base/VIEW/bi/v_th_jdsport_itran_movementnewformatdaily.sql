SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_JDSPORT_Itran_MovementNewFormatDaily] AS
SELECT
   I.TranType,
   I.Lot,
   I.Sku,
   I.FromLoc,
   I.ToLoc,
   case
      when
         I.TranType = 'DP'
      then
         substring(I.SourceKey, 1, 10)
      else
         I.SourceKey
   end AS 'Sourcekey'
, I.LOTTABLE04 AS 'Lottable04',
   Case
      when
         I.TranType = 'DP'
      then
         'Inbound'
      when
         I.TranType = 'WD'
      then
         'Outbound'
      when
         I.TranType = 'MV'
      then
         'Inventory Movement'
      when
         I.TranType = 'ADJ'
      then
         'Adjust'
      else
         'unknow'
   end AS 'Sourcetype'
, I.ToID, I.Qty, convert(varchar, I.EffectiveDate, 103) AS 'Effectivedate', I.ItrnKey, convert(varchar, I.AddDate, 103) AS 'Adddate', I.AddWho, I.FromID, I.Lottable06,
   case
      when
         I.SourceType = 'ntrPickDetailUpdate'
      then
         I.SourceKey
      else
         SUBSTRING ( I.SourceKey, 1, 10 )
   end  AS 'Sourcekey2'
, I.StorerKey, convert(varchar, I.LOTTABLE04, 103) AS 'ExpiryDate', I.LOTTABLE05 AS 'Lottable6', convert(varchar, I.LOTTABLE05, 103) AS 'Receipt date', I.LOTTABLE02, I.SourceKey AS 'Sourcekey3',
   case
      when
         I.SourceType = 'ntrPickDetailUpdate'
      then
         I.SourceKey
      else
         SUBSTRING ( I.SourceKey, 11, 5 )
   end AS 'LineNumber'
, I.LOTTABLE05 AS 'Lottable05', I.EditDate,
   Case
      when
         I.EditWho in
         (
            'itadmin', 'iml'
         )
      then
         'System'
      else
         I.EditWho
   end AS 'Editwho'
, I.Lottable06 AS 'PalletID', I.Channel, I.LOTTABLE01, I.LOTTABLE03
FROM
   dbo.ITRN I
WHERE
   (
(I.StorerKey = 'JDSPORTS'
      AND I.SourceType NOT IN
      (
         'ntrReplenishmentUpdate', 'rdtfnc_Move_ID', 'WSPUTAWAY'
      )
      AND I.TranType <> 'MV'
      AND convert(varchar, I.EditDate, 112) >= convert(varchar, getdate() - 1, 112) )
   )

GO