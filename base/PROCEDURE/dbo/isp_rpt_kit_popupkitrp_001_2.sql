SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: isp_RPT_KIT_POPUPKITRP_001_2                          */
/* Creation Date: 21-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18809                                                      */
/*                                                                         */
/* Called By: RPT_KIT_POPUPKITRP_001_2                                     */
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
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_KIT_POPUPKITRP_001_2]
      @c_KITKey        NVARCHAR(20)
    , @n_ExpectedQty   INT

AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT KITDETAIL.Sku,
          KITDETAIL.ExpectedQty / @n_ExpectedQty AS ComponentQty,
          BILLOFMATERIAL.ComponentSku,          --WZ01         
          BILLOFMATERIAL.Qty,                   --WZ01
          BILLOFMATERIAL.Notes                  --WZ01
   FROM KITDETAIL (NOLOCK) 
   JOIN KIT (NOLOCK) ON (KIT.KITKey = KITDETAIL.KITKey)
   JOIN BILLOFMATERIAL (NOLOCK) ON (KITDETAIL.Sku = BILLOFMATERIAL.Sku)     --WZ01
   WHERE ( KITDETAIL.KitKey = KIT.kitKey )
	AND	( KITDETAIL.[Type] = 'T' )
	AND   ( KIT.[Status]     < '9' )
	AND   ( KIT.Kitkey       = @c_KITKey )
   GROUP BY KITDETAIL.Sku,                            --WZ01
            KITDETAIL.ExpectedQty / @n_ExpectedQty,   --WZ01
            BILLOFMATERIAL.ComponentSku,              --WZ01         
            BILLOFMATERIAL.Qty,                       --WZ01
            BILLOFMATERIAL.Notes                      --WZ01

END

GO