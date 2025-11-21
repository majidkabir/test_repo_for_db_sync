SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_Item_Balance] AS 
SELECT RTrim(AL2.StorerKey) STORERKEY,
       SubString(AL3.Facility, 3, 2) FACILITY,
       RTrim(AL2.Sku) SKU,
       RTrim(AL3.HOSTWHCODE) HOSTWHCODE,
       RTrim(AL1.Lottable02) LOTTABLE02,
       RTrim(AL2.StorerKey) +
       SubString(AL3.Facility, 3, 2) +
       RTrim(AL2.Sku) +
       RTrim(AL3.HOSTWHCODE) +
       RTrim(AL1.Lottable02) SURROGATEKEYIDS,
       SUM(AL2.Qty) IDS_QTY
FROM   lotattribute AL1 (NOLOCK) 
       INNER JOIN lotxlocxid AL2 (NOLOCK) ON (AL1.Lot = AL2.Lot)
       INNER JOIN loc AL3 (NOLOCK) ON (AL2.Loc = AL3.Loc)
       JOIN StorerConfig AL4 (NOLOCK) ON 
                     (AL1.StorerKey = AL4.StorerKey  
               AND    SValue = '1'
               AND    AL4.ConfigKey  =  'OWITF')
GROUP BY RTrim(AL2.StorerKey),
         SubString(AL3.Facility, 3, 2),
         RTrim(AL2.Sku),
         RTrim(AL3.HOSTWHCODE),
         RTrim(AL1.Lottable02),
         RTrim(AL2.StorerKey) +
         SubString(AL3.Facility, 3, 2) +
         RTrim(AL2.Sku) +
         RTrim(AL3.HOSTWHCODE) +
         RTrim(AL1.Lottable02)





GO