SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store Procedure: isp_DeliveryOrder13                                 */    
/* Creation Date: 03-JUNE-2021                                          */    
/* Copyright: IDS                                                       */    
/* Written by:CSCHONG                                                   */    
/*                                                                      */    
/* Purpose:  WMS-17134-CR-DeliveryNote-Adidas                           */    
/*                                                                      */    
/* Usage:  Used for report dw = r_dw_delivery_Order_13                  */    
/*         duplicate from r_dw_delivery_Order_08                        */    
/*                                                                      */    
/* Called By: Exceed                                                    */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver.  Purposes                                  */    
/* 08-OCT-2021  CSCHONG 1.0   Devops Scripts combine                    */  
/* 22-MAR-2022  MINGLE  1.1   Modify sorting logic(ML01)                */
/* 29-MAR-2022  MINGLE  1.2   Added codelkup(ML02)                      */
/* 11-APR-2023  Calvin  1.3   JSM-141944 change Size/Qty per row from   */
/*                            5 to 4 to fit longer sizes (CLVN01)       */
/************************************************************************/    
    
CREATE   PROC [dbo].[isp_DeliveryOrder13]    
      (@c_MBOLKey     NVARCHAR(10)    
      ,@c_Type        NVARCHAR(10) = 'HR')    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_Cnt                INT    
         , @c_Loadkey            NVARCHAR(10)    
         , @c_ExternOrderkey     NVARCHAR(30)    
         , @c_Consigneekey       NVARCHAR(15)    
         , @c_C_Company          NVARCHAR(45)    
         , @c_C_Address1         NVARCHAR(45)    
         , @c_C_Address2         NVARCHAR(45)    
         , @c_C_Address3         NVARCHAR(45)    
         , @c_C_Address4         NVARCHAR(45)    
         , @c_C_City             NVARCHAR(45)    
         , @c_C_Zip              NVARCHAR(18)    
         , @c_C_State            NVARCHAR(45)        
         , @c_C_Country          NVARCHAR(30)        
         , @c_SSTYLE             NVARCHAR(20)    
         , @dt_EditDate          DATETIME    
         , @dt_DepartureDate     DATETIME    
         , @c_Userdefine02       NVARCHAR(20)    
         , @dt_DeliveryDate      DATETIME    
    --   , @c_BuyerPO            NVARCHAR(20)    
         , @c_BuyerPO            NVARCHAR(45)      
         , @c_ExternPOKey        NVARCHAR(20)    
         , @dt_UserDefine10      DATETIME            
         , @c_Billtokey          NVARCHAR(20)    
         , @c_B_Company          NVARCHAR(45)    
         , @c_B_Address1         NVARCHAR(45)    
         , @c_B_Address2         NVARCHAR(45)    
         , @c_B_Address3         NVARCHAR(45)    
         , @c_B_Address4         NVARCHAR(45)    
         , @c_B_City             NVARCHAR(45)    
         , @c_B_Zip              NVARCHAR(18)    
         , @c_B_State            NVARCHAR(45)        
         , @c_B_Country          NVARCHAR(30)        
         , @c_ST_Company         NVARCHAR(45)    
         , @c_ST_Address1        NVARCHAR(45)    
         , @c_ST_Address2        NVARCHAR(45)    
         , @c_ST_Address3        NVARCHAR(45)    
         , @c_ST_Address4        NVARCHAR(45)    
         , @c_ST_Phone1          NVARCHAR(45)    
         , @c_ST_Fax1            NVARCHAR(18)    
         , @c_ST_VAT    NVARCHAR(18)    
    
         , @C_RPTCode             NVARCHAR(20)    
         , @c_RPTCopyname         NVARCHAR(150)    
         , @c_OHNotes             NVARCHAR(250)    
         , @c_SizeCnt             INT    
         , @C_PreRPTCode          NVARCHAR(20)    
    
   DECLARE @dt_OHRDD             DATETIME    
         , @c_SkuDesc            NVARCHAR(60)    
         , @c_UOM                NVARCHAR(10)    
         , @n_TTLCTN             INT    
         , @n_Qty                INT    
         , @n_UnitPrice          FLOAT    
    
   DECLARE @c_PrevConsigneekey   NVARCHAR(15)    
         , @c_PrevNotes          NVARCHAR(4000)    
         , @c_VATLblText         NVARCHAR(10)         
         , @c_GMbolkey           NVARCHAR(10)        
         , @c_GUserdefine02      NVARCHAR(20)    
         , @c_GSTYLE             NVARCHAR(20)    
         , @c_GSizeQty           NVARCHAR(50)    
         , @c_CGSizeQty          NVARCHAR(250)    
         , @n_RecCnt             INT    
         , @c_Gsorting           NVARCHAR(150)    
         , @n_lineNum            INT    
         , @c_GPreSTYLE          NVARCHAR(20)    
         , @n_TTLLine            INT    
         , @n_MaxSizeLine        INT    
         , @n_recgrp             INT    
         , @n_pageno             INT    
         , @c_PreExtOrdKey       NVARCHAR(30)    
         , @c_line               NVARCHAR(1)    
         , @n_maxlinenumber      INT    
         , @n_MaxLine            INT                  
         , @c_GUserdefine03      NVARCHAR(20)         
         , @c_GUserdefine04      NVARCHAR(20)        
    
         ,@c_ShowVATLbIText    NVARCHAR(5)    
         ,@c_ShowBranch        NVARCHAR(5)    
         ,@c_ShowDNBarcode     NVARCHAR(5)    
         ,@c_ShowTruckNo       NVARCHAR(5)      
         ,@c_ShowShippingAgent NVARCHAR(5)    
         ,@c_Storerkey         NVARCHAR(20)    
         ,@c_BranchText        NVARCHAR(30)    
         ,@c_TruckText         NVARCHAR(30)    
         ,@c_shippingAgentText NVARCHAR(30)    
         ,@c_SSusr5            NVARCHAR(18)    
         ,@c_OHUDF04           NVARCHAR(40)    
         ,@c_MBVessel          NVARCHAR(30)    
         ,@c_STSusr1           NVARCHAR(20)    
         ,@c_ShowDTPrice       NVARCHAR(5)    
         ,@c_ShowAmt           NVARCHAR(5) 
		 ,@c_GColor            NVARCHAR(20)	--ML01
		 ,@c_ShowField         NVARCHAR(5)	--ML02
    
    
    
   SET @c_ExternOrderkey   = ''    
   SET @c_C_Company        = ''    
   SET @c_C_Address1       = ''    
   SET @c_C_Address2       = ''    
   SET @c_C_Address3       = ''    
   SET @c_C_Address4       = ''    
   SET @c_C_City           = ''    
   SET @c_C_Zip            = ''    
   SET @c_C_State          = ''       
   SET @c_C_Country        = ''       
   SET @c_Consigneekey     = ''      
   SET @n_recgrp           = 1       
   SET @n_MaxLine          = 1      
    
   SET @dt_EditDate        = ''    
   SET @dt_DepartureDate   = ''    
    
   SET @c_SkuDesc          = ''    
   SET @c_UOM              = ''    
   SET @n_TTLCTN           = 0    
   SET @n_Qty              = 0    
    
   SET @c_PrevConsigneekey = ''    
   SET @c_PrevNotes        = ''    
   SET @n_RecCnt           = 1         
   SET @n_MaxSizeLine      = 4    --(CLVN01)    
   SET @C_PreRPTCode       = ''       
   SET @c_PreExtOrdKey     = ''       
   SET @c_line             = 'N'     
    
       
   SET @c_ShowVATLbIText = 'N'    
   SET @c_ShowBranch     = 'N'    
   SET @c_ShowDNBarcode  ='N'    
   SET @c_ShowTruckNo    = 'N'    
   SET @c_ShowShippingAgent ='N'     
   SET @c_Storerkey      = ''    
   SET @c_VATLblText = ''    
   SET @c_BranchText = ''    
   SET @c_TruckText = ''    
   SET @c_shippingAgentText = ''  
   SET @c_ShowField  ='N'	--ML02
    
 IF ISNULL(@c_Type,'') = '' SET @c_Type = 'HR'     
    
   CREATE TABLE #TMP_DELNote13    
   (  MBOLKey           NVARCHAR(10)    
 --,  LoadKey           NVARCHAR(10)    
   ,  DepartureDate     DATETIME    
   ,  UserDefine02      NVARCHAR(20)    
   ,  ExternOrderkey    NVARCHAR(30)    
   ,  Billtokey         NVARCHAR(15)    
   ,  C_Company         NVARCHAR(45)    
   ,  C_Address1        NVARCHAR(45)    
   ,  C_Address2        NVARCHAR(45)    
   ,  C_Address3        NVARCHAR(45)    
   ,  C_Address4        NVARCHAR(45)    
   ,  C_City            NVARCHAR(45)    
   ,  C_Zip             NVARCHAR(18)    
   ,  C_State           NVARCHAR(45)        
   ,  C_Country         NVARCHAR(30)        
-- ,  BuyerPO           NVARCHAR(20)    
   ,  BuyerPO           NVARCHAR(45)      
   ,  UserDefine10      DATETIME NULL       
   ,  OHRDD             DATETIME NULL    
   ,  SkuDesc           NVARCHAR(60)    
   ,  UOM               NVARCHAR(10)    
   ,  TTLCTN            INT    
   ,  Qty               INT    
   ,  DeliveryDate      DATETIME    
   ,  SSTYLE          NVARCHAR(10)    
   ,  UnitPrice         FLOAT    
   ,  ST_Company        NVARCHAR(45)    
   ,  ST_Address1       NVARCHAR(45)    
   ,  ST_Address2       NVARCHAR(45)    
   ,  ST_Address3       NVARCHAR(45)    
   ,  ST_Address4       NVARCHAR(45)    
   ,  ST_Phone1         NVARCHAR(18)    
   ,  ST_Fax1           NVARCHAR(18)    
   ,  ST_VAT            NVARCHAR(18)    
   ,  B_Company         NVARCHAR(45)    
   ,  B_Address1        NVARCHAR(45)    
   ,  B_Address2        NVARCHAR(45)    
   ,  B_Address3        NVARCHAR(45)    
   ,  B_Address4        NVARCHAR(45)    
   ,  B_City            NVARCHAR(45)    
   ,  B_Zip             NVARCHAR(18)    
   ,  B_State           NVARCHAR(45)       
   ,  B_Country         NVARCHAR(30)       
   ,  copycode          NVARCHAR(10)    
   ,  copyname          NVARCHAR(150)    
   ,  OHNotes           NVARCHAR(250)    
   ,  SizeCnt           INT    
   ,  ConsigneeKey      NVARCHAR(15)      
   ,  VATLblText        NVARCHAR(10)      
   ,  SizeQty           NVARCHAR(250) NULL     
   ,  LineNum           INT                
   ,  RecGrp            INT    
   ,  Pageno            INT    
   ,  DrawLine          NVARCHAR(1)    
   ,  SSusr5            NVARCHAR(18)    
   ,  OHUDF04           NVARCHAR(40)    
   ,  MBVessel          NVARCHAR(30)    
   ,  STSUSR1           NVARCHAR(20)    
   ,  BranchText        NVARCHAR(30)     
   ,  TruckText         NVARCHAR(30)       
   ,  shippingAgentText NVARCHAR(30)    
   ,  ShowDNBarcode     NVARCHAR(5)    
   ,  ShowDTPrice       NVARCHAR(5)    
   ,  ShowAmt           NVARCHAR(5)
   ,  ShowField         NVARCHAR(5)	--ML02
 )    
    
    
 CREATE TABLE #TMP_DELNote13Size (    
     RowNo             INT IDENTITY(1,1)    
  ,  MBOLKey           NVARCHAR(10)  NULL    
  ,  UserDefine02      NVARCHAR(20)  NULL    
  ,  SSTYLE            NVARCHAR(10)  NULL    
  ,  SizeQty           NVARCHAR(250) NULL    
  ,  RecLineNo         INT    
    
 )    
    
   SELECT TOP 1 @c_Storerkey = ORDERS.storerkey    
   FROM MBOL        WITH (NOLOCK)    
   JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
   JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)    
   WHERE MBOL.MBOLKey = @c_MBOLKey    
    
       
SELECT  @c_ShowVATLbIText        = ISNULL(MAX(CASE WHEN C.Code = 'ShowVATLbIText'   THEN 'Y' ELSE 'N' END),'N')    
      , @c_ShowBranch            = ISNULL(MAX(CASE WHEN C.Code = 'ShowBranch'       THEN 'Y' ELSE 'N' END),'N')    
      , @c_ShowDNBarcode         = ISNULL(MAX(CASE WHEN C.Code = 'ShowDNBarcode'    THEN 'Y' ELSE 'N' END),'N')    
      , @c_ShowTruckNo           = ISNULL(MAX(CASE WHEN C.Code = 'ShowTruckNo'      THEN 'Y' ELSE 'N' END),'N')    
      , @c_ShowShippingAgent     = ISNULL(MAX(CASE WHEN C.Code = 'ShowShippingAgent'   THEN 'Y' ELSE 'N' END),'N')      
      , @c_ShowDTPrice           = ISNULL(MAX(CASE WHEN C.Code = 'ShowRetailPrice'      THEN 'Y' ELSE 'N' END),'N')    
      , @c_ShowAmt               = ISNULL(MAX(CASE WHEN C.Code = 'ShowAmount'   THEN 'Y' ELSE 'N' END),'N')   
	  , @c_ShowField             = ISNULL(MAX(CASE WHEN C.Code = 'ShowField'   THEN 'Y' ELSE 'N' END),'N')	--ML02 
      FROM CODELKUP C WITH (NOLOCK)    
      WHERE C.ListName = 'REPORTCFG'    
      AND   C.Storerkey= @c_Storerkey    
      AND   C.Long = 'r_dw_delivery_Order_13'    
      AND   ISNULL(C.Short,'') <> 'N'    
    
  IF @c_ShowVATLbIText = 'Y'    
  BEGIN    
    SET @c_VATLblText ='Tax ID.'    
  END    
    
  IF @c_ShowBranch = 'Y'    
  BEGIN    
    SET @c_BranchText = 'Branch'    
  END    
    
  IF @c_ShowTruckNo = 'Y'    
  BEGIN    
    SET @c_TruckText ='Truck No'    
  END    
    
  IF @c_ShowShippingAgent = 'Y'    
  BEGIN    
    SET @c_shippingAgentText = 'Shipping Agent'    
  END    
    
   DECLARE C_ORDLINE CURSOR FAST_FORWARD READ_ONLY FOR    
      SELECT ExternOrderkey= ISNULL(RTRIM(ORDERS.ExternOrderkey),'')    
          ,UserDefine02  = ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')    
         ,C_Company     = ISNULL(RTRIM(ORDERS.C_Company),'')    
         ,C_Address1    = ISNULL(RTRIM(ORDERS.C_Address1),'')    
         ,C_Address2    = ISNULL(RTRIM(ORDERS.C_Address2),'')    
         ,C_Address3    = ISNULL(RTRIM(ORDERS.C_Address3),'')    
         ,C_Address4    = ISNULL(RTRIM(ORDERS.C_Address4),'')    
         ,C_City        = ISNULL(RTRIM(ORDERS.C_City),'')    
         ,C_Zip         = ISNULL(RTRIM(ORDERS.C_Zip),'')    
         ,C_State       = ISNULL(RTRIM(ORDERS.C_State),'')        
         ,C_Country     = ISNULL(C_Country.Long,'')               
      -- ,BuyerPO       = ISNULL(ORDERS.BuyerPO,'')    
         ,BuyerPO       = ISNULL(ORDERS.M_Company,'')           
         ,EditDate      = MAX(ORDERS.EditDate)    
         ,DepartureDate = MBOL.DepartureDate    
         ,UserDefine10  = CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN convert(datetime,convert(nvarchar(10),ORDERS.UserDefine10,112))    
                  ELSE NULL END      
         ,MBOLKey       = MBOL.MBOLKey    
         ,Billtokey     = ISNULL(RTRIM(ORDERS.Billtokey),'')    
         ,SkuDesc       = ISNULL(RTRIM(ORDERDETAIL.Descr),'')    
         ,UOM           = MIN(ISNULL(RTRIM(ORDERDETAIL.UOM),''))    
         --ttlctns       = PACKHEADER.TTLCNTS    
		 ,ttlctns       = (SELECT  COUNT(DISTINCT  LABELNO)  FROM  PackDetail  PD  WHERE  PD.PickSlipNo  = PackHeader.PickSlipNo)
         ,Qty           = ISNULL(SUM(ORDERDETAIL.Qty),0)    
         ,DeliveryDate  = convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112))    
         ,OHRDD         = convert(datetime,convert(nvarchar(10),ISNULL(ORDERS.RDD,''),112))    
         ,B_Company     = ISNULL(RTRIM(ORDERS.B_Company),'')    
         ,B_Address1    = ISNULL(RTRIM(ORDERS.B_Address1),'')    
         ,B_Address2    = ISNULL(RTRIM(ORDERS.B_Address2),'')    
         ,B_Address3    = ISNULL(RTRIM(ORDERS.B_Address3),'')    
         ,B_Address4    = ISNULL(RTRIM(ORDERS.B_Address4),'')    
         ,B_City        = ISNULL(RTRIM(ORDERS.B_City),'')    
         ,B_Zip         = ISNULL(RTRIM(ORDERS.B_Zip),'')    
         ,B_State       = ISNULL(RTRIM(ORDERS.B_State),'')          
         ,B_Country     = ISNULL(B_Country.Long,'')                 
         ,ST_Company    = ISNULL(RTRIM(STORER.Company),'')    
         ,ST_Address1   = ISNULL(RTRIM(STORER.Address1),'')    
         ,ST_Address2   = ISNULL(RTRIM(STORER.Address2),'')    
         ,ST_Address3   = ISNULL(RTRIM(STORER.Address3),'')    
         ,ST_Address4   = ISNULL(RTRIM(STORER.Address4),'')    
         ,ST_Phone1     = ISNULL(RTRIM(STORER.Phone1),'')    
         ,ST_FAX1       = ISNULL(RTRIM(STORER.Fax1),'')    
         ,ST_VAT        = CASE WHEN @c_ShowVATLbIText = 'Y' THEN ISNULL(RTRIM(STORER.VAT),'') ELSE '' END    
         ,SSTYLE        = ORDERDETAIL.Style    
         ,UnitPrice     = MIN(ISNULL(RTRIM(ORDERDETAIL.UnitPrice),''))    
         ,RPTCode       = ISNULL(CODELKUP.code,'')    
         ,RPTCopyname   = ISNULL(CODELKUP.Description,'')    
         ,OHNotes       = ISNULL(ORDERS.Notes,'')    
         ,ConsigneeKey  = ISNULL(REPLACE(RTRIM(ORDERS.Consigneekey), 'AD', ''), '' )     
         ,SSUSR5 = CASE WHEN @c_ShowBranch = 'Y' THEN STORER.SUSR5 ELSE '' END    
         ,OHUDF04    = ORDERS.Userdefine04    
         ,MBVessel   = MBOL.vessel    
         ,STSUSR1    = ISNULL(ST.Susr1,'')    
         --,VATLblText    =                 
        
   FROM MBOL        WITH (NOLOCK)    
   JOIN MBOLDETAIL  WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
   JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)    
-- JOIN ORDERDETAIL (NOLOCK) ON  ORDERDETAIL.Orderkey = ORDERS.orderkey    
   JOIN (    
      --SELECT DISTINCT OrderKey, StorerKey, UOM, sku,unitprice,UserDefine02    
          SELECT OD.OrderKey,    
          CASE WHEN ISNULL(ADUOM.Short,'') = '' THEN OD.UOM ELSE ADUOM.Short END AS UOM,     
          OD.unitprice, OD.UserDefine02, sum(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, --,UserDefine03,UserDefine04    
          MIN(OD.Userdefine03) AS Userdefine03, MIN(OD.Userdefine04) AS Userdefine04, SKU.Style, MAX(SUBSTRING(SKU.Descr, LEN(SKU.Size) + 2, LEN(SKU.Descr))) AS Descr,Sku.susr5 AS SUSR5    
          FROM ORDERDETAIL OD WITH (NOLOCK)    
          JOIN SKU WITH (NOLOCK) ON OD.Storerkey =  SKU.Storerkey AND OD.Sku = SKU.sku    
          LEFT JOIN CODELKUP ADUOM WITH (NOLOCK) ON ADUOM.LISTNAME = 'ADUOM' AND ADUOM.code = OD.UOM AND ADUOM.Storerkey = OD.Storerkey     
         WHERE OD.MBOLKey = @c_MBOLKey    
          GROUP BY OD.OrderKey, OD.unitprice, OD.UserDefine02, CASE WHEN ISNULL(ADUOM.Short,'') = '' THEN OD.UOM ELSE ADUOM.Short END, SKU.Style,Sku.susr5    
     ) AS ORDERDETAIL    
   ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey )    
   JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)    
   --JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)    
   --                               AND(ORDERDETAIL.Storerkey = PACKDETAIL.Storerkey)    
   --                               AND(ORDERDETAIL.Sku       = PACKDETAIL.Sku)    
   --JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey  = SKU.Storerkey)    
   --                               AND(ORDERDETAIL.Sku        = SKU.Sku)    
   JOIN STORER      WITH (NOLOCK) ON STORER.STORERKEY = ORDERS.STORERKEY    
   LEFT JOIN CODELKUP    WITH (NOLOCK) ON CODELKUP.LISTNAME = 'REPORTCOPY' AND CODELKUP.long = 'r_dw_delivery_Order_13'    
                                AND CODELKUP.Storerkey = ORDERS.Storerkey    
    
   LEFT JOIN CODELKUP C_Country WITH (NOLOCK) ON C_Country.LISTNAME = 'ISOCountry' AND C_Country.code = ORDERS.C_Country    
             AND C_Country.Storerkey = ORDERS.Storerkey    
   LEFT JOIN CODELKUP B_Country WITH (NOLOCK) ON B_Country.LISTNAME = 'ISOCountry' AND B_Country.code = ORDERS.B_Country    
                                AND B_Country.Storerkey = ORDERS.Storerkey    
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.storerkey = ORDERS.consigneekey AND ST.Type='2'    
   --LEFT JOIN CODELKUP VATLblText WITH (NOLOCK) ON VATLblText.LISTNAME = 'REPORTCFG' AND VATLblText.code = 'VATLblText'    
   --     AND VATLblText.Storerkey = ORDERS.Storerkey    
 --LEFT JOIN CODELKUP ADUOM WITH (NOLOCK) ON ADUOM.LISTNAME = 'ADUOM' AND ADUOM.code = ORDERDETAIL.UOM AND ADUOM.Storerkey = ORDERDETAIL.Storerkey    
   WHERE MBOL.MBOLKey = @c_MBOLKey    
   GROUP BY ISNULL(RTRIM(ORDERS.ExternOrderkey),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Address2),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')    
         ,  ISNULL(RTRIM(ORDERS.C_City),'')    
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')    
         ,  ISNULL(RTRIM(ORDERS.C_State),'')          
         ,  ISNULL(C_Country.Long,'')                 
    --   ,  ISNULL(ORDERS.BuyerPO,'')    
         ,  ISNULL(ORDERS.M_Company,'')              
         ,  MBOL.DepartureDate    
         ,  CASE WHEN ISDATE(ORDERS.UserDefine10) = 1 THEN convert(datetime,convert(nvarchar(10),ORDERS.UserDefine10,112))    
                    ELSE NULL END       
         ,  MBOL.MBOLKey    
         ,  ISNULL(RTRIM(ORDERS.Billtokey),'')    
         ,  convert(datetime,convert(nvarchar(10),ORDERS.Deliverydate,112))    
         --,  PACKHEADER.TTLCNTS    
		 ,  PACKHEADER.Pickslipno
         ,  convert(datetime,convert(nvarchar(10),ISNULL(ORDERS.RDD,''),112))    
         ,  ISNULL(RTRIM(ORDERS.B_Company),'')    
         ,  ISNULL(RTRIM(ORDERS.B_Address1),'')    
         ,  ISNULL(RTRIM(ORDERS.B_Address2),'')    
         ,  ISNULL(RTRIM(ORDERS.B_Address3),'')    
         ,  ISNULL(RTRIM(ORDERS.B_Address4),'')    
         ,  ISNULL(RTRIM(ORDERS.B_City),'')    
         ,  ISNULL(RTRIM(ORDERS.B_Zip),'')    
         ,  ISNULL(RTRIM(ORDERS.B_State),'')          
         ,  ISNULL(B_Country.Long,'')                 
         ,  ISNULL(RTRIM(STORER.Company),'')    
         ,  ISNULL(RTRIM(STORER.Address1),'')    
         ,  ISNULL(RTRIM(STORER.Address2),'')    
         ,  ISNULL(RTRIM(STORER.Address3),'')    
         ,  ISNULL(RTRIM(STORER.Address4),'')    
         ,  ISNULL(RTRIM(STORER.Phone1),'')    
         ,  ISNULL(RTRIM(STORER.Fax1),'')    
         ,  CASE WHEN @c_ShowVATLbIText = 'Y' THEN ISNULL(RTRIM(STORER.VAT),'') ELSE '' END    
         ,  ORDERDETAIL.Style    
         ,  ISNULL(CODELKUP.code,'')    
         ,  ISNULL(CODELKUP.Description,'')    
         ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')    
         ,  ISNULL(ORDERS.Notes,'')    
     --  ,  ISNULL(RTRIM(ORDERS.Consigneekey), '' )     
         ,  ISNULL(REPLACE(RTRIM(ORDERS.Consigneekey), 'AD', ''), '' )     
        -- ,  ISNULL(VATLblText.Short, '')                 
         ,  ISNULL(RTRIM(ORDERDETAIL.Descr),''),CASE WHEN @c_ShowBranch = 'Y' THEN STORER.SUSR5 ELSE '' END    
         ,  ORDERS.Userdefine04,MBOL.vessel,ISNULL(ST.Susr1,'')    
 --  ORDER BY  MBOL.MBOLKey,ISNULL(RTRIM(ORDERS.ExternOrderkey),''),ISNULL(CODELKUP.code,''),    
 --ISNULL(RTRIM(ORDERDETAIL.UserDefine02),''),    
 --MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'')), MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine04),''))   
  ORDER BY ISNULL(CODELKUP.code,''),MBOL.MBOLKey,ISNULL(RTRIM(ORDERS.ExternOrderkey),''),  
     ISNULL(RTRIM(ORDERDETAIL.UserDefine02),''),  
     MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'')), MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine04),'')),ORDERDETAIL.Style   --ML01  
    
   OPEN C_ORDLINE    
   FETCH NEXT FROM C_ORDLINE INTO @c_ExternOrderkey    
                              , @c_Userdefine02    
                              , @c_C_Company    
                              , @c_C_Address1    
                              , @c_C_Address2    
                              , @c_C_Address3    
                              , @c_C_Address4    
                              , @c_C_City    
                              , @c_C_Zip    
                              , @c_C_State         
                              , @c_C_Country       
                              , @c_BuyerPO    
                              , @dt_EditDate    
                              , @dt_DepartureDate    
                              , @dt_UserDefine10        
                              , @c_MBOLKey    
                              , @c_Billtokey    
                              , @c_SkuDesc    
                              , @c_UOM    
                              , @n_TTLCTN    
                              , @n_Qty    
                              , @dt_deliverydate    
                              , @dt_OHRDD    
                              , @c_B_Company    
                              , @c_B_Address1    
                              , @c_B_Address2    
                              , @c_B_Address3    
                              , @c_B_Address4    
                              , @c_B_City    
                              , @c_B_Zip    
                              , @c_B_State         
                              , @c_B_Country       
                              , @c_ST_Company    
                              , @c_ST_Address1    
                              , @c_ST_Address2    
                              , @c_ST_Address3    
                              , @c_ST_Address4    
                              , @c_ST_Phone1    
                              , @c_ST_Fax1    
                              , @c_ST_VAT    
                              , @c_SSTYLE    
                              , @n_UnitPrice    
                              , @C_RPTCode    
                              , @c_RPTCopyname    
                              , @c_OHNotes    
                              , @c_ConsigneeKey    
                -- , @c_VATLblText      
                              , @c_SSusr5,@c_OHUDF04,@c_MBVessel,@c_STSusr1    
    
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
      IF CONVERT(NVARCHAR(8), @dt_DepartureDate, 112) = '19000101'    
      BEGIN    
         SET @dt_DepartureDate = @dt_EditDate    
      END    
    
      IF CONVERT(NVARCHAR(8), @dt_UserDefine10, 112) = '19000101'        
      BEGIN    
         SET @dt_UserDefine10 = NULL        
      END    
    
      IF CONVERT(NVARCHAR(8), @dt_OHRDD, 112) = '19000101'    
      BEGIN    
         SET @dt_OHRDD = NULL    
      END    
    
  SET @c_SizeCnt = 0    
  SET @c_line = 'N'       
  SET @n_MaxLine = 1     
    
  SELECT    
     @c_SizeCnt = COUNT(distinct ISNULL(RTRIM(SKU.SIZE),'')),    
     @n_Qty = SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0))     
  FROM MBOLDETAIL  WITH (NOLOCK)    
  JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)    
  JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)    
  JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)    
  JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)    
                                    AND (ORDERDETAIL.Sku = SKU.Sku)    
  WHERE MBOLDETAIL.MBOLKey  = @c_MBOLKey    
  AND   ORDERDETAIL.UserDefine02  = @c_UserDefine02    
  AND   SKU.Style = @c_SSTYLE    
  AND ORDERS.ExternOrderkey = @c_ExternOrderkey                  
  AND   ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0) <> 0    
  GROUP BY MBOLDETAIL.MBOLKey,ORDERDETAIL.UserDefine02 ,SKU.Style    
  HAVING SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) >0    
    
   SET @n_TTLLine =  (@c_SizeCnt/@n_MaxSizeLine)       
   IF (@c_SizeCnt%@n_MaxSizeLine) <> 0    
   BEGIN    
     SET @n_TTLLine = @n_TTLLine + 1    
   END    
    
   SET @n_MaxLine = @n_TTLLine    
   SET @n_RecCnt = 1    
    
    
   IF @C_PreRPTCode<> ''    
   BEGIN    
    
      IF @C_PreRPTCode <> @C_RPTCode    
      BEGIN    
    
       SET @n_recgrp = 0    
    
      END    
    
     SET @C_PreRPTCode = @C_RPTCode    
  END    
  ELSE    
  BEGIN    
    SET @n_recgrp = 0    
    SET @C_PreRPTCode = @C_RPTCode    
  END    
    
   SET @n_recgrp = @n_recgrp + 1             
    
      INSERT INTO #TMP_DELNote13 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,    
           C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,        
           OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,    
           ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,    
           B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,    
           ConsigneeKey, VATLblText,SizeQty,Linenum,RecGrp,Pageno,DrawLine, SSusr5,  OHUDF04,  MBVessel,  STSUSR1 ,  BranchText ,  TruckText ,      
           shippingAgentText  ,  ShowDNBarcode , ShowDTPrice,ShowAmt,ShowField)	--ML02    
      VALUES (@c_MBOLKey,@dt_DepartureDate, @c_UserDefine02, @c_ExternOrderkey, @c_Billtokey, @c_C_Company    
            , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10        
            , @dt_OHRDD, @c_SkuDesc, @c_UOM, @n_TTLCTN, @n_Qty, @dt_DeliveryDate, @c_SSTYLE, @n_UnitPrice,  @c_ST_Company, @c_ST_Address1    
            , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2    
            , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt    
            , @c_Consigneekey, @c_VATLblText,'',0,@n_recgrp,1,@c_line ,@c_SSusr5 ,@c_OHUDF04,@c_MBVessel,@c_STSusr1,@c_BranchText,@c_TruckText    
            , @c_shippingAgentText,@c_ShowDNBarcode, @c_showDTPrice,@c_ShowAmt,@c_ShowField	--ML02    
   )    
    
 SET @c_CGSizeQty = ''    
 SET @n_LineNum = 1    
    
 DECLARE C_SizeQty CURSOR FAST_FORWARD READ_ONLY FOR    
  SELECT MBOLKey,    
         UserDefine02 ,    
         Style ,    
         SkuSizeQty = Size + '/' + CAST(PackQty AS NVARCHAR(10)), Sorting,
		 Color	--ML01
  FROM (    
         SELECT    
         ISNULL(RTRIM(SKU.SIZE),'') AS Size,MBOLDETAIL.MBOLKey , ORDERDETAIL.UserDefine02,SKU.Style,    
            SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) AS PackQty,    
            MIN(ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'') + ISNULL(RTRIM(ORDERDETAIL.UserDefine04),'')) AS Sorting,SKU.Color	--ML01    
         FROM MBOLDETAIL  WITH (NOLOCK)    
         JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)    
         JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)    
         JOIN PACKHEADER  WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)    
         JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)    
                                           AND (ORDERDETAIL.Sku = SKU.Sku)    
         WHERE MBOLDETAIL.MBOLKey  =  @c_MBOLKey    
         AND   ORDERDETAIL.UserDefine02  = @c_UserDefine02    
         AND   SKU.Style = @c_SSTYLE    
         AND ORDERS.ExternOrderkey = @c_ExternOrderkey                    
      GROUP BY Size,MBOLDETAIL.MBOLKey , ORDERDETAIL.UserDefine02,SKU.Style,SKU.Color	--ML01   
         HAVING  SUM(ISNULL(ORDERDETAIL.ShippedQty,0) + ISNULL(ORDERDETAIL.QtyAllocated,0) + ISNULL(ORDERDETAIL.QtyPicked,0)) > 0    
  ) A ORDER BY mbolkey,userdefine02,Sorting,style,color	--ML01 
    
   OPEN C_SizeQty    
   FETCH NEXT FROM C_SizeQty INTO @c_Gmbolkey,@c_Guserdefine02,@c_GStyle,@c_GSizeqty,@c_Gsorting,@c_GColor	--ML01   
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN    
    
  --SELECT @c_GPreSTYLE '@c_GPreSTYLE',@c_GStyle '@c_GStyle',@n_RecCnt '@n_RecCnt',@c_CGSizeQty '@c_CGSizeQty',@c_GSizeqty '@c_GSizeqty'    
    
  SET @c_CGSizeQty = @c_CGSizeQty + space(2) +@c_GSizeqty    
  --select @n_RecCnt '@n_RecCnt',@c_SSTYLE '@c_SSTYLE',@C_RPTCode '@C_RPTCode'    
    
  IF @n_RecCnt%4 <> 0    --(CLVN01)
  BEGIN    
    
   IF  @n_RecCnt =  @c_SizeCnt    
   BEGIN    
     IF @n_LineNum = 1 AND @n_TTLLine = 1    
     BEGIN    
          UPDATE #TMP_DELNote13    
          SET SizeQty = LTRIM(@c_CGSizeQty)    
             ,Linenum = @n_LineNum    
             ,DrawLine = 'Y'    
          FROM #TMP_DELNote13    
          Where MBOLKey= @c_MBOLKey    
          AND   UserDefine02 = @c_UserDefine02    
          AND  SSTYLE = @c_SSTYLE    
          AND copycode = @C_RPTCode    
          AND ExternOrderkey = @c_ExternOrderkey                   
              
          SET @c_CGSizeQty  = ''    
    
   END    
   ELSE    
   BEGIN    
    
   IF @n_LineNum=@n_MaxLine    
   BEGIN    
     SET @c_line = 'Y'    
   END    
    
         IF @n_TTLLine <> 0    
         BEGIN    
             
           INSERT INTO #TMP_DELNote13 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,    
                 C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,        
                 OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,    
                 ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,    
                 B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,    
                 ConsigneeKey, VATLblText,SizeQty,Linenum,recgrp,Pageno,DrawLine , SSusr5,  OHUDF04,  MBVessel,  STSUSR1 ,  BranchText ,  TruckText ,      
                 shippingAgentText  ,  ShowDNBarcode , ShowDTPrice,ShowAmt,ShowField	--ML02   
           )    
            VALUES (@c_MBOLKey,@dt_DepartureDate, '', @c_ExternOrderkey, @c_Billtokey, @c_C_Company    
                  , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10        
                  , @dt_OHRDD, '', '', @n_TTLCTN, 0, @dt_DeliveryDate, '', 0,  @c_ST_Company, @c_ST_Address1    
                  , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2    
                  , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt    
                  , @c_Consigneekey, @c_VATLblText,LTRIM(@c_CGSizeQty),@n_LineNum,@n_recgrp,1,@c_line ,@c_SSusr5 ,@c_OHUDF04,@c_MBVessel,@c_STSusr1,@c_BranchText,@c_TruckText    
                  , @c_shippingAgentText,@c_ShowDNBarcode , @c_showDTPrice,@c_ShowAmt,@c_ShowField	--ML02    
           )    
             
             
               SET @c_CGSizeQty  = ''    
               SET @n_LineNum = @n_LineNum + 1    
               SET @n_TTLLine = @n_TTLLine - 1    
             
          END    
    END    
   END    
  END    
  ELSE    
  BEGIN    
 --  select '123'    
    
 --  select @n_RecCnt '@n_RecCnt',@c_SSTYLE '@c_SSTYLE',@C_RPTCode '@C_RPTCode',@n_LineNum '@n_LineNum',@n_TTLLine '@n_TTLLine'    
    
   IF @n_LineNum = 1 AND @n_TTLLine = 1    
   BEGIN    
    
   -- select @c_SSTYLE '@c_SSTYLE',@c_CGSizeQty '@c_CGSizeQty',@C_RPTCode '@C_RPTCode'    
    
     UPDATE #TMP_DELNote13    
     SET SizeQty = LTRIM(@c_CGSizeQty)    
        ,Linenum = @n_LineNum    
        ,DrawLine = 'Y'    
    FROM #TMP_DELNote13    
    Where MBOLKey= @c_MBOLKey    
    AND   UserDefine02 = @c_UserDefine02    
    AND  SSTYLE = @c_SSTYLE    
    AND copycode = @C_RPTCode    
    AND ExternOrderkey = @c_ExternOrderkey                --CS02    
    
     SET @c_CGSizeQty  = ''    
    
   END    
   ELSE    
   BEGIN    
    
        IF @n_LineNum=@n_MaxLine    
        BEGIN    
          SET @c_line = 'Y'    
        END    
    
         IF @n_TTLLine >= 1    
         BEGIN    
             
           INSERT INTO #TMP_DELNote13 (MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,    
           C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country, BuyerPO ,  UserDefine10,        
           OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,    
           ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,    
           B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode, copyname,OHNotes,SizeCnt,    
           ConsigneeKey, VATLblText,SizeQty,Linenum,recgrp,Pageno,DrawLine, SSusr5,  OHUDF04,  MBVessel,  STSUSR1 ,  BranchText ,  TruckText ,      
           shippingAgentText  ,  ShowDNBarcode   , ShowDTPrice,ShowAmt,ShowField	--ML02    
           )    
           VALUES (@c_MBOLKey,@dt_DepartureDate, @c_UserDefine02, @c_ExternOrderkey, @c_Billtokey, @c_C_Company    
          , @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_City, @c_C_Zip, @c_C_State, @c_C_Country, @c_BuyerPO, @dt_UserDefine10        
          , @dt_OHRDD, @c_SkuDesc, @c_UOM, @n_TTLCTN, case when @n_LineNum=1 then @n_Qty else 0 end, @dt_DeliveryDate, @c_SSTYLE,    
            case when @n_LineNum=1 then @n_UnitPrice else 0 end,  @c_ST_Company, @c_ST_Address1    
          , @c_ST_Address2, @c_ST_Address3, @c_ST_Address4, @c_ST_Phone1, @c_ST_Fax1, @c_ST_VAT, @c_B_Company, @c_B_Address1, @c_B_Address2    
          , @c_B_Address3, @c_B_Address4 , @c_B_City, @c_B_Zip , @c_B_State, @c_B_Country, @C_RPTCode, @c_RPTCopyname,@c_OHNotes,@c_SizeCnt    
          , @c_Consigneekey, @c_VATLblText,LTRIM(@c_CGSizeQty),@n_LineNum,@n_recgrp,1,@c_line ,@c_SSusr5 ,@c_OHUDF04,@c_MBVessel,@c_STSusr1,@c_BranchText,@c_TruckText    
          , @c_shippingAgentText,@c_ShowDNBarcode  , @c_showDTPrice,@c_ShowAmt,@c_ShowField	--ML02   
          )    
    
    
         SET @c_CGSizeQty  = ''    
         SET @n_LineNum = @n_LineNum + 1    
         SET @n_TTLLine = @n_TTLLine - 1    
             
         END    
      END    
 END    
    
   --select * from #TMP_DELNote13    
   SET @n_RecCnt = @n_RecCnt +  1    
    
    
 FETCH NEXT FROM C_SizeQty INTO @c_Gmbolkey,@c_Guserdefine02,@c_GStyle,@c_GSizeqty,@c_Gsorting,@c_GColor	--ML01    
 END    
   CLOSE C_SizeQty    
   DEALLOCATE C_SizeQty    
    
    
   --SET @c_PreExtOrdKey = @c_ExternOrderkey    
      FETCH NEXT FROM C_ORDLINE INTO @c_ExternOrderkey    
                              , @c_Userdefine02    
                              , @c_C_Company    
                              , @c_C_Address1    
                              , @c_C_Address2    
                              , @c_C_Address3    
                              , @c_C_Address4    
                              , @c_C_City    
                              , @c_C_Zip    
                              , @c_C_State         
                              , @c_C_Country       
                              , @c_BuyerPO    
                              , @dt_EditDate    
                              , @dt_DepartureDate    
                              , @dt_UserDefine10       
                              , @c_MBOLKey    
                              , @c_Billtokey    
                              , @c_SkuDesc    
                              , @c_UOM    
                              , @n_TTLCTN    
                              , @n_Qty    
                              , @dt_deliverydate    
                              , @dt_OHRDD    
                              , @c_B_Company    
                              , @c_B_Address1    
                              , @c_B_Address2    
                              , @c_B_Address3    
                              , @c_B_Address4    
                              , @c_B_City    
                          , @c_B_Zip    
                              , @c_B_State         
                              , @c_B_Country       
                              , @c_ST_Company    
                              , @c_ST_Address1    
                              , @c_ST_Address2    
                              , @c_ST_Address3    
                              , @c_ST_Address4    
                              , @c_ST_Phone1    
                              , @c_ST_Fax1    
                              , @c_ST_VAT    
                              , @c_SSTYLE    
                              , @n_UnitPrice    
                              , @C_RPTCode    
                              , @c_RPTCopyname    
                              , @c_OHNotes    
                              , @c_ConsigneeKey      
                             -- , @c_VATLblText        
                              , @c_SSusr5,@c_OHUDF04,@c_MBVessel,@c_STSusr1    
    
   END    
   CLOSE C_ORDLINE    
   DEALLOCATE C_ORDLINE    
      
  IF @c_Type = 'HR'     
  BEGIN    
   SELECT DISTINCT mbolkey AS mbolkey    
         ,CASE WHEN ShowDTPrice = 'Y' AND ShowAmt = 'Y' THEN 'FR'     
               WHEN ShowDTPrice = 'Y' AND ShowAmt = 'N' THEN 'RR'    
               WHEN ShowDTPrice = 'N' AND ShowAmt = 'Y' THEN 'AR'    
               ELSE 'OR' END AS RptType    
   FROM #TMP_DELNote13    
   WHERE MBOLKey = @c_MBOLKey    
  END    
  ELSE    
  BEGIN    
   SELECT  DISTINCT    
      MBOLKey,  DepartureDate,  UserDefine02,  ExternOrderkey,  Billtokey,  C_Company,  C_Address1,    
      C_Address2,  C_Address3  ,  C_Address4 ,  C_City  ,  C_Zip, C_State, C_Country,  BuyerPO , UserDefine10,    
      OHRDD ,  SkuDesc ,  UOM,  TTLCTN ,  Qty ,  DeliveryDate,  SSTYLE,  UnitPrice,  ST_Company,    
      ST_Address1,  ST_Address2,  ST_Address3,  ST_Address4 ,  ST_Phone1,  ST_Fax1 ,  ST_VAT  ,    
      B_Company,  B_Address1, B_Address2,  B_Address3,  B_Address4,  B_City ,  B_Zip, B_State, B_Country, copycode,  copyname,OHNotes,SizeCnt,    
      ConsigneeKey, VATLblText,SizeQty,LineNum,recgrp,Pageno,DrawLine , SSusr5,  OHUDF04,  MBVessel,  STSUSR1 ,  BranchText ,  TruckText ,      
      shippingAgentText  ,  ShowDNBarcode , ShowField	--ML02   
   FROM #TMP_DELNote13    
   WHERE linenum<> 0    
   AND MBOLKey = @c_MBOLKey    
   ORDER BY MBOLKey,copycode,copyname,ExternOrderkey,recgrp ,LineNum,SSTYLE,sizeqty  --ML01     
END    
    
   DROP TABLE #TMP_DELNote13    
   DROP TABLE #TMP_DELNote13Size    
END    

GO