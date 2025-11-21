SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Store Procedure: isp_UCC_Carton_Label_52_rdt                               */    
/* Creation Date: 15-Nov-2016                                                 */    
/* Copyright: IDS                                                             */    
/* Written by: CSCHONG                                                        */    
/*                                                                            */    
/* Purpose:  WMS-445 - BrownShoe Carton Content Label                         */    
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
/* 02-Mar-2017  CSCHONG   1.0   WMS-445- change field logic (CS01)            */  
/* 20-Dec-2018  TLTITNG01 1.1   missing nolock                                */
/* 23-Jul-2021  AL01      1.2   INC1567905 - Bug fixed, add filter storerkey  */
/******************************************************************************/    
    
CREATE PROC [dbo].[isp_UCC_Carton_Label_52_rdt] (  
         @c_StorerKey      NVARCHAR(15)  
      ,  @c_PickSlipNo     NVARCHAR(10)  
      ,  @c_StartCartonNo  NVARCHAR(10)  
      ,  @c_EndCartonNo    NVARCHAR(10))  
  
AS    
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF  
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF  
SET CONCAT_NULL_YIELDS_NULL OFF    
    
BEGIN  
 DECLARE @c_ExecSQLStmt        NVARCHAR(MAX),  
         @c_ExecArguments      NVARCHAR(MAX),  
         @c_GetPickSlipNo      NVARCHAR(10),  
         @c_GetOrderkey        NVARCHAR(10),  
         @n_CartonNo           INT,  
         @c_Mode               NVARCHAR(1),  
         @c_Style              NVARCHAR(20),  
         @c_Notes              NVARCHAR(250),  
         @n_Qty                INT,  
         @n_Err                INT,   
         @c_ErrMsg             NVARCHAR(250),    
         @b_Success            INT ,  
         @c_Getlabelno         NVARCHAR(20),  
         @c_GetStorer          NVARCHAR(20),   
         @c_GetSKU             NVARCHAR(20),  
         @n_PackQty            INT,  
         @n_prncopy            INT,  
         @c_skusize            NVARCHAR(50),  
         @n_getCartonNo        INT,  
         @c_SNotes1            NVARCHAR(150),  
         @c_SNotes2            NVARCHAR(150),  
         @c_GetSNotes1         NVARCHAR(150),  
         @c_GetSNotes2         NVARCHAR(150),  
         @c_GetStorerKey       NVARCHAR(15),  
         @c_sku                NVARCHAR(20),  
         @n_TTLCarton          INT,  
         @c_mat                NVARCHAR(20),  
         @n_GrossWgt           FLOAT  
  
  
 SET @c_ExecSQLStmt = ''    
 SET @c_ExecArguments = ''  
   
 SET @n_CartonNo = 1  
   
 CREATE TABLE #TempUCCLabel50  
 (  PickSlipNo         NVARCHAR(10) NULL,  
    Orderkey           NVARCHAR(10) NULL,  
    FromAdd            NVARCHAR(250) NULL,  
    ToAdd              NVARCHAR(250) NULL,  
    Zip                NVARCHAR(18)  NULL,  
    City               NVARCHAR(45)  NULL,  
    Storerkey          NVARCHAR(20)  NULL,  
    SNotes1            NVARCHAR(150) NULL,  
    SNotes2            NVARCHAR(150) NULL,     
    ExternPOkey        NVARCHAR(20) NULL,  
    MAT                NVARCHAR(20) NULL,  
    Notes              NVARCHAR(250) NULL,  
    CustPO             NVARCHAR(50) NULL,  
    ODUdef03           NVARCHAR(30) NULL,  
    ODUdef04           NVARCHAR(30) NULL,  
    ODUdef05           NVARCHAR(30) NULL,  
    LineNum            NVARCHAR(10) NULL,  
    CartonLength       FLOAT NULL,  
    CartonWidth        FLOAT NULL,  
    CartonHeight       FLOAT NULL,  
    GrossWeight        FLOAT NULL,  
    CartonWeight       FLOAT NULL,   
    Qty                INT  NULL,  
    CartonNO           INT NULL,  
    TTLCarton          INT NULL,  
    Labelno            NVARCHAR(20) NULL,  
    SKU                NVARCHAR(20) NULL,               
    Mode               NVARCHAR(1) NULL,  
    CartonNum          NVARCHAR(10) NULL  
  )                                                 
    
 INSERT INTO #TempUCCLabel50  
   ( Pickslipno  ,  
     Orderkey    ,  
     FromAdd     ,     
     ToAdd       ,    
     Zip         ,  
     City        ,   
     Storerkey   ,  
     SNotes2     ,  
     SNotes1     ,  
     ExternPOkey ,     
     MAT         ,     
     Notes       ,     
     CustPO      ,     
     ODUdef03    ,     
     ODUdef04    ,     
     ODUdef05    ,     
     LineNum     ,     
     CartonLength,     
     CartonWidth ,     
     CartonHeight,     
     GrossWeight ,     
     CartonWeight,     
     Qty         ,     
     CartonNO    ,     
     TTLCarton   ,     
     Labelno     ,  
     SKU         ,  
     Mode        ,  
     CartonNum              
    )  
   
  SELECT DISTINCT ph.pickslipno,ord.OrderKey,  
  F.UserDefine11 + F.UserDefine12 + F.UserDefine13 + CHAR(13) +   
  F.UserDefine14 + F.UserDefine15  +CHAR(13) +  
  F.UserDefine16 + F.UserDefine17 +CHAR(13) +   
  F.UserDefine18 + F.UserDefine19 +CHAR(13) +  
  F.UserDefine20 + CHAR(13) AS FromAdd,  
  STO.Company  + CHAR(13) +  
  STO.Address1 + SPACE(1)  + STO.Address2 + SPACE(1) +STO.Address3 AS ToAdd, --+ CHAR(13) +  
  STO.Zip , STO.City,ord.StorerKey,  
  STO.Notes2,STO.Notes1,  
  SUBSTRING (OD.ExternPOKey,1, CHARINDEX ('-',OD.ExternPOKey)-1) AS ExternPOkey,'','',  
  SUBSTRING(OD.POkey,1,  
     CASE   
    WHEN  CHARINDEX('-',OD.POkey,8)=0 THEN   
     CASE   
      WHEN CHARINDEX('-',OD.POkey,6)=0 THEN LEN (OD.POkey)  
      WHEN CHARINDEX('-',OD.POkey,6)>0 THEN CHARINDEX('-',OD.POkey,6)-1   
     END   
    WHEN  CHARINDEX('-',OD.POkey,8)>0 THEN CHARINDEX('-',OD.POkey,8) -1   
     END) AS CustPO,  
  ISNULL(OD.UserDefine03,''),ISNULL(OD.UserDefine04,''),ISNULL(OD.UserDefine05,''),  
  SUBSTRING (OD.ExternPOKey,CHARINDEX ('-',OD.ExternPOKey)+1,20) AS LineNum,  
  ISNULL(CT.Cartonlength,0),ISNULL(CT.CartonWidth,0),ISNULL(CT.CartonHeight,0),0,ISNULL(CT.CartonWeight,0),0,  
  PD.CartonNo,1,  
  labelno,  
  '',  
  CASE WHEN ISNULL(OD.UserDefine08,'') IN ('','0') AND ISNULL(OD.UserDefine09,'') ='' AND ISNULL(OD.UserDefine10,'') = '' THEN 'S' ELSE 'M' END AS mode  
  ,CONVERT(NVARCHAR(10),PD.CartonNo)  
  FROM PackHeader AS ph WITH (NOLOCK)  
  JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = ph.PickSlipNo  
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=PH.OrderKey  
  JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=ORD.OrderKey  
  LEFT JOIN FACILITY F WITH (NOLOCK) ON F.Facility=ORD.Facility  
  LEFT JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.ConsigneeKey  
  LEFT JOIN Packinfo PI WITH (NOLOCK) ON PI.Pickslipno = PD.Pickslipno   
             AND PI.Cartonno = PD.Cartonno  
  LEFT JOIN CARTONIZATION CT WITH (NOLOCK) ON CT.Cartontype = PI.CartonType AND CT.CartonizationGroup='BWS'  
    WHERE (PH.PickSlipNo= @c_PickSlipNo)  
    AND (PH.Storerkey = @c_Storerkey)  
    AND (PD.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo)  
    ORDER BY PD.CartonNo  desc  
   
  DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  SELECT DISTINCT Pickslipno,Labelno,cartonNo,Snotes1, SNotes2,mode,Storerkey  
  FROM #TempUCCLabel50  
  WHERE pickslipno = @c_pickslipno  
  ORDER BY cartonNo  
  
  OPEN C_Lebelno   
  FETCH NEXT FROM C_Lebelno INTO @c_GetPickSlipNo ,@c_Getlabelno,@n_getCartonNo,@c_GetSNotes1,@c_GetSNotes2,@c_Mode,@c_GetStorerKey  
  
  WHILE (@@FETCH_STATUS <> -1)   
  BEGIN   
     
   SET @n_qty = 0  
   SET @c_SNotes1 =''  
   SET @c_SNotes2 = ''  
   SET @c_sku = ''  
   SET @c_Style = ''  
   SET @c_mat = ''  
   SET @c_Notes = ''  
   SET @n_GrossWgt = 0.00  
     
     
   IF ISNULL(@c_GetSNotes1,'') = ''  
   BEGIN  
      
    SELECT TOP 1 @c_SNotes1 = C.UDF02  
    FROM CODELKUP C WITH (NOLOCK)  
    JOIN STORER S WITH (NOLOCK) ON S.Country = C.Short AND S.State=C.Long  
    WHERE LISTNAME='BWSCNTREG'   
    AND S.StorerKey = @c_GetStorerKey   
   END  
     
     
   IF ISNULL(@c_GetSNotes2,'') = ''  
   BEGIN  
      
    SELECT TOP 1 @c_SNotes2 = C.UDF01  
    FROM CODELKUP C WITH (NOLOCK)  
    JOIN STORER S WITH (NOLOCK) ON S.Country = C.Short AND S.State=C.Long  
    WHERE LISTNAME='BWSCNTREG'   
    AND S.StorerKey = @c_GetStorerKey   
   END  
     
   IF @c_Mode = 'S'   
   BEGIN  
      
    SELECT DISTINCT @c_sku = PD.SKU  
    FROM PACKHEADER PH WITH (NOLOCK)  
    JOIN PACkDETAIL PD WITH (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo  
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey  
    JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORD.OrderKey  
    WHERE PH.PickSlipNo = @c_GetPickSlipNo  
    AND ISNULL(OD.UserDefine08,'') IN ('','0')  
    AND ISNULL(OD.UserDefine09,'') =''   
    AND ISNULL(OD.UserDefine10,'') = ''  
      
    SET @c_mat = @c_sku  
      
    SELECT @n_qty = SUM(bom.qty)  
    FROM BillOfMaterial AS bom (NOLOCK)  
    WHERE bom.Sku = @c_sku  
    AND bom.Storerkey=@c_GetStorerkey  
      
    SELECT @c_Notes = S.Notes2 + SPACE(1) + S.notes1              --(CS01)  
    FROM SKU S WITH (NOLOCK)  
    WHERE S.Sku = @c_sku  
    AND S.StorerKey = @c_GetStorerKey  
      
   END  
   ELSE  
   BEGIN  
    SET @c_sku = ''  
    SET @c_Notes = ''  
      
    SELECT TOP 1 @c_sku = PD.SKU  
    FROM PackDetail PD WITH (NOLOCK)     
    JOIN SKU S WITH (NOLOCK) ON  S.StorerKey = PD.Storerkey AND S.sku = PD.sku  
    WHERE PD.PickSlipNo = @c_GetPickSlipNo  
    AND PD.CartonNo = @n_getCartonNo  
      
    --SELECT DISTINCT @c_Style = S.Style  
    --FROM PackDetail PD WITH (NOLOCK)  
    --JOIN SKU S WITH (NOLOCK) ON  S.StorerKey = PD.Storerkey AND S.sku = PD.sku  
    --WHERE PD.PickSlipNo = @c_GetPickSlipNo  
    --AND PD.CartonNo = @n_getCartonNo  
      
    SELECT DISTINCT @c_Style = S.Style  
    FROM SKU S WITH (NOLOCK)  
    WHERE S.sku=@c_sku  
    AND S.StorerKey = @c_GetStorerKey --AL01
	
    SET @c_mat = @c_Style  
      
    SELECT @n_qty = SUM(pd.qty)  
    FROM Packdetail  AS PD (NOLOCK)  --tlting01  
    WHERE pd.PickSlipNo = @c_GetPickSlipNo  
    AND pd.labelno= @c_Getlabelno  
      
    SELECT @c_Notes = S.Notes2 + SPACE(1) + S.notes1     --(CS01)  
    FROM SKU S WITH (NOLOCK)  
    WHERE S.Sku = @c_sku  
    AND S.StorerKey = @c_GetStorerKey  
      
   END   
     
   SELECT @n_GrossWgt = SUM(WEIGHT)  
   FROM PackInfo (NOLOCK)  
   WHERE PickSlipNo = @c_PickSlipNo  
   AND CartonNo=@n_getCartonNo  
  
   UPDATE #TempUCCLabel50  
   SET sku    =  ISNULL(@c_sku,'')  
      ,MAT    =  @c_Mat  
      ,SNotes1 = CASE WHEN @c_SNotes1 <> '' THEN @c_SNotes1 ELSE SNotes1 END   
      ,SNotes2 = CASE WHEN @c_SNotes2 <> '' THEN @c_SNotes2 ELSE SNotes2 END   
      ,Notes   = @c_Notes  
      ,Qty     = @n_qty  
      ,GrossWeight = ISNULL(@n_GrossWgt,0.00)  
   Where Labelno   = @c_Getlabelno  
   AND PickSlipNo  = @c_PickSlipNo  
   AND CartonNO    = @n_getCartonNo  
     
    
  FETCH NEXT FROM C_Lebelno INTO @c_GetPickSlipNo ,@c_Getlabelno,@n_getCartonNo,@c_GetSNotes1,@c_GetSNotes2,@c_Mode,@c_GetStorerKey  
  END   
     
  CLOSE C_Lebelno  
  DEALLOCATE C_Lebelno   
  
  SET @n_TTLCarton = 1  
  
  SELECT @n_TTLCarton = MAX(cartonNo)   
  FROM PACKDETAIL (NOLOCK)  
  WHERE PickSlipNo = @c_PickSlipNo  
    
    
  UPDATE #TempUCCLabel50  
  SET TTLCarton = @n_TTLCarton  
  WHERE PickSlipNo = @c_PickSlipNo  
    
    
  SELECT * FROM #TempUCCLabel50   
  ORDER BY CartonNo  
   
 DROP TABLE #TempUCCLabel50  
END    

GO