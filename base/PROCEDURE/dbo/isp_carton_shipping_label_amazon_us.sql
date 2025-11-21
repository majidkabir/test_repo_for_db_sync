SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store Procedure: isp_carton_shipping_label_Amazon_US                       */    
/* Creation Date: 02-Oct-2020                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: WLChooi                                                        */    
/*                                                                            */    
/* Purpose: WMS-15407 - [CN] Cartersz new shipping label for AMAZON US        */    
/*                                                                            */    
/* Called By: r_dw_carton_shipping_label_amazon_us                            */    
/*                                                                            */    
/* GitLab Version: 1.0                                                        */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author    Ver.  Purposes                                      */  
/* 02-oCT-2020  WLChooi   1.0   DevOps Combine Script                         */
/******************************************************************************/    
CREATE   PROC [dbo].[isp_carton_shipping_label_Amazon_US](@c_LabelNo NVARCHAR(20))    
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
           @c_ExternOrderkey     NVARCHAR(50),    
           @c_OrderkeyStart      NVARCHAR(10),  
           @c_OrderkeyEnd        NVARCHAR(10),  
           @c_ReprintFlag        NVARCHAR(1),  
           @n_CartonNo           INT,  
           @c_Storerkey          NVARCHAR(15),  
           @c_Style              NVARCHAR(20),  
           @c_Color              NVARCHAR(10),  
           @c_Size               NVARCHAR(5),  
           @n_Qty                INT,  
           @c_colorsize_busr67   NVARCHAR(10),   
           @n_Err                INT,   
           @c_ErrMsg             NVARCHAR(250),    
           @b_Success            INT ,  
           @c_Getlabelno         NVARCHAR(20),  
           @c_GetStorer          NVARCHAR(20),   
           @c_GetSKU             NVARCHAR(20),  
           @c_busr1              NVARCHAR(30) ,  
           @n_PQty               INT,  
           @n_CntSKU             INT,  
           @n_PackQty            INT,  
           @n_freegoodqty        INT,  
           @c_ordUserdef03       NVARCHAR(20),  
           @n_prncopy            INT,  
           @c_skusize            NVARCHAR(50),  
           @c_ExternOrdKey       NVARCHAR(50),
           @c_GetExternOrdKey    NVARCHAR(50),
           @n_CTNExtOrdkey       INT,         
           @c_ODUDef03           NVARCHAR(18),
           @c_ORDSpecialHD       NVARCHAR(1), 
           @c_UpcCode            NVARCHAR(20),
           @c_Altsku             NVARCHAR(20),
           @c_GetAltsku          NVARCHAR(20),
           @c_sku                NVARCHAR(20),
           @c_BOMNotes           NVARCHAR(20),
           @c_ORDDETU04          NVARCHAR(20),
           @c_GetORDDETU04       NVARCHAR(20),
           @c_orderkey           NVARCHAR(10) 
     
   SET @n_Cnt = 1    
   SET @n_PosStart = 0  
   SET @n_PosEnd = 0  
   SET @n_DashPos = 0  
   SET @n_freegoodqty = 0  
     
   SET @c_ExecSQLStmt = ''    
   SET @c_ExecArguments = ''  
     
   SET @n_CartonNo = 0  
   SET @c_Storerkey = ''  
   SET @c_Style = ''   
   SET @c_Color = ''   
   SET @c_Size = ''   
   SET @n_Qty = 0  
   SET @n_CntSKU = 1  
   SET @n_PackQty = 0  
   SET @n_prncopy = 0  
   SET @c_skusize = ''  
   SET @c_ODUDef03 = ''        
   SET @c_ORDSpecialHD = ''    
   SET @c_UpcCode = ''         
   SET @c_Altsku = ''          
   SET @c_GetAltsku = ''       
   SET @c_Sku = ''             
   SET @c_BOMNotes = ''        
   SET @c_ORDDETU04 = ''       
   SET @c_GetORDDETU04 = ''    
     
   CREATE TABLE #TempAmazonUSCartonLBL  
   (  
      FromAdd            NVARCHAR(250) NULL,  
      ToAdd              NVARCHAR(250) NULL,  
      ShipBarCode        NVARCHAR(20) NULL,              
      ExternOrderkey     NVARCHAR(10) NULL,  
      EffectiveDate      DATETIME,  
      --CartonType         NVARCHAR(10) NULL,  
   -- DCNo               NVARCHAR(10) NULL,  
   -- DEPT               NVARCHAR(20) NULL,  
      PONo               NVARCHAR(20) NULL,  
      StoreBarcode       NVARCHAR(35) NULL,  
      StoreNo            NVARCHAR(6) NULL,  
      Labelno            NVARCHAR(20) NULL,  
      containerType      NVARCHAR(60) NULL,  
      carrier            NVARCHAR(150) NULL,  
      Mbolkey            NVARCHAR(20) NULL,  
      UPCCode            NVARCHAR(20)  NULL,  
      Caseqty            INT,  
      SKUSize            NVARCHAR(60) NULL,      
      ORDHUserDef04      NVARCHAR(20)  NULL,  
      freegoodqty        INT,  
      SpecialMark        NVARCHAR(10) NULL,
      Userdefine01       NVARCHAR(50) NULL  
   )                                                 
        
   INSERT INTO #TempAmazonUSCartonLBL  
     (  
      FromAdd            ,  --col01  
      ToAdd              ,  --col02  
      ShipBarCode        ,  --col03              
      ExternOrderkey     ,  --col04  
      EffectiveDate      ,  --col05  
      --CartonType       ,  
      --DCNo             ,  
   -- DEPT               ,  
      PONo                ,  --col09  
      StoreBarcode        ,  --col10  
      StoreNo            ,  --col17  
      Labelno            ,  --col12  
      containerType      ,  --col13  
      carrier            ,  --col14  
      mbolkey            ,  --col15  
      UPCCode            ,  --col20  
      Caseqty            ,  --col21  
      SKUSize            ,  --col22  
     --PONo             ,   
      ORDHUserDef04      ,  --col31  
      freegoodqty        ,  --col32  
      SpecialMark        ,  --col34   
      Userdefine01
     )  
     
   SELECT DISTINCT (CASE WHEN ISNULL(FAC.descr,'')    <> '' THEN FAC.descr + ' '    ELSE '' END +
                    CASE WHEN ISNULL(FAC.Address1,'') <> '' THEN FAC.Address1 + ' ' ELSE '' END +
                    CASE WHEN ISNULL(FAC.Address2,'') <> '' THEN FAC.Address2 + ' ' ELSE '' END +
                    CASE WHEN ISNULL(FAC.Address3,'') <> '' THEN FAC.Address3 + ' ' ELSE '' END +
                    CASE WHEN ISNULL(FAC.Address4,'') <> '' THEN FAC.Address4 + ' ' ELSE '' END +
                    CASE WHEN ISNULL(FAC.City,'')     <> '' THEN FAC.City + ' '     ELSE '' END +
                    CASE WHEN ISNULL(FAC.[State],'')  <> '' THEN FAC.[State] + ' '  ELSE '' END +
                    CASE WHEN ISNULL(FAC.Zip,'')      <> '' THEN FAC.Zip + ' '      ELSE '' END +
                    CASE WHEN ISNULL(FAC.Country,'')  <> '' THEN FAC.Country + ' '  ELSE '' END),
                    --FAC.Address1 + ' ' + FAC.Address2 + ' ' + FAC.Address3 + ' ' + FAC.Address4 + ' ' +  
                    --FAC.City + ' ' +  FAC.[State] + ' ' + FAC.Zip + ' ' + FAC.Country),
         (ORD.M_Company + CHAR(13) +  
         ORD.M_Address1 + CHAR(13) +  
         ORD.M_Address2 + CHAR(13) +  
         ORD.M_Address3 +
         ORD.M_city + ',' +       
         ORD.M_State +' ' +      
         ORD.M_Zip + ' ' +       
         ORD.M_Country ),  
         ('420' + ORD.M_Zip),  
         '', --ORD.Externorderkey,             
         CASE WHEN ISNULL(ORD.EffectiveDate,'') <> '' THEN ORD.EffectiveDate  
         ELSE CAST (ORD.UserDefine06 as datetime) END,  
       --  CASE WHEN ISNULL(ORD.Stop,'') <> '' THEN ORD.Stop   
       --  ELSE ORD.M_ISOCntryCode END ,  
        -- ORD.userdefine02  ,  
         ORD.BuyerPO ,  
        ('91' + CASE WHEN LEN(ORD.C_Contact2) >= 5 THEN LEFT(ORD.C_Contact2,5)  
                  --ELSE RIGHT('00000'+ISNULL(ORD.C_Contact2,''),5) END),        
                  ELSE ISNULL(ORD.C_Contact2,'')END ),      
         CASE WHEN LEN(ORD.C_Contact2) >= 5 THEN LEFT(ORD.C_Contact2,5)       
                  ELSE RIGHT(ISNULL(ORD.C_Contact2,''),5) END,       
         PDET.labelno,  
         'label type:'+ ISNULL(ORD.ContainerType,''),  
         ISNULL(C.notes,''),                 
         ORD.mbolkey,  
         '',  
         0,  
         '',--( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size),  
         ISNULL(ORD.userdefine04,''),0,  
         CASE WHEN ISNULL(CL1.Code,'') <> '' AND ISNULL(CL2.Code,'') <> '' THEN ISNULL(CL1.Notes,'') 
              WHEN ISNULL(CL3.Code,'') <> '' AND ISNULL(CL4.Code,'') <> '' THEN ISNULL(CL3.Notes,'') 
         ELSE '' END,
         ORD.UserDefine01   
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno   
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU   
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   JOIN STORER STO WITH (NOLOCK) ON STO.Storerkey = ORD.consigneekey  
   JOIN FACILITY FAC WITH (NOLOCK) ON FAC.Facility = ORD.Facility  
   LEFT JOIN Packinfo PI WITH (NOLOCK) ON PI.Pickslipno = PDET.Pickslipno   
                                      AND PI.Cartonno = PDET.Cartonno  
   JOIN SKU  S WITH (NOLOCK)  ON S.SKU = PDET.SKU AND S.storerkey = PDET.Storerkey  
   LEFT JOIN PO WITH (NOLOCK) ON PO.Externpokey = ORD.ExternPOKey   
   LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey=PDET.Storerkey AND U.SKU = PDET.SKU  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='CASHIPPER'   
                        AND c.code = ORD.IntermodalVehicle                       
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME='CALBLWBO' AND CL1.Storerkey = ORD.StorerKey  
                                       AND CL1.Code = ORD.BillToKey              
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME='CALBLWSKU' AND CL2.Storerkey = ORD.StorerKey   
                                       AND CL2.Code = PIDET.Sku                     
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME='CALBLBO' AND CL3.Storerkey = ORD.StorerKey   
                                       AND CL3.Code = ORD.BillToKey             
   LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.LISTNAME='CALBLSKU' AND CL4.Storerkey = ORD.StorerKey   
                                       AND CL4.Code = PIDET.Sku                      
   WHERE PDET.Labelno = @c_LabelNo  
 -- ORDER BY PH.Pickslipno  desc  
  
   SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU         
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   WHERE PDET.Labelno = @c_LabelNo  
   
   DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT Labelno  
   FROM #TempAmazonUSCartonLBL  
   WHERE labelno = @c_LabelNo  
     
   OPEN C_Lebelno   
   FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno  
     
   WHILE (@@FETCH_STATUS <> -1)   
   BEGIN   
      SELECT @n_CntSKU = COUNT(SKU)  
      FROM PACKDETAIL WITH (NOLOCK)  
      WHERE Labelno = @c_Getlabelno  
  
      SELECT TOP 1 --@n_freegoodqty = ORDET.freegoodqty  
              @c_OrdUserdef03 = ORD.Userdefine03  
             --,@c_ODUDef03 = RIGHT(ORDET.UserDefine03,LEN(ORDET.UserDefine03)-CHARINDEX('-',ORDET.UserDefine03))                   
             ,@c_ODUDef03 = RIGHT(RTRIM(ORDET.UserDefine03),LEN(RTRIM(ORDET.UserDefine03))-CHARINDEX('-',RTRIM(ORDET.UserDefine03)))
             ,@c_ORDSpecialHD = ORD.SpecialHandling                                                    
             ,@c_ORDDETU04    = ISNULL(ORDET.UserDefine04,'')                                          
             ,@c_orderkey     = ORD.OrderKey                                                           
             ,@c_Storerkey    = ORD.StorerKey                                                          
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
      JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
      JOIN ORDERDETAIL AS ORDET WITH (NOLOCK) ON ORDET.orderkey = ORD.OrderKey AND ORDET.SKU = PDET.SKU
      WHERE PDET.LabelNo = @c_Getlabelno  
     
      IF @c_ORDDETU04 <> '' AND ISNUMERIC(@c_ORDDETU04) = 1  
      BEGIN  
         SET @c_GetORDDETU04 = SUBSTRING(@c_ORDDETU04,0,7)+ '-' + SUBSTRING(@c_ORDDETU04,7,2) + '-' + SUBSTRING(@c_ORDDETU04,9,3)   
      END  
    
      SET @c_UpcCode = ''  
  
      IF @c_ORDSpecialHD IN ('1','2','3')  
      BEGIN  
     
         IF EXISTS (SELECT 1 FROM BillofMaterial WITH (NOLOCK)  
                    WHERE UDF01 = @c_ODUDef03 AND storerkey =@c_Storerkey)                          
     
         BEGIN  
           
            SELECT TOP 1 @c_Altsku = s.altsku  
                       , @c_skusize = ISNULL(( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size),'')  
            FROM BillofMaterial BOM WITH (NOLOCK)  
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = BOM.Storerkey  
            AND S.sku = BOM.Sku  
            WHERE UDF01=@c_ODUDef03                                            
            AND BOM.Storerkey = @c_Storerkey                                   
     
            IF ISNULL(@c_Altsku,'') <> ''  
            BEGIN  
              SET @c_UpcCode = @c_Altsku  
            END  
         END  
         ELSE  
         BEGIN  
            SET @c_skusize = @c_ODUDef03  
         END     
      END  
  
      IF @n_CntSKU > 1  
      BEGIN   
         SELECT @n_freegoodqty = SUM(ORDET.freegoodqty)                                                                     
         --FROM PACKHEADER PH WITH (NOLOCK)  
         --JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
         --JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno  
         FROM ORDERS ORD WITH (NOLOCK) --ON ORD.Orderkey = PIDET.Orderkey  
         JOIN ORDERDETAIL AS ORDET WITH (NOLOCK) ON ORDET.orderkey = ORD.OrderKey  
         --WHERE PDET.LabelNo = @c_Getlabelno  
         WHERE ORD.OrderKey =@c_orderkey  
         --AND RIGHT(ORDET.UserDefine03,LEN(ORDET.UserDefine03)-CHARINDEX('-',ORDET.UserDefine03))= @c_ODUDef03                        
         AND RIGHT(RTRIM(ORDET.UserDefine03),LEN(RTRIM(ORDET.UserDefine03))-CHARINDEX('-',RTRIM(ORDET.UserDefine03)))= @c_ODUDef03     
      END  
      ELSE  
      BEGIN  
         SELECT @n_freegoodqty = CASE WHEN SUM(ORDET.freegoodqty) = 0 THEN 1 ELSE SUM(ORDET.freegoodqty) END  --@n_freegoodqty = ISNULL(SUM(ORDET.freegoodqty),0)                                                
         FROM ORDERS ORD WITH (NOLOCK) --ON ORD.Orderkey = PIDET.Orderkey  
         JOIN ORDERDETAIL AS ORDET WITH (NOLOCK) ON ORDET.orderkey = ORD.OrderKey  
         --WHERE PDET.LabelNo = @c_Getlabelno  
         WHERE ORD.OrderKey =@c_orderkey  
      END  
    
      IF @c_ORDSpecialHD = '0'  
      BEGIN   
         IF @n_CntSKU > 1  
         BEGIN  
              
            SET @c_UpcCode = 'Mixed'  
            SET @c_skusize = 'Mixed'  
            --UPDATE #TempAmazonUSCartonLBL  
            --SET SKUSize = 'Mixed'  
            ----  ,ORDHUserDef04 = ''  
            --Where labelno=@c_Getlabelno  
         END  
         ELSE  
         BEGIN  
            SELECT @c_skusize = ( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size)  
                  ,@c_GetAltsku = S.ALTSKU                                                       
            FROM SKU S WITH (NOLOCK)  
            JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku  
            WHERE PDET.LabelNo = @c_Getlabelno   
     
            SELECT TOP 1 @c_GetAltsku = CASE WHEN S.BUSR1='1'  THEN CSKU.ALTSKU  
                                             WHEN S.BUSR1<>'1' THEN s.ALTSKU   
                                        END   
            FROM SKU S WITH (NOLOCK)  
            JOIN Pickdetail PD WITH (NOLOCK) ON PD.Sku = S.Sku AND PD.Storerkey = S.Storerkey
            INNER JOIN dbo.BillOfMaterial BOM (NOLOCK) ON s.Sku=BOM.Sku  AND BOM.Storerkey=s.Storerkey
            INNER JOIN dbo.SKU CSKU (NOLOCK) ON bom.ComponentSku=CSKU.Sku AND bom.Storerkey=CSKU.Storerkey  
            INNER JOIN orders OH (nolock) ON PD.orderkey=OH.orderkey  
            WHERE PD.caseid = @c_Getlabelno AND PD.OrderKey=@c_orderkey --AND OH.ContainerType IN ('12','012','112')  
 
            SET @c_UpcCode = @c_GetAltsku                     
            --UPDATE #TempAmazonUSCartonLBL  
            --SET --freegoodqty = CASE WHEN @n_freegoodqty = 0 THEN 1 ELSE @n_freegoodqty END,  
            --   SKUSize =@c_skusize  
            --Where labelno=@c_Getlabelno  
   
         END  
      END  
   
      UPDATE #TempAmazonUSCartonLBL  
      SET UPCCode = @c_UpcCode  
         ,SKUSize = @c_skusize  
         ,ORDHUserDef04 = @c_GetORDDETU04  
         ,freegoodqty = ISNULL(@n_freegoodqty,1)  
      Where labelno=@c_Getlabelno  

      SET @c_ExternOrdKey =''  
      SET @c_GetExternOrdKey =''  
      SET @n_CTNExtOrdkey =1  
    
      SELECT --@c_Externordkey = ORD.ExternOrderkey,   
             @n_CtnExtOrdkey = COUNT(DISTINCT Ord.ExternOrderKey)  
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
      JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno  AND PIDET.SKU = PDET.SKU         
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
         SELECT TOP 1 @c_GetExternOrdKey = CASE WHEN LEN(ORD.ExternOrderkey) > 10 THEN RIGHT(ORD.ExternOrderkey,10)    
                                           ELSE ORD.ExternOrderkey END                                                 
         FROM PACKHEADER PH WITH (NOLOCK)  
         JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
         JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU         
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
         WHERE PDET.Labelno = @c_LabelNo  
      END  
    
      SELECT @n_PackQty = sum(pd.qty * CASE WHEN ISNULL(s.BUSR1,0) = 0 THEN 0 ELSE s.BUSR1 END)  
      FROM PACKDETAIL PD WITH (NOLOCK)  
      JOIN sku s WITH (NOLOCK) ON s.Sku=pd.sku AND s.StorerKey=pd.StorerKey  
      WHERE Labelno = @c_Getlabelno  
  
      UPDATE #TempAmazonUSCartonLBL  
      SET Caseqty = @n_PackQty  
      -- ,Mqty    = @n_PackQty  
         ,ExternOrderkey = @c_GetExternOrdKey                   
      Where labelno=@c_Getlabelno  
    
   FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno  
   END   
     
   CLOSE C_Lebelno  
   DEALLOCATE C_Lebelno    
  
  
   SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU         
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   WHERE PDET.Labelno = @c_LabelNo  
  
   --SET @n_prncopy = 1  
   WHILE @n_prncopy > 1  
   BEGIN  
     
   INSERT INTO #TempAmazonUSCartonLBL  
        (  
              FromAdd            ,  --col01  
              ToAdd              ,  --col02  
              ShipBarCode        ,  --col03              
              ExternOrderkey     ,  --col04  
              EffectiveDate      ,  --col05  
              PONo               ,  --col09  
              StoreBarcode       ,  --col10  
              StoreNo            ,  --col17  
              Labelno            ,  --col12  
              containerType      ,  --col13  
              carrier            ,  --col14  
              mbolkey            ,  --col15  
              UPCCode            ,  --col20  
              Caseqty            ,  --col21  
              SKUSize            ,  --col22  
              ORDHUserDef04      ,  --col31  
              freegoodqty        ,  --col32  
              SpecialMark        ,  --col34      
              Userdefine01   
        )  
   SELECT TOP 1 FromAdd          ,  --col01  
              ToAdd              ,  --col02  
              ShipBarCode        ,  --col03              
              ExternOrderkey     ,  --col04  
              EffectiveDate      ,  --col05  
              PONo               ,  --col09  
              StoreBarcode       ,  --col10  
              StoreNo            ,  --col17  
              Labelno            ,  --col12  
              containerType      ,  --col13  
              carrier            ,  --col14  
              mbolkey            ,  --col15  
              UPCCode            ,  --col20  
              Caseqty            ,  --col21  
              SKUSize            ,  --col22  
              ORDHUserDef04      ,  --col31  
              freegoodqty        ,  --col32   
              SpecialMark        ,  --col34      
              Userdefine01
   FROM #TempAmazonUSCartonLBL  
  
      SET @n_prncopy = @n_prncopy - 1  
   END  
     
   IF @n_prncopy >= 1  
   BEGIN  
      SELECT  FromAdd            ,  --col01  
              ToAdd              ,  --col02  
              ShipBarCode        ,  --col03              
              ExternOrderkey     ,  --col04  
              EffectiveDate      ,  --col05  
              PONo               ,  --col09  
              StoreBarcode       ,  --col10  
              StoreNo            ,  --col17  
              Labelno            ,  --col12  
              containerType      ,  --col13  
              carrier            ,  --col14  
              mbolkey            ,  --col15  
              UPCCode            ,  --col20  
              Caseqty            ,  --col21  
              SKUSize            ,  --col22  
              ORDHUserDef04      ,  --col31  
              freegoodqty        ,  --col32     
              SpecialMark        ,  --col34      
              Userdefine01       
      FROM   #TempAmazonUSCartonLBL  
   END  
   
   IF OBJECT_ID('tempdb..#TempAmazonUSCartonLBL') IS NOT NULL
      DROP TABLE #TempAmazonUSCartonLBL
END    

GO