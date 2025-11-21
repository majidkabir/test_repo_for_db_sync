SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_Vics_CBOL_Detail_Info                            */
/* Creation Date: 14-Jun-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose:  VICS BOL                                                   */
/*                                                                      */
/* Input Parameters: @ai_cbolkey - (MBOL#) (SOS#246112)                 */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_vics_cbol_detail_info                                */
/*            r_dw_vics_cbol_supp_detail                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 0                                                           */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */   
/************************************************************************/

CREATE PROC [dbo].[isp_Vics_CBOL_Detail_Info] 
(
@ai_cbolkey BIGINT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   IF EXISTS(SELECT 1 FROM ORDERS O (NOLOCK) 
             JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
             JOIN MBOL MB (NOLOCK) ON O.Mbolkey = MB.Mbolkey
             WHERE ISNULL(OD.Consoorderkey,'') <> ''
             AND MB.Cbolkey = @ai_cbolkey 
             AND ISNULL(MB.Cbolkey,0) <> 0)
   BEGIN
     	SELECT DISTINCT ORDERDETAIL.ExternConsoOrderKey, CBOL.CBOLReference
     	INTO #CONSOORD
      FROM MBOL WITH (NOLOCK)
      JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )       
      JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN CBOL WITH (NOLOCK) ON (MBOL.Cbolkey = CBOL.Cbolkey)
      WHERE MBOL.CBOLKEY = @ai_cbolkey 
      AND ISNULL(MBOL.Cbolkey,0) <> 0
      
      SELECT EXTERNCONSOORDERKEY, TTLCTN, TTLWeight  
      INTO #SUMM
      FROM [dbo].[fnc_GetVicsCBOL_CartonInfo](@ai_cbolkey)
      
      SELECT ORD.ExternConsoOrderKey,
            '' AS userDefine03,
            SM.TTLCTN AS PKG,          
            SM.TTLWeight AS WEIGHT,        
            'Y / N  ' AS PALLETS,
            ORD.CBOLReference 
      FROM #CONSOORD AS ORD
      JOIN #SUMM AS SM ON SM.ExternConsoOrderkey = ORD.ExternConsoOrderkey
   END
   ELSE
   BEGIN
      SELECT ORDERS.ExternOrderKey,
             ORDERS.userDefine03,
             PKG = SUM(CONVERT(INT, MBOLDETAIL.TotalCartons)),          
             WEIGHT = SUM(MBOLDETAIL.Weight),        
             'Y / N  ' PALLETS,
             CBOL.CBOLReference 
       FROM MBOL WITH (NOLOCK)
       JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.Mbolkey = MBOLDETAIL.Mbolkey )
       JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
       JOIN CBOL WITH (NOLOCK) ON (MBOL.Cbolkey = CBOL.Cbolkey)
       WHERE ( MBOL.cbolKey = @ai_cbolkey   ) 
       AND ( ISNULL(MBOL.Cbolkey,0) <> 0 )
       GROUP BY ORDERS.ExternOrderKey, 
                ORDERS.userDefine03,
                CBOL.CBOLReference   
   END            
END /* main procedure */

GO