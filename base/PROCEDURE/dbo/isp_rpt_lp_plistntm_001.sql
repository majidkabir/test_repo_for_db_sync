SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/              
/* Stored Procedure: isp_RPT_LP_PLISTNTM_001                            */              
/* Creation Date: 5-SEP-2022                                            */          
/* Copyright: LF Logistics                                              */          
/* Written by: WZPang                                                   */          
/*                                                                      */          
/* Purpose: WMS-20702 - TH - NUSKIN - Create New Logi Report (TH)       */            
/*                                                                      */              
/* Called By: RPT_LP_PLISTNTM_001                                       */              
/*                                                                      */              
/* PVCS Version: 1.3                                                    */              
/*                                                                      */              
/* Version: 7.0                                                         */              
/*                                                                      */              
/* Data Modifications:                                                  */              
/*                                                                      */              
/* Updates:                                                             */              
/* Date         Author   Ver  Purposes                                  */      
/* 5-SEP-2022   WZPang   1.0  DevOps Combine Script                     */  
/* 28-SEP-2022  WZPang   1.1  Insert new Codelkup                       */  
/* 29-SEP-2022  WZPang   1.2  Insert new Codelkup                       */  
/* 07-Oct-2022  WLChooi  1.3  Fix - JOIN PICKHEADER as packing not start*/
/*                            yet (WL01)                                */
/* 19-OCT-2022  WZPang   1.4  Update Field Mapping						*/
/************************************************************************/              
CREATE   PROC [dbo].[isp_RPT_LP_PLISTNTM_001] (      
      @c_loadkey NVARCHAR(10)          
)              
 AS              
 BEGIN              
                  
   SET NOCOUNT ON              
   SET ANSI_NULLS ON              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF              
   SET ANSI_WARNINGS ON        
                
      
   DECLARE @n_MaxLine INT = 10,      
     @n_totalpage INT  = 0    
      
   CREATE TABLE #TEMP_PD      
            (  OrderKey         NVARCHAR(10),      
               ExternOrderkey   NVARCHAR(30),      
               Type             NVARCHAR(10),      
               Notes            NVARCHAR(500),      
               Notes2           NVARCHAR(500),
			   BuyerPO			NVARCHAR(20),
               Consigneekey     NVARCHAR(20),      
               C_company        NVARCHAR(100),      
               C_Address1       NVARCHAR(100),      
               C_Address2       NVARCHAR(100),      
               C_Address3       NVARCHAR(100),      
               C_Address4       NVARCHAR(100),      
               C_State          NVARCHAR(50),      
               C_Zip            NVARCHAR(20),      
               C_phone1         NVARCHAR(30),      
               DeliveryDate     DATETIME,      
               Sku              NVARCHAR(20),      
               Qty              INT,      
               PickHeaderKey    NVARCHAR(20),      
               PickSlipNo       NVARCHAR(20),      
               Loadkey          NVARCHAR(20),      
               Descr            NVARCHAR(100),      
               ND1              NVARCHAR(250),      
               ND2              NVARCHAR(500),      
               ND3              NVARCHAR(500),      
               ND4              NVARCHAR(500),      
               ND5              NVARCHAR(2000),      
               ND6              NVARCHAR(500),      
               ND7              NVARCHAR(500),  
               ND8              NVARCHAR(500),  
               ND9              NVARCHAR(500),  
               ND10             NVARCHAR(500),  
               ND11             NVARCHAR(500),  
               ND12				NVARCHAR(500),  
               ND13             NVARCHAR(500),  
               ND14             NVARCHAR(500),  
               ND15             NVARCHAR(500),  
               ND16             NVARCHAR(500),  
               ND17             NVARCHAR(500),  
               ND18             NVARCHAR(500),  
               PageNo INT                            
               )      
      
 INSERT INTO #TEMP_PD      
         (      
               OrderKey,              
               ExternOrderkey,         
               Type,                   
               Notes,                  
               Notes2,
			   BuyerPO,		--WZ03
               Consigneekey,           
               C_company,              
               C_Address1,             
               C_Address2,             
               C_Address3,             
               C_Address4,             
               C_State,                
               C_Zip,                 
               C_phone1,               
               DeliveryDate,           
               Sku,            
               Qty,            
               PickHeaderKey,      
               PickSlipNo,             
               Loadkey,           
               Descr,                  
               ND1,            
               ND2,            
               ND3,            
               ND4,            
               ND5,           
               ND6,            
               ND7,  
               ND8,  --(WZ01)  
               ND9,  --(WZ01)  
               ND10, --(WZ01)  
               ND11, --(WZ01)  
               ND12, --(WZ01)  
               ND13, --(WZ01)  
               ND14, --(WZ01)  
               ND15, --(WZ02)  
               ND16, --(WZ02)  
               ND17, --(WZ02)  
               ND18, --(WZ02)  
               PageNo              
               )      
      
   SELECT ORDERS.OrderKey,      
          ORDERS.ExternOrderkey,      
          ORDERS.Type,      
          ORDERS.Notes,      
          ORDERS.Notes2,
		  ORDERS.BuyerPO,	--WZ03
          ORDERS.Consigneekey,      
          ORDERS.C_company,      
          ORDERS.C_Address1,      
          ORDERS.C_Address2,      
          ORDERS.C_Address3,      
          ORDERS.C_Address4,      
          ORDERS.C_State,      
          ORDERS.C_Zip,      
          ORDERS.C_phone1,      
          ORDERS.DeliveryDate,      
          PICKDETAIL.Sku,      
          SUM(PICKDETAIL.Qty) AS Qty,      
          PICKHEADER.PickHeaderKey AS PickHeaderKey,  --WL01      
          PICKHEADER.PickHeaderKey AS Pickslipno,     --WL01      
          LoadPlanDetail.Loadkey,      
          Sku.Descr,      
          ISNULL(C1.LONG,'') AS ND1,      
          ISNULL(C2.LONG,'') AS ND2,      
          ISNULL(C3.LONG,'') AS ND3,      
          ISNULL(C4.LONG,'') AS ND4,      
          ISNULL(C5.NOTES,'')AS ND5,      
          ISNULL(C6.LONG,'') AS ND6,      
          ISNULL(C7.LONG,'') AS ND7,  
          ISNULL(C8.LONG,'') AS ND8,     
          ISNULL(C9.LONG,'') AS ND9,     
          ISNULL(C10.LONG,'') AS ND10,   
          ISNULL(C11.LONG,'') AS ND11,   
          ISNULL(C12.LONG,'') AS ND12,   
          ISNULL(C13.LONG,'') AS ND13,   
          ISNULL(C14.LONG,'') AS ND14,   
          ISNULL(C15.LONG,'') AS ND15,   
          ISNULL(C16.LONG,'') AS ND16,   
          ISNULL(C17.LONG,'') AS ND17,   
          ISNULL(C18.LONG,'') AS ND18,   
    --      (Row_Number() OVER (PARTITION BY ORDERS.ExternOrderkey ORDER BY ORDERS.ExternOrderkey ASC) - 1 ) / @n_MaxLine + 1 AS PageNo,      
    --@n_totalpage                                                                                                                            
         (Row_Number() OVER (PARTITION BY ORDERS.ExternOrderkey ORDER BY ORDERS.ExternOrderkey ASC) - 1 ) / @n_MaxLine + 1 AS PageNo                
   FROM LOADPLANDETAIL (NOLOCK)      
   JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = LOADPLANDETAIL.OrderKey      
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = ORDERDETAIL.Orderkey      
   --JOIN PACKHEADER (NOLOCK) ON ORDERS.Orderkey = PACKHEADER.Orderkey  -- WL01      
   JOIN PICKHEADER (NOLOCK) ON ORDERS.Orderkey = PICKHEADER.Orderkey  -- WL01 
   JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber AND ORDERDETAIL.Sku = PICKDETAIL.Sku      
   JOIN SKU (NOLOCK) ON ORDERDETAIL.Sku = SKU.Sku AND SKU.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C1(NOLOCK) ON C1.Listname = 'NUSKINDN' AND c1.code = 'ND1' AND C1.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C2(NOLOCK) ON C2.Listname = 'NUSKINDN' AND c2.code = 'ND2' AND C2.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C3(NOLOCK) ON C3.Listname = 'NUSKINDN' AND c3.code = 'ND3' AND C3.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C4(NOLOCK) ON C4.Listname = 'NUSKINDN' AND c4.code = 'ND4' AND C4.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C5(NOLOCK) ON C5.Listname = 'NUSKINDN' AND c5.code = 'ND5' AND C5.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C6(NOLOCK) ON C6.Listname = 'NUSKINDN' AND c6.code = 'ND6' AND C6.Storerkey = ORDERS.Storerkey      
   LEFT JOIN Codelkup C7(NOLOCK) ON C7.Listname = 'NUSKINDN' AND c7.code = 'ND7' AND C7.Storerkey = ORDERS.Storerkey  
   LEFT JOIN Codelkup C8(NOLOCK) ON C8.Listname = 'NUSKINDN' AND c8.code = 'ND8' AND C8.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C9(NOLOCK) ON C9.Listname = 'NUSKINDN' AND c9.code = 'ND9' AND C9.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C10(NOLOCK) ON C10.Listname = 'NUSKINDN' AND c10.code = 'ND10' AND C10.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C11(NOLOCK) ON C11.Listname = 'NUSKINDN' AND c11.code = 'ND11' AND C11.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C12(NOLOCK) ON C12.Listname = 'NUSKINDN' AND c12.code = 'ND12' AND C12.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C13(NOLOCK) ON C13.Listname = 'NUSKINDN' AND c13.code = 'ND13' AND C13.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C14(NOLOCK) ON C14.Listname = 'NUSKINDN' AND c14.code = 'ND14' AND C14.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C15(NOLOCK) ON C15.Listname = 'NUSKINDN' AND c15.code = 'ND15' AND C15.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C16(NOLOCK) ON C16.Listname = 'NUSKINDN' AND c16.code = 'ND16' AND C16.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C17(NOLOCK) ON C17.Listname = 'NUSKINDN' AND c17.code = 'ND17' AND C17.Storerkey = ORDERS.Storerkey    
   LEFT JOIN Codelkup C18(NOLOCK) ON C18.Listname = 'NUSKINDN' AND c18.code = 'ND18' AND C18.Storerkey = ORDERS.Storerkey    
   WHERE LOADPLANDETAIL.Loadkey = @c_loadkey      
   GROUP BY ORDERS.Orderkey,      
            ORDERS.ExternOrderkey,      
            ORDERS.Type,      
            ORDERS.Notes,      
            ORDERS.Notes2,
			ORDERS.BuyerPO,		--WZ03
            ORDERS.Consigneekey,      
            ORDERS.C_company,      
            ORDERS.C_Address1,      
            ORDERS.C_Address2,      
            ORDERS.C_Address3,      
            ORDERS.C_Address4,      
            ORDERS.C_State,      
            ORDERS.C_Zip,      
            ORDERS.C_phone1,      
            ORDERS.DeliveryDate,      
            PICKDETAIL.Sku,    
            PICKHEADER.PickHeaderKey,   --WL01      
            LoadPlanDetail.Loadkey,      
            SKU.Descr,      
            C1.LONG,      
            C2.LONG,      
            C3.LONG,      
            C4.LONG,      
            C5.NOTES,      
            C6.LONG,      
            C7.LONG,  
            C8.LONG,      
            C9.LONG,      
            C10.LONG,     
            C11.LONG,     
            C12.LONG,     
            C13.LONG,           
            C14.LONG,     
            C15.LONG,     
            C16.LONG,     
            C17.LONG,     
            C18.LONG      
              
        
     
  SELECT *, (SELECT MAX(TP.PageNo) FROM #TEMP_PD TP WHERE TP.OrderKey = PD.OrderKey) AS TotalPage FROM #TEMP_PD PD     
    
   DROP TABLE #TEMP_PD                  
      
      
END -- procedure   

GO