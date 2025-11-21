SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_IQC_IQCRPT_001                                */
/* Creation Date: 07-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18711                                                      */
/*                                                                         */
/* Called By: RPT_IQC_IQCRPT_001                                           */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 07-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 31-Oct-2023  WLChooi 1.1   UWP-10213 - Global Timezone (GTZ01)          */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_IQC_IQCRPT_001] @c_QCKey NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey  NVARCHAR(15)
         , @c_Type       NVARCHAR(1)  = N'1'
         , @c_DataWindow NVARCHAR(60) = N'RPT_IQC_IQCRPT_001'
         , @c_RetVal     NVARCHAR(255)

   SELECT @c_Storerkey = StorerKey
   FROM InventoryQC (NOLOCK)
   WHERE QC_Key = @c_QCKey

   EXEC [dbo].[isp_GetCompanyInfo] @c_Storerkey = @c_Storerkey
                                 , @c_Type = @c_Type
                                 , @c_DataWindow = @c_DataWindow
                                 , @c_RetVal = @c_RetVal OUTPUT

   SELECT InventoryQC.QC_Key
        , InventoryQC.StorerKey
        , InventoryQC.TradeReturnKey
        , InventoryQC.Refno
        , InventoryQC.from_facility
        , InventoryQC.to_facility
        , InventoryQCDetail.SKU
        , InventoryQCDetail.FromLoc
        , InventoryQCDetail.ToLoc
        , InventoryQCDetail.ToID
        , InventoryQCDetail.Reason
        , [dbo].[fnc_ConvSFTimeZone](InventoryQC.StorerKey, InventoryQC.from_facility, LOTATTRIBUTE.Lottable04) AS Lottable04   --GTZ01
        /*CODELKUP.Description,*/
        , Description = (  SELECT TOP 1 CODELKUP.Description
                           FROM CODELKUP (NOLOCK)
                           WHERE CODELKUP.LISTNAME = 'ASNREASON'
                           AND   CODELKUP.Code = InventoryQCDetail.Reason
                           AND   (CODELKUP.Storerkey = InventoryQCDetail.StorerKey OR ISNULL(CODELKUP.Storerkey, '') = '')
                           ORDER BY CODELKUP.Storerkey DESC)
        , InventoryQCDetail.ToQty
        , SKU.DESCR
        , PACK.CaseCnt
        , PACK.PackDescr
        /*TYPE = CASE WHEN ISNULL(InventoryQC.TradeReturnKey, '') <> '' Then 'Trade Return - ' + Ltrim(Inventoryqc.Reason) + ' (' + A.Description + ')' else 'LotxlocxID - '+ Ltrim(Inventoryqc.Reason) + ' (' + A.Description + ')' end,*/
        , TYPE = CASE WHEN ISNULL(InventoryQC.TradeReturnKey, '') <> '' THEN
                         'Trade Return - ' + LTRIM(InventoryQC.Reason) + ' ('
                         + (  SELECT TOP 1 A.Description
                              FROM CODELKUP A (NOLOCK)
                              WHERE A.LISTNAME = 'IQCTYPE'
                              AND   A.Code = InventoryQC.Reason
                              AND   (A.Storerkey = InventoryQC.StorerKey OR ISNULL(A.Storerkey, '') = '')
                              ORDER BY A.Storerkey DESC) + ')'
                      ELSE
                         'LotxlocxID - ' + LTRIM(InventoryQC.Reason) + ' ('
                         + (  SELECT TOP 1 A.Description
                              FROM CODELKUP A (NOLOCK)
                              WHERE A.LISTNAME = 'IQCTYPE'
                              AND   A.Code = InventoryQC.Reason
                              AND   (A.Storerkey = InventoryQC.StorerKey OR ISNULL(A.Storerkey, '') = '')
                              ORDER BY A.Storerkey DESC) + ')' END
        , [user_name] = SUSER_SNAME()
        , LOTATTRIBUTE.Lottable02
        , LOTATTRIBUTE.Lottable03
        , FrHostWhs = LOC.HOSTWHCODE
        , ToHostWhs = LOC2.HOSTWHCODE
        , InventoryQCDetail.QCLineNo
        , STORER.Company
        , CONVERT(NVARCHAR(60), InventoryQC.Notes) AS Notes
        , LOTATTRIBUTE.Lottable01
        , ISNULL(@c_RetVal, '') AS Logo
        , [dbo].[fnc_ConvSFTimeZone](InventoryQC.StorerKey, InventoryQC.from_facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM InventoryQC WITH (NOLOCK)
      , InventoryQCDetail WITH (NOLOCK)
      /*CODELKUP WITH (NOLOCK),*/
      /*CODELKUP A WITH (NOLOCK),*/
      , LOTATTRIBUTE WITH (NOLOCK)
      , PACK WITH (NOLOCK)
      , SKU WITH (NOLOCK)
      , LOC WITH (NOLOCK)
      , LOC LOC2 WITH (NOLOCK)
      , STORER WITH (NOLOCK)
   WHERE (InventoryQC.QC_Key = InventoryQCDetail.QC_Key)
   AND
      /*( InventoryQCDetail.Reason = CODELKUP.Code ) and*/
         (LOTATTRIBUTE.Lot = InventoryQCDetail.FromLot)
   AND   (InventoryQCDetail.StorerKey = SKU.StorerKey)
   AND   (InventoryQCDetail.SKU = SKU.Sku)
   AND
      /*( InventoryQC.Reason = A.Code ) and*/
      /*( A.Listname = 'IQCTYPE') and*/
      /*( CODELKUP.Listname = 'ASNREASON' ) and*/
         (SKU.PACKKey = PACK.PackKey)
   AND   (LOC.Loc = InventoryQCDetail.FromLoc)
   AND   (LOC2.Loc = InventoryQCDetail.ToLoc)
   AND   (InventoryQC.StorerKey = STORER.StorerKey)
   AND   (InventoryQC.QC_Key = @c_QCKey)

END

GO