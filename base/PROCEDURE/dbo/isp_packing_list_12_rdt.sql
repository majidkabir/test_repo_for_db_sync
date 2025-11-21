SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/            
/* Store Procedure: isp_Packing_List_12_rdt                                   */            
/* Creation Date: 27-JAN-2014                                                 */            
/* Copyright: IDS                                                             */            
/* Written by: YTWan                                                          */            
/*                                                                            */            
/* Purpose: SOS#301324 - Develop Generic Packing slip for LFUSA -             */
/*          REDLANDS facility                                                 */            
/*                                                                            */            
/* Called By:  r_dw_packing_list_12_rdt                                       */            
/*                                                                            */            
/* PVCS Version: 1.0                                                          */            
/*                                                                            */            
/* Version: 5.4                                                               */            
/*                                                                            */            
/* Data Modifications:                                                        */            
/*                                                                            */            
/* Updates:                                                                   */            
/* Date         Author    Ver.  Purposes                                      */          
/******************************************************************************/   

CREATE PROC [dbo].[isp_Packing_List_12_rdt]           
       (@c_PickSlipNo NVARCHAR(10))            
AS          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_WARNINGS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_STCompany       NVARCHAR(65)
         , @c_Externorderkey  NVARCHAR(30)
         , @c_C_Company       NVARCHAR(45)
         , @c_C_Addresses     NVARCHAR(200)
--         , @c_C_Address2      NVARCHAR(45)
--         , @c_C_City          NVARCHAR(45)
--         , @c_C_State         NVARCHAR(45)
--         , @c_C_Zip           NVARCHAR(18)
         , @c_BuyerPO         NVARCHAR(20)
         , @c_FCDescr         NVARCHAR(50)
         , @c_FCAddresses     NVARCHAR(80)
         , @c_ConsoOrderkey   NVARCHAR(30)

         , @n_NoOfLabel       INT
         , @n_CartonNo        INT
         , @n_Qty             INT
         , @n_TotalWeight     FLOAT
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(10)
         , @c_Size            NVARCHAR(5)
         , @c_RetailSku       NVARCHAR(20)


 CREATE TABLE #TMP_PACKLIST
         ( STCompany       NVARCHAR(65)
         , Externorderkey  NVARCHAR(30)
         , C_Company       NVARCHAR(45)
         , C_Addresses     NVARCHAR(200)
--         , C_Address2      NVARCHAR(45)
--         , C_City          NVARCHAR(45)
--         , C_State         NVARCHAR(45)
--         , C_Zip           NVARCHAR(18)
         , BuyerPO         NVARCHAR(20)
         , FCDescr         NVARCHAR(50)
         , FCAddresses     NVARCHAR(80)
         , NoOfLabel       INT
         , CartonNo        INT
         , Storerkey       NVARCHAR(15)
         , Sku             NVARCHAR(20)
         , SkuDescr        NVARCHAR(60)
         , Style           NVARCHAR(20)
         , Color           NVARCHAR(10)
         , Size            NVARCHAR(5)
         , RetailSku       NVARCHAR(20)
         , Qty             INT
         , TotalWeight     FLOAT
         )


   SELECT TOP 1
          @c_STCompany      = ISNULL(RTRIM(ST.Company),'') + ' c/o LF Logistics' 
         ,@c_Externorderkey = ISNULL(RTRIM(OH.Externorderkey),'')
         ,@c_C_Company      = ISNULL(RTRIM(OH.C_Company),'')
         ,@c_C_Addresses    = ISNULL(RTRIM(OH.C_Address1),'') + ' '
                            + ISNULL(RTRIM(OH.C_Address2),'')   
                            + ISNULL(RTRIM(OH.C_City),'')     + ', ' 
                            + ISNULL(RTRIM(OH.C_State),'')    + ', ' 
                            + ISNULL(RTRIM(OH.C_Zip),'')  
         ,@c_BuyerPO        = ISNULL(RTRIM(OH.BuyerPO),'') 
         ,@c_FCDescr        = ISNULL(RTRIM(FC.Descr),'')
         ,@c_FCAddresses    = ISNULL(RTRIM(FC.UserDefine01),'') + ', ' 
                            + ISNULL(RTRIM(FC.UserDefine03),'') + ', ' 
                            + ISNULL(STUFF(SUBSTRING(ISNULL(FC.UserDefine04,''),1,9),6,0,'-'),'')
         ,@c_ConsoOrderkey  = ISNULL(RTRIM(PH.ConsoOrderkey),'') 
   FROM PACKHEADER  PH WITH (NOLOCK)          
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PH.ConsoOrderKey = OD.ConsoOrderkey)          
   JOIN ORDERS      OH WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)   
   JOIN FACILITY    FC WITH (NOLOCK) ON (OH.Facility = FC.Facility) 
   JOIN STORER      ST WITH (NOLOCK) ON (PH.Storerkey= ST.Storerkey)   
   WHERE PH.PickslipNo = @c_Pickslipno

   --SELECT @n_NoOfLabel = COUNT(DISTINCT CartonNo)
   --FROM PACKDETAIL WITH (NOLOCK)
   --WHERE PickslipNo = @c_Pickslipno

   SET @n_NoOfLabel   = 0
   SET @n_TotalWeight = 0.00

   SELECT @n_TotalWeight  = SUM(PI.Weight)
   FROM PACKINFO PI WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   SELECT @n_NoOfLabel = COUNT(DISTINCT PD.LabelNo)
         ,@n_TotalWeight  = CASE WHEN @n_TotalWeight > 0 THEN @n_TotalWeight ELSE SUM(PD.Qty * ISNULL(SKU.StdGrossWgt,0)) END
   FROM PACKDETAIL PD    WITH (NOLOCK)  
   JOIN SKU        SKU   WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey)  AND (PD.SKU = SKU.SKU) 
   WHERE PD.PickSlipNo = @c_PickSlipNo




   DECLARE CUR_PACK CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT PD.CartonNo
         ,PD.Storerkey
         ,PD.Sku
         ,ISNULL(RTRIM(SKU.Descr),'')
         ,ISNULL(RTRIM(SKU.Style),'')
         ,ISNULL(RTRIM(SKU.Color),'')
         ,ISNULL(RTRIM(SKU.Size),'')
         ,PD.Qty
   FROM PACKDETAIL PD  WITH (NOLOCK)
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) AND (PD.Sku = SKU.Sku)
   WHERE PD.PickslipNo = @c_Pickslipno

   OPEN CUR_PACK
   
   FETCH NEXT FROM CUR_PACK INTO @n_CartonNo
                              ,  @c_Storerkey 
                              ,  @c_Sku  
                              ,  @c_SkuDescr 
                              ,  @c_Style
                              ,  @c_Color  
                              ,  @c_Size       
                              ,  @n_Qty                                   
                             
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT TOP 1 @c_RetailSku = ISNULL(RTRIM(RetailSku),'')
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE ConsoOrderkey = @c_ConsoOrderkey
      AND   Storerkey     = @c_Storerkey
      AND   Sku           = @c_Sku

      INSERT INTO #TMP_PACKLIST
         (  STCompany        
         ,  Externorderkey  
         ,  C_Company        
         ,  C_Addresses      
--         ,  C_Address2       
--         ,  C_City           
--         ,  C_State         
--         ,  C_Zip            
         ,  BuyerPO          
         ,  FCDescr          
         ,  FCAddresses      
         ,  NoOfLabel        
         ,  CartonNo         
         ,  Storerkey        
         ,  Sku              
         ,  SkuDescr         
         ,  Style            
         ,  Color            
         ,  Size             
         ,  RetailSku       
         ,  Qty
         ,  TotalWeight
         )
      VALUES 
         (  @c_STCompany        
         ,  @c_Externorderkey  
         ,  @c_C_Company        
         ,  @c_C_Addresses       
--         ,  @c_C_Address2       
--         ,  @c_C_City           
--         ,  @c_C_State         
--         ,  @c_C_Zip            
         ,  @c_BuyerPO          
         ,  @c_FCDescr          
         ,  @c_FCAddresses      
         ,  @n_NoOfLabel        
         ,  @n_CartonNo         
         ,  @c_Storerkey        
         ,  @c_Sku              
         ,  @c_SkuDescr         
         ,  @c_Style            
         ,  @c_Color            
         ,  @c_Size             
         ,  @c_RetailSku       
         ,  @n_Qty
         ,  @n_TotalWeight
         )

      FETCH NEXT FROM CUR_PACK INTO @n_CartonNo
                                 ,  @c_Storerkey 
                                 ,  @c_Sku  
                                 ,  @c_SkuDescr 
                                 ,  @c_Style
                                 ,  @c_Color  
                                 ,  @c_Size       
                                 ,  @n_Qty  

   END
   CLOSE CUR_PACK
   DEALLOCATE CUR_PACK

   SELECT STCompany        
         ,Externorderkey  
         ,C_Company        
         ,C_Addresses      
--         ,C_Address2       
--         ,C_City           
--         ,C_State         
--         ,C_Zip            
         ,BuyerPO          
         ,FCDescr          
         ,FCAddresses      
         ,NoOfLabel        
         ,CartonNo         
         ,Storerkey        
         ,Sku              
         ,SkuDescr         
         ,Style            
         ,Color            
         ,Size             
         ,RetailSku       
         ,Qty 
         ,TotalWeight
   FROM #TMP_PACKLIST
   ORDER BY CartonNo
         ,  Sku
             
END

GO