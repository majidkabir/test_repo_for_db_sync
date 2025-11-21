SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Proc: isp_PackListBySku13                                     */        
/* Creation Date: 10-DEC-2018                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: WLCHOOI                                                  */        
/*                                                                      */        
/* Purpose: WMS-7199 SG - Triple - ECOM Shipping Invoice                */        
/*        :                                                             */        
/* Called By: r_dw_packing_list_by_Sku13                                */        
/*          :                                                           */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 21-Feb-2019 WLCHOOI  1.0   WMS-7199 - Change the logic of calculating*/        
/*                                       QTY and ExtendedPrice          */        
/* 18-Mar-2020 CSCHONG  1.1   WMS-12557 - add report config (CS01)      */        
/* 13-May-2020 CSCHONG  1.2   WMS-12557 - fix duplicate issue (CS02)    */      
/* 25-AUG-2021 CSCHONG  1.2   WMS-17750 fix deuplicate detail (CS03)    */  
/* 02-Jun-2023 CSCHONG  1.3   Devops Scripts Combine & WMS-22669(CS04)  */
/************************************************************************/        
CREATE   PROC [dbo].[isp_PackListBySku13]               
     @c_PickSlipNo        NVARCHAR(10)     
    
AS        
BEGIN        
 SET NOCOUNT ON        
 SET ANSI_NULLS OFF        
 SET QUOTED_IDENTIFIER OFF        
 SET CONCAT_NULL_YIELDS_NULL OFF        
              
         
   DECLARE @c_descr      NVARCHAR(90),        
           @c_sku        NVARCHAR(90),        
           @c_extprice   FLOAT,        
           @c_b_contact1 NVARCHAR(90),        
           @c_b_address1 NVARCHAR(90),        
           @c_b_address2 NVARCHAR(90),        
           @c_b_address3 NVARCHAR(90),        
           @c_b_address4 NVARCHAR(90),        
           @c_c_contact1 NVARCHAR(90),        
           @c_c_address1 NVARCHAR(90),        
           @c_c_address2 NVARCHAR(90),        
           @c_c_address3 NVARCHAR(90),        
           @c_c_address4 NVARCHAR(90),        
           @c_c_city     NVARCHAR(90),        
           @c_userdef05  NVARCHAR(30),        
           @c_qty        INT,        
           @c_showField  NVARCHAR(1)   --CS01        
        
        
   SET @c_descr = ''        
   SET @c_sku = ''        
   SET @c_extprice = 0.00        
        
 CREATE TABLE #PLISTBYSKU13(        
                             B_Contact1        NVARCHAR(60)        
                            ,B_Address1        NVARCHAR(90)        
                            ,B_Address2        NVARCHAR(90)        
                            ,B_Address3        NVARCHAR(90)        
                            ,B_Address4        NVARCHAR(90)        
                            ,C_Contact1        NVARCHAR(60)        
                            ,C_Address1        NVARCHAR(90)        
                            ,C_Address2        NVARCHAR(90)        
                            ,C_Address3        NVARCHAR(90)        
                            ,C_Address4        NVARCHAR(90)        
                            ,C_City            NVARCHAR(90)        
                            ,Descr             NVARCHAR(90)        
                            ,Qty               INT        
                            ,ExtPrice          FLOAT        
                            ,UserDefine05      NVARCHAR(30)        
                            ,PickSlipNo        NVARCHAR(10)        
                            ,SKU               NVARCHAR(50)        
                            ,ShowField         NVARCHAR(1)        --CS01       
                            ,OrderLineNo       NVARCHAR(10)
                            ,externorderkey    NVARCHAR(50)       --CS04
                           )      
              
           
        
 INSERT INTO #PLISTBYSKU13(B_Contact1,B_Address1,B_Address2,B_Address3,B_Address4,C_Contact1,C_Address1,C_Address2,C_Address3,C_Address4        
                          ,C_City, Descr, Qty,ExtPrice,UserDefine05,PickSlipNo,SKU,ShowField,OrderLineNo,externorderkey)           --CS01   --CS04     
 SELECT DISTINCT   ISNULL(O.B_contact1,'')                                              --CS03  
                  ,ISNULL(O.B_Address1,'')        
                  ,ISNULL(O.B_Address2,'')        
                  ,ISNULL(O.B_Address3,'')        
                  ,ISNULL(O.B_Address4,'')        
                  ,ISNULL(O.C_contact1,'')        
                  ,ISNULL(O.C_Address1,'')        
                  ,ISNULL(O.C_Address2,'')        
                  ,ISNULL(O.C_Address3,'')        
                  ,ISNULL(O.C_Address4,'')        
                  ,ISNULL(O.C_City,'')        
                  ,LTRIM(RTRIM(S.DESCR))        
                  ,(PID.QTY)               --CS02      
                  ,OD.ExtendedPrice--*PID.QTY        
                  ,ISNULL(OD.USERDEFINE05,'')        
                  ,PH.PickSlipNo        
                           ,OD.SKU         --CS02      
                  --,''                       --CS02      
                  ,ISNULL(CLR.short,'N') as ShowField             --CS01    
                  ,OD.OrderLineNumber 
                  ,RTRIM(O.ExternOrderKey)             --CS04     
 FROM ORDERS     O  WITH (NOLOCK)        
 JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey        
 JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)         
 CROSS APPLY (SELECT SUM(PICKD.qty) AS QTY FROM dbo.PICKDETAIL PICKD WITH (NOLOCK) WHERE PICKD.OrderKey = OD.OrderKey  AND PICKD.OrderLineNumber = OD.OrderLineNumber   
                                     AND PICKD.sku = OD.sku AND PICKD.Storerkey = OD.StorerKey) AS PID  
 JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = OD.Storerkey)        
                                    AND(S.Sku = OD.Sku)         
 --CS01 START        
 LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (o.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'          
              AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_Sku13' AND ISNULL(CLR.Short,'') <> 'N'        
              AND CLR.code2 = UPPER(O.shipperkey))         
 --CS01 END        
 WHERE  PH.PickSlipNo = @c_PickSlipNo AND O.OrderGroup = 'ECOM'        
       
        
 SELECT   B_Contact1        
         ,B_Address1        
         ,B_Address2        
         ,B_Address3        
         ,B_Address4        
         ,C_Contact1        
         ,C_Address1        
         ,C_Address2        
         ,C_Address3        
         ,C_Address4        
         ,C_City        
         ,Descr        
         ,Qty  as qty      
         ,ExtPrice        
         ,UserDefine05  
         ,SKU         
         ,showfield     --cs01      
         ,externorderkey     --CS04 
         ,OrderLineNo 
 from #PLISTBYSKU13      
   
        
END -- procedure  

GO