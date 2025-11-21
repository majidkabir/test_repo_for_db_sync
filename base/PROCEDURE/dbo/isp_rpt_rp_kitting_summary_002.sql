SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_RP_KITTING_SUMMARY_002                      */
/* Creation Date: 10-Feb-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-21729 - [TW]-EAT Logi Report_Kitting Summary_CR          */
/*                                                                       */
/* Called By: RPT_RP_KITTING_SUMMARY_002                                 */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 10-Feb-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_KITTING_SUMMARY_002]
(
   @c_Kitkey_Start        NVARCHAR(10)
 , @c_Kitkey_End          NVARCHAR(10)
 , @c_Storerkey_Start     NVARCHAR(15)
 , @c_Storerkey_End       NVARCHAR(15)
 , @c_EffectiveDate_Start DATETIME
 , @c_EffectiveDate_End   DATETIME
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT KIT.KITKey
        , KIT.ReasonCode
        , KIT.CustomerRefNo
        , KIT.EffectiveDate
        , KIT.StorerKey
        , KITDETAIL.Sku
        , KITDETAIL.Qty
        , KITDETAIL.Loc
        , KITDETAIL.LOTTABLE01
        , KITDETAIL.LOTTABLE04
        , KITDETAIL.KITLineNumber
        , KITDETAIL.Type
        , KITDETAIL.LOTTABLE02
        , KITDETAIL.LOTTABLE03
        , KITDETAIL.LOTTABLE05
        , KITDETAIL.PackKey
        , KITDETAIL.UOM
        , KITDETAIL.Lot
        , SKU.DESCR
        , KIT.ExternKitKey
        , KIT.Remarks
   FROM KIT (NOLOCK)
   JOIN KITDETAIL (NOLOCK) ON (KIT.KITKey = KITDETAIL.KITKey)
   JOIN SKU (NOLOCK) ON (KITDETAIL.StorerKey = SKU.StorerKey) AND (KITDETAIL.Sku = SKU.Sku)
   WHERE ( KIT.KITKey BETWEEN @c_Kitkey_Start AND @c_Kitkey_End ) AND         ( KIT.Storerkey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End ) AND         ( KIT.EffectiveDate BETWEEN @c_EffectiveDate_Start AND @c_EffectiveDate_End )

END

GO