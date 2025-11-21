SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_LP_LOADSHEET_008                              */      
/* Creation Date: 21-MARCH-2023                                            */    
/* Copyright: LF Logistics                                                 */    
/* Written by: WZPang                                                      */    
/*                                                                         */    
/* Purpose: WMS-21912 - [ID] Diversey û LoadSheet                          */     
/*                                                                         */      
/* Called By: RPT_LP_LOADSHEET_008                                         */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */  
/* 021-Mar-2023 WZPang  1.0  DevOps Combine Script                        */   
/***************************************************************************/          
CREATE   PROC [dbo].[isp_RPT_LP_LOADSHEET_008] (  
      @c_Loadkey  NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE  @c_Storerkey   NVARCHAR(15)                           
         ,  @c_Type        NVARCHAR(1) = '1'                      
         ,  @c_DataWindow  NVARCHAR(60) = 'RPT_LP_LOADSHEET_008'  
         ,  @c_RetVal      NVARCHAR(255)    

   SELECT @c_Storerkey = OH.Storerkey
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey

   EXEC [dbo].[isp_GetCompanyInfo]  
         @c_Storerkey  = @c_Storerkey  
      ,  @c_Type       = @c_Type  
      ,  @c_DataWindow = @c_DataWindow  
      ,  @c_RetVal     = @c_RetVal           OUTPUT 
 
   SELECT LPD.LoadKey,  
          OH.OrderKey,  
          OH.Facility,  
          OH.ExternOrderKey,  
          OH.Storerkey,   
          OH.DeliveryDate,  
          ISNULL(loadplan.CarrierKey,'') AS carrierkey,  
          ISNULL(loadplan.Truck_Type,'') Truck_Type,  
          ISNULL(CONVERT(NVARCHAR(35), OH.Notes),'') AS Notes,  
          OH.ConsigneeKey,  
          OH.C_Company,  
          OH.C_Address1,  
          OH.C_City,  
          SUM(PD.qty) AS PQty,  
          CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(SUM(PD.qty) / PAC.CaseCnt) ELSE 0 END AS PQtyInCS,  
          PD.SKU,  
          SKU.Descr,  
          PAC.Pallet,  
          PAC.CaseCnt,  
          LOADPLAN.UserDefine01,  
          ISNULL(PD.dropid,'') AS Dropid,  
          CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable02 ELSE '' END AS Lottable02,  
          CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable04 ELSE NULL END AS Lottable04,  
          CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN 'Y' ELSE 'N' END AS Showlot24,  
          PAC.Innerpack AS IP,  
          CASE WHEN ISNULL(CLR1.Code ,'') <> '' THEN 'Y' ELSE 'N' END AS showinnerpack,  
          ISNULL(CLR2.Short ,'') AS showskubarcode,
          ISNULL(@c_RetVal,'') AS Logo
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)   
   INNER JOIN ORDERS OH WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)   
   INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey AND LPD.LoadKey = OD.LoadKey)   
   INNER JOIN PICKDETAIL AS PD ON (PD.Orderkey = OD.OrderKey    
                               AND PD.sku = OD.sku AND PD.OrderLineNumber = OD.OrderLineNumber)  
   INNER JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)   
   INNER JOIN PACK PAC WITH (NOLOCK) ON (SKU.PackKey = PAC.PackKey)   
   JOIN LOADPLAN WITH (NOLOCK) ON LOADPLAN.loadkey = OD.loadkey      
   JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.Lot = PD.lot)   
   LEFT JOIN Codelkup CLR (NOLOCK) ON (OH.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWLOT24'   
                                   AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'RPT_LP_LOADSHEET_008' AND ISNULL(CLR.Short,'') <> 'N')  
   LEFT JOIN Codelkup CLR1 (NOLOCK) ON (OH.Storerkey = CLR1.Storerkey AND CLR1.Code = 'SHOWINNERPACK'   
                                   AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'RPT_LP_LOADSHEET_008' AND ISNULL(CLR1.Short,'') <> 'N')  
   LEFT JOIN Codelkup CLR2 (NOLOCK) ON (OH.Storerkey = CLR2.Storerkey AND CLR2.Code = 'ShowSKUBarcode'   
                                   AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'RPT_LP_LOADSHEET_008' AND ISNULL(CLR1.Short,'') <> 'N')  
   WHERE LPD.LoadKey = @c_LoadKey   
   GROUP BY LPD.LoadKey,  
            OH.OrderKey,  
            OH.Facility,  
            OH.ExternOrderKey,  
            OH.Storerkey,   
            OH.DeliveryDate,  
            ISNULL(loadplan.CarrierKey,'') ,  
            ISNULL(loadplan.Truck_Type,'') ,  
            ISNULL(CONVERT(NVARCHAR(35), OH.Notes),'') ,  
            OH.ConsigneeKey,  
            OH.C_Company,  
            OH.C_Address1,  
            OH.C_City,  
            PD.SKU,  
            SKU.Descr,  
            PAC.Pallet,  
            PAC.CaseCnt,  
            LOADPLAN.UserDefine01,  
            ISNULL(PD.dropid,'') ,  
            CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable02 ELSE '' END,  
            CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN LOTT.Lottable04 ELSE NULL END,  
            CASE WHEN ISNULL(CLR.Code ,'') <> '' THEN 'Y' ELSE 'N' END ,  
            PAC.Innerpack,  
            CASE WHEN ISNULL(CLR1.Code ,'') <> '' THEN 'Y' ELSE 'N' END,  
            ISNULL(CLR2.Short ,'')  
   ORDER BY LPD.LoadKey, OH.OrderKey,ISNULL(PD.dropid,''), PD.Sku   

END  

GO