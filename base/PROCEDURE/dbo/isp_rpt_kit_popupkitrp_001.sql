SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_KIT_POPUPKITRP_001                            */
/* Creation Date: 21-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18809                                                      */
/*                                                                         */
/* Called By: RPT_KIT_POPUPKITRP_001                                       */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 21-Jan-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 14-Apr-2023  WZPang  1.1   WMS-21810 - Modify Columns                   */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_KIT_POPUPKITRP_001]
      @c_KITKey        NVARCHAR(20)

AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT KITDETAIL.KitKey,
          KITDETAIL.StorerKey,
          KITDETAIL.Sku,
          KITDETAIL.ExpectedQty,
          KIT.ExternKitKey,      --(WZ01)
          --KIT.CustomerRefNo,
          PACK.Casecnt,
          SKU.Busr6,
          SKU.Busr7
   FROM KIT (NOLOCK)
   JOIN KITDETAIL (NOLOCK) ON (KIT.KITKey = KITDETAIL.KITKey)
   JOIN ( SELECT Kitkey, SUM(ExpectedQty) FromSkuQty
          FROM KITDETAIL (NOLOCK)
          WHERE   (KITDETAIL.[Type] = 'T' )
          GROUP BY Kitkey ) KDF ON (KITDETAIL.Kitkey = KDF.Kitkey)
   JOIN SKU (NOLOCK) ON (KITDETAIL.Storerkey = SKU.Storerkey)
                    AND (KITDETAIL.Sku = SKU.Sku)
   JOIN PACK (NOLOCK) ON (KITDETAIL.Packkey = Pack.Packkey)
   WHERE (KITDETAIL.[Type] = 'T' )
	AND   (KITDETAIL.ExpectedQty > 0   )
	AND   (KIT.[Status] < '9' )
   AND   (KDF.FromSkuQty   > 0   )
   AND   (KIT.Kitkey = @c_KITKey )

END

GO