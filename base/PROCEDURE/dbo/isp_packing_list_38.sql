SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store Procedure: isp_Packing_List_38                                       */    
/* Creation Date:14-JUNE-201                                                  */    
/* Copyright: IDS                                                             */    
/* Written by: CSCHONG                                                        */    
/*                                                                            */    
/* Purpose: WMS-2150-CN_DYSON_Report_B2C PackingList                          */    
/*        :                                                                   */    
/* Called By:  r_dw_packing_list_38                                           */    
/*                                                                            */    
/* PVCS Version: 1.0                                                          */    
/*                                                                            */    
/* Version: 1.0                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author    Ver.  Purposes                                      */  
/* 10-Nov-2017  Shong     1.1   Performance Tuning                            */  
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */  
/******************************************************************************/    
    
CREATE PROC [dbo].[isp_Packing_List_38] (  
         @c_PickSlipNo NVARCHAR(10))    
AS    
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
BEGIN    
   DECLARE @n_continue   INT   
       , @n_starttcnt  INT  
      , @b_success   INT    
       , @n_err    INT   
       , @c_errmsg   NVARCHAR(255)  
   
   SET @n_continue      = 1  
   SET @n_starttcnt     = @@TRANCOUNT  
   SET @b_success       = 1  
   SET @n_err           = 0  
   SET @c_Errmsg        = ''  
  
   CREATE Table #TempPackList38 (  
               OrderKey         NVARCHAR(10) NULL   
               , ExternOrderkey     NVARCHAR(50) NULL  --tlting_ext  
               , ORD_Contact1    NVARCHAR(30) NULL  
               , ORD_Address1      NVARCHAR(150) NULL  
               , C_Phone1           NVARCHAR(18) NULL  
               , SKU                NVARCHAR(20) NULL  
               , ST_PHONE1          NVARCHAR(18) NULL  
               , PickQty           INT   
               , OHUDE01            NVARCHAR(45) NULL   
               , ORD_Date           DATETIME NULL    
               , ORD_AddDate        DATETIME NULL  
               , SDESCR          NVARCHAR(60) NULL  
               , ST_Notes1       NVARCHAR(150) NULL  
    )   
  
   INSERT INTO #TempPackList38 (  
               OrderKey           
               , ExternOrderkey       
               , ORD_Contact1      
               , ORD_Address1        
               , C_Phone1             
               , SKU                  
               , ST_PHONE1           
               , PickQty              
               , OHUDE01              
               , ORD_Date          
               , ORD_AddDate                          
               , SDESCR            
               , ST_Notes1  )  
     SELECT OH.OrderKey,     
         OH.ExternOrderKey,     
         OH.C_contact1,     
         RTRIM(OH.C_State)+RTRIM(OH.C_City)+RTRIM(OH.C_Address1)   
         + RTRIM(OH.C_Address2)+RTRIM(OH.C_Address3)+RTRIM(OH.C_Address4),     
         OH.C_Phone1,     
         PAD.SKU,   
         ST.Phone1,     
         SUM(PAD.Qty) as PickQty ,  
         OH.UserDefine01,   
         OH.Orderdate,  
   OH.Adddate,  
   SKU.DESCR,   
         ST.notes1  
   FROM PackHeader PH (NOLOCK)     
    JOIN PackDetail PAD (NOLOCK) ON ( PAD.PickSlipNo = PH.PickSlipNo)       
    JOIN ORDERS OH (NOLOCK) ON PH.orderkey=OH.orderkey  
    JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = OH.StorerKey   
    JOIN SKU (NOLOCK) ON ( PAD.Sku = SKU.Sku AND PAD.StorerKey = SKU.StorerKey )                                      
   WHERE ( PH.PickSlipNo = @c_PickSlipNo)  
   AND PH.[Status]='9'  
   GROUP BY OH.OrderKey,     
         OH.ExternOrderKey,     
         OH.C_contact1,     
         OH.C_Address1,     
         OH.C_Phone1,     
         PAD.SKU,   
         RTRIM(OH.C_State)+RTRIM(OH.C_City)+RTRIM(OH.C_Address1)   
         + RTRIM(OH.C_Address2)+RTRIM(OH.C_Address3)+RTRIM(OH.C_Address4),     
         OH.C_Company,   
         ST.phone1,  
         OH.UserDefine01,  
   OH.Orderdate,  
   OH.Adddate,  
   SKU.DESCR,   
         ST.notes1  
     ORDER BY oh.ExternOrderkey,pad.Sku  
  
  
   SELECT *  
   FROM #TempPackList38              
      
            
  
   DROP TABLE #TempPackList38  
END  

GO