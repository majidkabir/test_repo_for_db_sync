SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/    
/* Store Procedure: isp_carton_shipping_label                                 */    
/* Creation Date: 12-feb-2016                                                 */    
/* Copyright: IDS                                                             */    
/* Written by: CSCHONG                                                        */    
/*                                                                            */    
/* Purpose:  SOS#362692 -Carters SZ - RDT Outbound Label                      */    
/*                                                                            */    
/* Called By: Powerbuilder                                                    */    
/*                                                                            */    
/* PVCS Version: 1.1                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author    Ver.  Purposes                                      */  
/* 10-Jun-2016  CSCHONG   1.1   SOS#371538 Update Externorderkey logic (CS01) */  
/* 01-Aug-2016  CSCHONG   1.2   Revised Address field for space between (CS02)*/  
/* 14-Feb-2017  CSCHONG   1.3   WMS-1072 - Revise field logic (CS03)          */    
/* 05-NOV-2018  CSCHONG   1.4   Avoid many to many join (CS04)                */    
/* 28-Jan-2019  TLTING_ext 1.5  enlarge externorderkey field length           */  
/******************************************************************************/    
    
CREATE PROC [dbo].[isp_carton_shipping_label] (@c_LabelNo NVARCHAR(20))    
AS    
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF   
    
BEGIN  
 DECLARE @n_Cnt                INT,  
         @n_PosStart           INT,  
         @n_PosEnd             INT,  
         @n_DashPos            INT,  
         @c_ExecSQLStmt        NVARCHAR(MAX),  
         @c_ExecArguments      NVARCHAR(MAX),  
         @c_ExternOrderkey     NVARCHAR(50),   --tlting_ext  
         @c_OrderkeyStart      NVARCHAR(10),  
         @c_OrderkeyEnd        NVARCHAR(10),  
         @c_ReprintFlag        NVARCHAR(1),  
         @n_CartonNo           INT,  
         @c_Storerkey          NVARCHAR(15),  
         @c_Style              NVARCHAR(20),  
         @c_Color              NVARCHAR(10),  
         @c_Size               NVARCHAR(5),  
         @n_Qty                INT,  
         @c_colorsize_busr67   NVARCHAR(10), --NJOW01  
         @n_Err                INT,  --NJOW01  
         @c_ErrMsg             NVARCHAR(250),  --NJOW01  
         @b_Success            INT,  --NJOW01  
     @n_prncopy            INT,  
     @c_ExternOrdKey       NVARCHAR(50),   --(CS01)      --tlting_ext  
     @c_GetExternOrdKey    NVARCHAR(50),   --(CS01)      --tlting_ext  
     @c_Getlabelno         NVARCHAR(20),   --(CS01)  
     @n_CTNExtOrdkey       INT             --(CS01)  
       
   
 SET @n_Cnt = 1    
 SET @n_PosStart = 0  
 SET @n_PosEnd = 0  
 SET @n_DashPos = 0  
   
 SET @c_ExecSQLStmt = ''    
 SET @c_ExecArguments = ''  
   
 SET @n_CartonNo = 0  
 SET @c_Storerkey = ''  
 SET @c_Style = ''   
 SET @c_Color = ''   
 SET @c_Size = ''   
 SET @n_Qty = 0  
 SET @n_prncopy = 0  
   
 CREATE TABLE #TempGenericCartonLBL  
 (  
  FromAdd            NVARCHAR(250) NULL,  
      ToAdd              NVARCHAR(250) NULL,  
      ShipBarCode        NVARCHAR(20) NULL,              
  ExternOrderkey     NVARCHAR(10) NULL,  
  EffectiveDate      DATETIME,  
  CartonType         NVARCHAR(10) NULL,  
  DCNo               NVARCHAR(10) NULL,  
  DEPT               NVARCHAR(20) NULL,  
      PONo               NVARCHAR(20) NULL,  
      StoreBarcode       NVARCHAR(35) NULL,  
      StoreNo            NVARCHAR(5) NULL,  
  Labelno            NVARCHAR(20) NULL,  
  containerType      NVARCHAR(60) NULL  
   
 )                                                 
   
  
    
 INSERT INTO #TempGenericCartonLBL  
   (  
    FromAdd            ,  
      ToAdd              ,  
      ShipBarCode        ,              
  ExternOrderkey     ,  
  EffectiveDate      ,  
  CartonType         ,  
  DCNo               ,  
  DEPT               ,  
      PONo               ,  
      StoreBarcode       ,  
      StoreNo   ,  
  Labelno            ,  
  containerType        
   )  
   
SELECT DISTINCT (FAC.descr + CASE WHEN ISNULL(FAC.descr,'') <> '' THEN ' ' END +FAC.address1 + ' ' +     --(CS03)  
                 FAC.Address2 + ' ' +FAC.Address3 + ' ' +FAC.Address4 + ' ' +                            --(CS03)  
                 FAC.City + ' ' +  FAC.State + ' ' + FAC.Zip + ' ' + FAC.Country) AS COl01,              --(CS03)    
         (ORD.M_Company + CHAR(13) +  
         ORD.M_Address1 + CHAR(13) +  
         ORD.M_Address2 + CHAR(13) +  
         ORD.M_Address3 + CHAR(13) +  
         ORD.M_city + ',' +           --(CS02)  
         ORD.M_State + ' ' +   
         ORD.M_Zip + ' ' +  
         ORD.M_Country ),  
         ('420' + ORD.M_Zip),  
         '' ,--ORD.Externorderkey,             --(CS01)  
         CASE WHEN ISNULL(ORD.EffectiveDate,'') <> '' THEN ORD.EffectiveDate  
         ELSE CAST (ORD.UserDefine06 as datetime) END,  
         PI.Cartontype,  
         CASE WHEN ISNULL(ORD.Stop,'') <> '' THEN ORD.Stop   
         ELSE ORD.M_ISOCntryCode END ,  
         ORD.userdefine02  ,  
         ORD.BuyerPO ,  
         ('91' + CASE WHEN LEN(ORD.C_Contact2) > 5 THEN LEFT(ORD.C_Contact2,5)  --(CS03)  
                  ELSE RIGHT('00000'+ISNULL(ORD.C_Contact2,''),5) END) ,  --(CS03)  
         CASE WHEN LEN(ORD.C_Contact2) > 5 THEN LEFT(ORD.C_Contact2,5)  --(CS03)  
                  ELSE RIGHT('00000'+ISNULL(ORD.C_Contact2,''),5) END ,  
         PDET.labelno,  
         'label type:' + ISNULL(ORD.ContainerType,'')  
  FROM PACKHEADER PH WITH (NOLOCK)  
  JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
  JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU  --CS04    
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
  JOIN STORER S WITH (NOLOCK) ON S.Storerkey = ORD.consigneekey  
  JOIN FACILITY FAC WITH (NOLOCK) ON FAC.Facility = ORD.Facility  
  LEFT JOIN Packinfo PI WITH (NOLOCK) ON PI.Pickslipno = PDET.Pickslipno   
                                 AND PI.Cartonno = PDET.Cartonno  
  WHERE PDET.Labelno = @c_LabelNo  
 -- ORDER BY PH.Pickslipno  desc  
  
 /*CS01 Start*/  
   
  DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  SELECT Labelno  
  FROM #TempGenericCartonLBL  
  WHERE labelno = @c_LabelNo  
  
  OPEN C_Lebelno   
  FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno  
  
  WHILE (@@FETCH_STATUS <> -1)   
  BEGIN   
     
     
     SET @c_ExternOrdKey =''  
   SET @c_GetExternOrdKey =''  
   SET @n_CTNExtOrdkey =1  
    
    SELECT --@c_Externordkey = ORD.ExternOrderkey,   
           @n_CtnExtOrdkey = COUNT(DISTINCT Ord.ExternOrderKey)  
  FROM PACKHEADER PH WITH (NOLOCK)  
  JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
    JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU  --CS04    
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
  WHERE PDET.Labelno = @c_LabelNo  
   -- GROUP BY Ord.ExternOrderKey  
   
   
 IF @n_CTNExtOrdkey>1  
 BEGIN  
  SET @c_GetExternOrdKey = 'MULTIPLE'  
 END  
 ELSE  
  BEGIN  
   SET @c_GetExternOrdKey =@c_Externordkey  
    SELECT TOP 1 @c_GetExternOrdKey = CASE WHEN LEN(ORD.ExternOrderkey) > 10 THEN RIGHT(ORD.ExternOrderkey,10)  --(CS03)  
                                      ELSE ORD.ExternOrderkey END                                             --(CS03)  
    FROM PACKHEADER PH WITH (NOLOCK)  
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
          JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU  --CS04    
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
    WHERE PDET.Labelno = @c_LabelNo  
     
  END  
    
 UPDATE #TempGenericCartonLBL  
   SET ExternOrderkey = @c_GetExternOrdKey                   
   Where labelno=@c_Getlabelno  
     
    
  FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno  
  END   
     
  CLOSE C_Lebelno  
  DEALLOCATE C_Lebelno    
   
   
 /*CS01 End*/  
  
 SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)  
 FROM PACKHEADER PH WITH (NOLOCK)  
 JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
 JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU  --CS04    
 JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
 WHERE PDET.Labelno = @c_LabelNo  
   
  
WHILE @n_prncopy > 1  
BEGIN  
  
INSERT INTO #TempGenericCartonLBL  
   (  
    FromAdd            ,  
      ToAdd              ,  
      ShipBarCode        ,              
  ExternOrderkey     ,  
  EffectiveDate      ,  
  CartonType         ,  
  DCNo               ,  
  DEPT               ,  
      PONo               ,  
      StoreBarcode       ,  
      StoreNo            ,  
  Labelno            ,  
  containerType        
   )  
SELECT TOP 1 FromAdd        ,  
      ToAdd              ,  
      ShipBarCode        ,              
  ExternOrderkey     ,  
  EffectiveDate      ,  
  CartonType         ,  
  DCNo               ,  
  DEPT               ,  
      PONo               ,  
      StoreBarcode       ,  
      StoreNo            ,  
  Labelno            ,  
  containerType        
 FROM   #TempGenericCartonLBL  
  
  
 SET @n_prncopy = @n_prncopy - 1  
  
END  
   
IF @n_prncopy >= 1  
BEGIN  
 SELECT FromAdd        ,  
      ToAdd              ,  
      ShipBarCode        ,              
  ExternOrderkey     ,  
  EffectiveDate      ,  
  CartonType         ,  
  DCNo               ,  
  DEPT               ,  
      PONo               ,  
      StoreBarcode       ,  
      StoreNo            ,  
  Labelno            ,  
  containerType        
 FROM   #TempGenericCartonLBL  
END   
   
 DROP TABLE #TempGenericCartonLBL  
END    
  

GO