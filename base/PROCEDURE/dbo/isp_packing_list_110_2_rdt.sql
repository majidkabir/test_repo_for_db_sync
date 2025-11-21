SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure: isp_packing_list_110_2_rdt                          */  
/* Creation Date: 16-AUG-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose: WMS-17584-[TW] SPZ_PackList_CR                              */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_packing_list_110_2_rdt             */  
/*                                                                      */  
/* Called By: RCM from MBOL, ReportType = 'PACKLIST'                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 16-AUG-2021  Mingle  1.0   Created                                   */  
/************************************************************************/  
CREATE PROC [dbo].[isp_packing_list_110_2_rdt]  
   @c_PickSlipNo NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue  INT = 1
         , @n_TTLCTN    INT = 0
         , @c_long          NVARCHAR(30) 
         , @c_udf01          NVARCHAR(30) 
         , @c_udf02          NVARCHAR(30)
  
   CREATE TABLE #Temp_DOrderByPS(  
         DCompany        NVARCHAR(45)   
      ,  DAddress1       NVARCHAR(45)  
      ,  DAddress2       NVARCHAR(45)  
      ,  DAddress3       NVARCHAR(45)   
      ,  DZip            NVARCHAR(45)  
      ,  DState          NVARCHAR(45)  
      ,  DCountry        NVARCHAR(45)  
      --,  mbolkey         NVARCHAR(20)
      ,  DNotes       NVARCHAR(500)    
      ,  OHROUTE         NVARCHAR(10)   
      ,  DeliveryDate    DATETIME   
      ,  Orderkey        NVARCHAR(20) 
      ,  ExtOrdKey       NVARCHAR(50) 
      ,  Consigneekey    NVARCHAR(45) 
      ,  SDESCR          NVARCHAR(250) 
      ,  Qty             INT  
      ,  orderlinenumber NVARCHAR(20)
      ,  SKU             NVARCHAR(20) 
      ,  FAddress1       NVARCHAR(45) 
      ,  FAddress2       NVARCHAR(45) 
      ,  FAddress3       NVARCHAR(45)  
      ,  FZip            NVARCHAR(45) 
      ,  FCountry        NVARCHAR(45) 
      ,  FState          NVARCHAR(45)
      ,  FPhone1         NVARCHAR(18)
      ,  FCompany        NVARCHAR(45)    
      ,  UOM             NVARCHAR(10)       
      ,  PQTY            INT  
      ,  TTLCTN          INT  
      ,  PickSlipNo      NVARCHAR(10)
      ,  PickHeaderkey   NVARCHAR(10)
      ,  DPhone1         NVARCHAR(20) 
      ,  long          NVARCHAR(30) 
      ,  udf01          NVARCHAR(30) 
      ,  udf02          NVARCHAR(30) 
      )  
  
   IF(@n_Continue = 1 OR @n_Continue = 2)  
   BEGIN
      SELECT @n_TTLCTN = COUNT(DISTINCT pd.cartonNo) 
      FROM PackDetail PD with (nolock) 
      WHERE pd.PickSlipNo = @c_PickSlipNo

      SELECT @c_long  = ISNULL(CL1.Long,''),
          @c_udf01  = ISNULL(CL1.UDF01,''),
          @c_udf02  = ISNULL(CL1.UDF02,'')
   FROM CODELKUP CL1(NOLOCK)
   WHERE CL1.LISTNAME = 'REPORTCFG'
   AND CL1.Storerkey = 'spz'
   AND CL1.code = 'RPTTitle'
        
      INSERT INTO #Temp_DOrderByPS 
         (  DCompany
         ,  DAddress1
         ,  DAddress2
         ,  DAddress3
         ,  DZip
         ,  DState         
         ,  DCountry 
         --,  mbolkey
         ,  DNotes
         ,  OHROUTE
         ,  DeliveryDate
         ,  Orderkey
         ,  ExtOrdKey
         ,  Consigneekey 
         ,  SDESCR
         ,  Qty
         ,  orderlinenumber 
         ,  SKU
         ,  FAddress1
         ,  FAddress2
         ,  FAddress3
         ,  FState
         ,  FZip
         ,  FCountry
         ,  FPhone1
         ,  FCompany     
         ,  UOM
         ,  PQTY 
         ,  TTLCTN
         ,  PickSlipNo
         ,  PickHeaderkey
         ,  DPhone1
         ,  long
         ,  udf01
         ,  udf02
         )
      SELECT DISTINCT 
            DCompany  = ISNULL(OH.c_company,'')
         ,  DAddress1 = ISNULL(OH.c_Address1,'')
         ,  DAddress2 = ISNULL(OH.c_Address2,'')
         ,  DAddress3 = ISNULL(Oh.c_Address3,'')  
         ,  DZip      = ISNULL(OH.c_zip,'')
         ,  DState    = ISNULL(OH.c_State,'')         
         ,  DCountry  = ISNULL(OH.c_Country,'')  
         --,  MB.Mbolkey
         ,  DNotes = OH.Notes
         ,  OHROUTE   = ISNULL(OH.Route,'')
         ,  OH.Deliverydate
         ,  OH.Orderkey
         ,  OH.ExternOrderkey
         ,  Consigneekey = ISNULL(OH.Consigneekey,'')  
         ,  S.descr
         ,  Qty = OD.QtyPicked + OD.ShippedQty 
         ,  orderlinenumber = ''
         ,  OD.SKU
         ,  FAddress1 = ISNULL(F.Address1,'')
         ,  FAddress2 = ISNULL(F.Address2,'')
         ,  FAddress3 = ISNULL(F.Address3,'')  
         ,  FState    = ISNULL(F.state,'')
         ,  FZip      = ISNULL(F.zip,'')
         ,  FCountry  = ISNULL(F.Country,'')
         ,  FPhone1   = ISNULL(F.Phone1,'')
         ,  FCompany  = N'ΘªÖµ╕»σòåσÅ░τüúσê⌐Φ▒Éτë⌐µ╡üµ£ëΘÖÉσà¼σÅ╕σÅ░τüúσêåσà¼σÅ╕'
         ,  P.PackUOM3
         ,  PQTY      = sum(PD.Qty)
         ,  TTLCTN    = @n_TTLCTN
         ,  PH.PickSlipNo
         ,  PK.Pickheaderkey
         ,  DPhone1  = ISNULL(OH.c_Phone1,'') 
         ,  long = @c_long 
         ,  udf01 = @c_udf01
         ,  udf02 = @c_udf02
      FROM ORDERS OH (NOLOCK) 
      JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY 
      --JOIN MBOLDETAIL MD (NOLOCK) ON MD.ORDERKEY = OH.ORDERKEY  
      --JOIN MBOL MB (NOLOCK) ON MD.MBOLKEY = MB.MBOLKEY  
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey  
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey=OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber 
      JOIN SKU S WITH (NOLOCK) ON S.Storerkey = OD.Storerkey AND S.SKU = OD.SKU  
      JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey  
      --LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = OH.StorerKey  
      JOIN Facility AS F WITH (NOLOCK) ON F.facility = OH.Facility
      JOIN Pickheader AS PK WITH (NOLOCK) ON PK.Orderkey = PH.OrderKey
      WHERE PH.PickSlipNo = @c_PickSlipNo 
      GROUP BY 
            ISNULL(OH.c_company,'')
         ,  ISNULL(OH.c_Address1,'')
         ,  ISNULL(OH.c_Address2,'')
         ,  ISNULL(Oh.c_Address3,'')  
         ,  ISNULL(OH.c_zip,'')
         ,  ISNULL(OH.c_State,'')
         ,  ISNULL(OH.c_Country,'')  
         --,  MB.Mbolkey
         ,  OH.Notes
         ,  ISNULL(OH.Route,'')
         ,  OH.Deliverydate
         ,  OH.Orderkey
         ,  OH.ExternOrderkey
         ,  ISNULL(OH.Consigneekey,'')  
         ,  S.descr
         ,  OD.QtyPicked 
         ,  OD.ShippedQty
         --,  od.orderlinenumber
         ,  OD.SKU
         ,  ISNULL(F.Address1,'')
         ,  ISNULL(F.Address2,'')
         ,  ISNULL(F.Address3,'')  
         ,  ISNULL(F.zip,'')
         ,  ISNULL(F.Country,'')
         ,  ISNULL(F.state,'')
         ,  ISNULL(F.Phone1,'')
         ,  P.PackUOM3
         ,  PH.PickSlipNo
         ,  PK.Pickheaderkey
         ,  ISNULL(OH.c_Phone1,'')
      ORDER BY OH.Orderkey
            ,  OD.SKU  
 
   END  
  
   SELECT 
         DCompany           
      ,  DAddress1        
      ,  DAddress2        
      ,  DAddress3         
      ,  DZip             
      ,  DNotes           
      ,  OHROUTE            
      ,  DeliveryDate    
      ,  Orderkey         
      ,  DState             
      ,  Consigneekey     
      ,  SDESCR            
      ,  Qty             
      ,  SKU              
      ,  FAddress1        
      ,  FAddress2        
      ,  FAddress3         
      ,  FZip             
      ,  PQTY            
      ,  FState           
      ,  FCompany            
      ,  ExtOrdKey        
      ,  TTLCTN          
      ,  UOM                   
      --,  mbolkey          
      ,  FCountry         
      ,  DCountry         
      ,  orderlinenumber
      ,  FPhone1
      ,  PickSlipNo 
      ,  PickHeaderkey
      ,  DPhone1
      ,  long
      ,  udf01
      ,  udf02
   FROM #Temp_DOrderByPS  
   ORDER BY Orderkey
           ,sku  
  
  
   IF OBJECT_ID('tempdb..#Temp_DOrderByPS') IS NOT NULL  
      DROP TABLE #Temp_DOrderByPS  
  
  
END

GO