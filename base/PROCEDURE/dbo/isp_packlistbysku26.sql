SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Proc: isp_PackListBySku26                                     */        
/* Creation Date: 26-Apr-2022                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: CSCHONG                                                  */        
/*                                                                      */        
/* Purpose: WMS-19430 MYSûUAMYûModify UAMY Packing List by SKU          */        
/*        :                                                             */        
/* Called By: r_dw_packing_list_by_Sku26                                */        
/*          :                                                           */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 26-Apr-2022 CSCHONG  1.0  devops Scripts Combine                     */       
/* 23-MAY-2022 CSCHONG  1.1  Fix qty issue (CS01)                       */ 
/************************************************************************/        
CREATE PROC [dbo].[isp_PackListBySku26]            
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
           @c_showField  NVARCHAR(1)          
        
        
   SET @c_descr = ''        
   SET @c_sku = ''        
   SET @c_extprice = 0.00        
        
 CREATE TABLE #PLISTBYSKU26(        
  B_Contact1   NVARCHAR(60)        
 ,B_Address1   NVARCHAR(90)        
 ,B_Address2   NVARCHAR(90)        
 ,B_Address3   NVARCHAR(90)        
 ,B_Address4   NVARCHAR(90)        
 ,C_Contact1   NVARCHAR(60)        
 ,C_Address1   NVARCHAR(90)        
 ,C_Address2   NVARCHAR(90)        
 ,C_Address3   NVARCHAR(90)        
 ,C_Address4   NVARCHAR(90)        
 ,C_City       NVARCHAR(90)        
 ,Descr        NVARCHAR(90)        
 ,Qty          INT        
 ,PIFWGT       FLOAT        
 --,UserDefine05  NVARCHAR(30)        
 ,PickSlipNo   NVARCHAR(10)        
 ,SKU          NVARCHAR(50)        
 --,ShowField    NVARCHAR(1)            
 --,OrderLineNo  NVARCHAR(10)
 ,ExtOrdkey    NVARCHAR(50)
 ,C_State      NVARCHAR(90)   
 ,C_Zip        NVARCHAR(90)   
 ,Logo         NVARCHAR(50)
 ,labelno      NVARCHAR(20)
, OHNotes      NVARCHAR(4000) )  
        
      
   CREATE TABLE #PLISTBYSKU26_Final(        
  B_Contact1   NVARCHAR(60)        
 ,B_Address1   NVARCHAR(90)        
 ,B_Address2   NVARCHAR(90)        
 ,B_Address3   NVARCHAR(90)        
 ,B_Address4   NVARCHAR(90)        
 ,C_Contact1   NVARCHAR(60)        
 ,C_Address1   NVARCHAR(90)        
 ,C_Address2   NVARCHAR(90)        
 ,C_Address3   NVARCHAR(90)        
 ,C_Address4   NVARCHAR(90)        
 ,C_City       NVARCHAR(90)        
 ,Descr        NVARCHAR(90)   
 ,Qty          INT        
 ,ExtPrice     FLOAT        
 ,UserDefine05  NVARCHAR(30)        
 ,ShowField    NVARCHAR(1))           
           
        
 INSERT INTO #PLISTBYSKU26(B_Contact1,B_Address1,B_Address2,B_Address3,B_Address4,C_Contact1,C_Address1,C_Address2,C_Address3,C_Address4        
        ,C_City, Descr, Qty,PIFWGT,PickSlipNo,SKU,ExtOrdkey,C_State,C_Zip,Logo,labelno,OHNotes)                   
 SELECT DISTINCT ISNULL(O.B_contact1,'')                                             
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
   ,LTRIM(RTRIM(PID.DESCR))        
   ,(PID.QTY)                   --CS01
   ,PID.PWGT--*PID.QTY          --Cs01 
   --,ISNULL(OD.USERDEFINE05,'')        
   ,PH.PickSlipNo        
   ,'' --OD.SKU        --CS01   
   --,''                       
  -- ,ISNULL(CLR.short,'N') as ShowField            
   --,OD.OrderLineNumber  
     , O.ExternOrderKey
     , ISNULL(O.C_State,'')  
     , ISNULL(O.C_Zip,'')   
     , CASE WHEN UPPER(RTRIM(O.ShipperKey)) = 'SHOPEE' THEN 'S' ELSE  CASE WHEN UPPER(RTRIM(O.ShipperKey)) = 'LAZADA' THEN 'L' ELSE 'NOLOGO' END END 
     , PID.LabelNo   --CS01
     , ISNULL(O.Notes,'')   
 FROM ORDERS     O  WITH (NOLOCK)        
 JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey        
 JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)     
 JOIN PackDetail PD WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo   
--CS02 S
 --CROSS APPLY (SELECT PICKD.CaseID,SUM(PICKD.qty) AS QTY FROM dbo.PICKDETAIL PICKD WITH (NOLOCK) WHERE PICKD.OrderKey = OD.OrderKey  AND PICKD.OrderLineNumber = OD.OrderLineNumber   
 --                                    AND PICKD.sku = OD.sku AND PICKD.Storerkey = OD.StorerKey GROUP BY PICKD.CaseID) AS PID  
-- JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = OD.Storerkey)        
--                                    AND(S.Sku = OD.Sku)         
--LEFT JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo= PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo          
 CROSS APPLY (SELECT PICKD.PickSlipNo,PICKD.LabelNo,PICKD.CartonNo,sum(PICKD.qty) AS QTY ,s.DESCR AS DESCR,(ISNULL(pif.Weight,0)) AS PWGT
              FROM dbo.PACKDETAIL PICKD WITH (NOLOCK) 
              JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PICKD.StorerKey AND S.sku = PICKD.sku
              LEFT JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo= PICKD.PickSlipNo AND PIF.CartonNo = PICKD.CartonNo 
              WHERE ph.PickSlipNo = PICKD.PickSlipNo  
              GROUP BY PICKD.PickSlipNo,PICKD.LabelNo,PICKD.CartonNo,s.DESCR,(ISNULL(pif.Weight,0))) AS PID  
--CS01 E
 WHERE  PH.PickSlipNo = @c_PickSlipNo AND O.OrderGroup = 'ECOM'        
 --AND PD.CartonNo >= CAST(@c_StartCartonno as INT)         
 --AND PD.CartonNo <= CAST(@c_EndCartonno as INT)         
 --GROUP BY  ISNULL(O.B_contact1,'')        
 --  ,ISNULL(O.B_Address1,'')        
 --  ,ISNULL(O.B_Address2,'')        
 --  ,ISNULL(O.B_Address3,'')        
 --  ,ISNULL(O.B_Address4,'')        
 --  ,ISNULL(O.C_contact1,'')        
 --  ,ISNULL(O.C_Address1,'')        
 --  ,ISNULL(O.C_Address2,'')        
 --  ,ISNULL(O.C_Address3,'')        
 --  ,ISNULL(O.C_Address4,'')        
 --  ,ISNULL(O.C_City,'')        
 --  ,LTRIM(RTRIM(S.DESCR))              
 --  ,PIF.Weight              
 --  ,PH.PickSlipNo        
 --  ,OD.SKU  
 --  , O.ExternOrderKey
 --  , ISNULL(O.C_State,'')  
 --  , ISNULL(O.C_Zip,'')   
 --  ,CASE WHEN UPPER(RTRIM(O.ShipperKey)) = 'SHOPEE' THEN 'S' ELSE  CASE WHEN UPPER(RTRIM(O.ShipperKey)) = 'LAZADA' THEN 'L' ELSE 'NOLOGO' END END  
 --  , PD.LabelNo
 --  , ISNULL(O.Notes,'')       
              
        
 SELECT B_Contact1        
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
 ,(Qty)  as qty      
 ,PIFWGT    
 ,PickSlipNo    
 ,'' AS SKU         
 ,ExtOrdkey,C_State,C_Zip,Logo,labelno,OHNotes   
 from #PLISTBYSKU26 
--GROUP BY  B_Contact1        
--         ,B_Address1        
--         ,B_Address2        
--         ,B_Address3        
--         ,B_Address4        
--         ,C_Contact1        
--         ,C_Address1        
--         ,C_Address2        
--         ,C_Address3        
--         ,C_Address4        
--         ,C_City        
--         ,Descr       
--         ,PIFWGT    
--         ,PickSlipNo
--         ,ExtOrdkey,C_State,C_Zip,Logo,labelno,OHNotes          
ORDER BY PickSlipNo,labelno

        
END -- procedure    


GO