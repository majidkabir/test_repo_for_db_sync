SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure: isp_Vics_BOL_Detail_Info_DMark                      */  
/* Creation Date: 08-Oct-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: IDS                                                      */  
/*                                                                      */  
/* Purpose:  VICS BOL (From Datamark)                                   */  
/*                                                                      */  
/* Input Parameters: @as_mbolkey - (MBOL#)                              */  
/*                   @as_consigneekey - (Consigneekey) (SOS#246112)     */  
/*                                                                      */  
/* Output Parameters: Report                                            */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: r_dw_vics_bol_detail_info_dmark                           */  
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
  
CREATE PROC [dbo].[isp_Vics_BOL_Detail_Info_DMark]   
(  
@as_mbolkey NVARCHAR(10),  
@as_consigneekey NVARCHAR(15)  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   IF EXISTS(SELECT 1 FROM DATAMART.ODS.ORDERS O (NOLOCK)   
             JOIN DATAMART.ODS.ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey  
             WHERE ISNULL(OD.Consoorderkey,'') <> ''  
             AND O.mbolkey = @as_mbolkey   
             AND O.Consigneekey = @as_consigneekey)  
   BEGIN  
     	SELECT DISTINCT ORDERDETAIL.ExternConsoOrderKey
     	INTO #CONSOORD
      FROM DATAMART.ODS.MBOLDETAIL MBOLDETAIL WITH (NOLOCK)       
      JOIN DATAMART.ODS.ORDERS ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
      JOIN DATAMART.ODS.ORDERDETAIL ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      WHERE MBOLDETAIL.MBOLKEY =  @as_mbolkey 
      AND ORDERS.ConsigneeKey = @as_consigneekey
      
      SELECT EXTERNCONSOORDERKEY, TTLCTN, TTLWeight  
      INTO #SUMM
      FROM [dbo].[fnc_GetVicsBOL_CartonInfo_DMark](@as_mbolkey , @as_consigneekey)
      
      SELECT ORD.ExternConsoOrderKey,
            '' AS userDefine03,
            SM.TTLCTN AS PKG,          
            SM.TTLWeight AS WEIGHT,        
            'Y / N  ' AS PALLETS 
      FROM #CONSOORD AS ORD
      JOIN #SUMM AS SM ON SM.ExternConsoOrderkey = ORD.ExternConsoOrderkey
   END  
   ELSE  
   BEGIN  
      SELECT ORDERS.ExternOrderKey,  
             ORDERS.userDefine03,  
             PKG = SUM(CONVERT(INT, MBOLDETAIL.TotalCartons)),            
             WEIGHT = SUM(MBOLDETAIL.Weight),          
             'Y / N  ' PALLETS   
       FROM DATAMART.ODS.MBOLDETAIL MBOLDETAIL WITH (NOLOCK)   
       JOIN DATAMART.ODS.ORDERS ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey )   
       WHERE ( MBOLDETAIL.MbolKey = @as_mbolkey   )   
       AND ( ORDERS.ConsigneeKey = @as_consigneekey)   
       GROUP BY ORDERS.ExternOrderKey,   
                ORDERS.userDefine03    
   END              
END /* main procedure */  

GO