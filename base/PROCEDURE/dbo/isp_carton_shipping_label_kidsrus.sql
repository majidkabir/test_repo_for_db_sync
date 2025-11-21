SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store Procedure: isp_carton_shipping_label_KidsRUS                         */    
/* Creation Date: 10-Mar-2016                                                 */    
/* Copyright: IDS                                                             */    
/* Written by: CSCHONG                                                        */    
/*                                                                            */    
/* Purpose:  SOS#362692 - Carters SZ - RDT Outbound Label                     */    
/*                                                                            */    
/* Called By: Powerbuilder                                                    */    
/*                                                                            */    
/* PVCS Version: 2.6                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author    Ver.  Purposes                                      */  
/* 10-Jun-2016  CSCHONG   1.1   SOS#371538 Update Externorderkey logic (CS01) */  
/* 01-Aug-2016  CSCHONG   1.2   Revised Address field for space between (CS02)*/  
/* 05-Aug-2016  CSCHONG   1.3   Revised field logic (CS03)                    */  
/* 02-Sep-2016  CSCHONG   1.4   Add more filter to reduce lock table (CS04)   */  
/* 17-Oct-2016  CSCHONG   1.5   Fix freeqty when 0 set to 1 (CS05)            */  
/* 23-Jan-2017  SPChin    1.6   IN00249672 - Add RTRIM                        */  
/* 14-Feb-2017  CSCHONG   1.7   WMS-1072 - Revise field logic (CS06)          */      
/* 05-NOV-2018  CSCHONG   1.8   Avoid many to many join (CS07)                */     
/* 29-Jan-2019  TLTING_ext 1.9  enlarge externorderkey field length           */   
/* 20-Sep-2019  CSCHONG   2.0  WMS-10392 Performance tunning (CS08)           */  
/* 11-Mar-2020  KuanYee   2.1  INC1072061-Add Join statement condition (KY01) */      
/* 30-Mar-2020  WLChooi   2.2  WMS-11877 Add Special Mark (WL01)              */    
/* 09-Apr-2020  WLChooi   2.3  Fix missing UPCCode by Ran Zhou and tune the   */
/*                             query (WL02)                                   */
/* 07-Jun-2022  WLChooi   2.4  DevOps Combine Script                          */
/* 07-Jun-2022  WLChooi   2.4  Performance Tune - Filter UDF01 <> '' (WL03)   */
/* 25-Nov-2022  WLChooi   2.5  Performance Tune - Filter UDF01 <> NULL (WL04) */
/* 09-Jun-2023  WLChooi   2.6  Performance Tune (WL05)                        */
/******************************************************************************/    
CREATE   PROC [dbo].[isp_carton_shipping_label_KidsRUS](@c_LabelNo NVARCHAR(20))    
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
           @c_ExternOrderkey     NVARCHAR(40),   --tlting_ext  
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
           @c_ExternOrdKey       NVARCHAR(50),   --(CS01)      --tlting_ext  
           @c_GetExternOrdKey    NVARCHAR(50),   --(CS01)      --tlting_ext  
           @n_CTNExtOrdkey       INT,             --(CS01)  
           @c_ODUDef03           NVARCHAR(18),    --(CS03)  
           @c_ORDSpecialHD       NVARCHAR(1),     --(CS03)  
           @c_UpcCode            NVARCHAR(20),    --(CS03)  
           @c_Altsku             NVARCHAR(20),    --(CS03)  
           @c_GetAltsku          NVARCHAR(20),    --(CS03)  
           @c_sku                NVARCHAR(20),    --(CS03)  
           @c_BOMNotes           NVARCHAR(20),     --(CS03)  
           @c_ORDDETU04          NVARCHAR(20),     --(CS03)  
           @c_GetORDDETU04       NVARCHAR(20),     --(CS03)  
           @c_orderkey           NVARCHAR(10)      --(CS03)  
     
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
   SET @c_ODUDef03 = ''                 --(CS03)  
   SET @c_ORDSpecialHD = ''             --(CS03)  
   SET @c_UpcCode = ''                  --(CS03)  
   SET @c_Altsku = ''                   --(CS03)  
   SET @c_GetAltsku = ''                 --(CS03)  
   SET @c_Sku = ''                       --(CS03)  
   SET @c_BOMNotes = ''                 --(CS03)  
   SET @c_ORDDETU04 = ''                --(CS03)  
   SET @c_GetORDDETU04 = ''             --(CS03)  
     
   CREATE TABLE #TempKidsRUSCartonLBL  
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
      SpecialMark        NVARCHAR(10) NULL --WL01  
   )                                                 
        
   INSERT INTO #TempKidsRUSCartonLBL  
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
      SpecialMark           --col34   --WL01  
     )  
     
   SELECT DISTINCT (FAC.descr + CASE WHEN ISNULL(FAC.descr,'') <> '' THEN ' ' END +FAC.address1 + ' ' +FAC.Address2 + ' ' +FAC.Address3 + ' ' +FAC.Address4 + ' ' +  
                          FAC.City + ' ' +  FAC.State + ' ' + FAC.Zip + ' ' + FAC.Country) AS COl01,   --(CS06)  
         (ORD.M_Company + CHAR(13) +  
         ORD.M_Address1 + CHAR(13) +  
         ORD.M_Address2 + CHAR(13) +  
         ORD.M_Address3 + CHAR(13) +  
         ORD.M_city + ',' +        --(CS02)  
         ORD.M_State +' ' +        --(CS02)  
         ORD.M_Zip + ' ' +         --(CS02)  
         ORD.M_Country ),  
         ('420' + ORD.M_Zip),  
         '', --ORD.Externorderkey,                  --(CS01)  
         CASE WHEN ISNULL(ORD.EffectiveDate,'') <> '' THEN ORD.EffectiveDate  
         ELSE CAST (ORD.UserDefine06 as datetime) END,  
       --  CASE WHEN ISNULL(ORD.Stop,'') <> '' THEN ORD.Stop   
       --  ELSE ORD.M_ISOCntryCode END ,  
        -- ORD.userdefine02  ,  
         ORD.BuyerPO ,  
        ('91' + CASE WHEN LEN(ORD.C_Contact2) >= 5 THEN LEFT(ORD.C_Contact2,5)  --(CS06)  
                  --ELSE RIGHT('00000'+ISNULL(ORD.C_Contact2,''),5) END),        --(CS06)  
                  ELSE ISNULL(ORD.C_Contact2,'')END ),        --(CS06)  
         CASE WHEN LEN(ORD.C_Contact2) >= 5 THEN LEFT(ORD.C_Contact2,5)         --(CS06)  
                  ELSE RIGHT(ISNULL(ORD.C_Contact2,''),5) END,         --(CS06)  
         PDET.labelno,  
         'label type:'+ ISNULL(ORD.ContainerType,''),  
         ISNULL(C.notes,''),                    --(CS04)  
         ORD.mbolkey,  
         '',  
         0,  
         '',--( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size),  
         ISNULL(ORD.userdefine04,''),0,  
         CASE WHEN ISNULL(CL1.Code,'') <> '' AND ISNULL(CL2.Code,'') <> '' THEN ISNULL(CL1.Notes,'') --WL01  
              WHEN ISNULL(CL3.Code,'') <> '' AND ISNULL(CL4.Code,'') <> '' THEN ISNULL(CL3.Notes,'') --WL01  
         ELSE '' END --WL01  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno   
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     --CS07    
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   JOIN STORER STO WITH (NOLOCK) ON STO.Storerkey = ORD.consigneekey  
   JOIN FACILITY FAC WITH (NOLOCK) ON FAC.Facility = ORD.Facility  
   LEFT JOIN Packinfo PI WITH (NOLOCK) ON PI.Pickslipno = PDET.Pickslipno   
                                      AND PI.Cartonno = PDET.Cartonno  
   JOIN SKU  S WITH (NOLOCK)  ON S.SKU = PDET.SKU AND S.storerkey = PDET.Storerkey  
   LEFT JOIN PO WITH (NOLOCK) ON PO.Externpokey = ORD.ExternPOKey   
   LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey=PDET.Storerkey AND U.SKU = PDET.SKU  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname='CASHIPPER'   
                        AND c.code = ORD.IntermodalVehicle                         --(CS04)  
   LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME='CALBLWBO' AND CL1.Storerkey = ORD.StorerKey  
                                       AND CL1.Code = ORD.BillToKey                   --(WL01)  
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME='CALBLWSKU' AND CL2.Storerkey = ORD.StorerKey   
                                       AND CL2.Code = PIDET.Sku                       --(WL01)  
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.LISTNAME='CALBLBO' AND CL3.Storerkey = ORD.StorerKey   
                                       AND CL3.Code = ORD.BillToKey                   --(WL01)  
   LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.LISTNAME='CALBLSKU' AND CL4.Storerkey = ORD.StorerKey   
                                       AND CL4.Code = PIDET.Sku                       --(WL01)  
   WHERE PDET.Labelno = @c_LabelNo  
 -- ORDER BY PH.Pickslipno  desc  
  
   SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     --CS07    
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   WHERE PDET.Labelno = @c_LabelNo  
     
  
   DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT Labelno  
   FROM #TempKidsRUSCartonLBL  
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
             --,@c_ODUDef03 = RIGHT(ORDET.UserDefine03,LEN(ORDET.UserDefine03)-CHARINDEX('-',ORDET.UserDefine03))                    --(CS03),IN00249672  
             ,@c_ODUDef03 = RIGHT(RTRIM(ORDET.UserDefine03),LEN(RTRIM(ORDET.UserDefine03))-CHARINDEX('-',RTRIM(ORDET.UserDefine03))) --(CS03),IN00249672  
             ,@c_ORDSpecialHD = ORD.SpecialHandling                                                                  --(CS03)  
             ,@c_ORDDETU04    = ISNULL(ORDET.UserDefine04,'')                                                        --(CS03)  
             ,@c_orderkey     = ORD.OrderKey                                                                         --(CS03)    
             ,@c_Storerkey    = ORD.StorerKey                                                                        --(CS04)               
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
      JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     --CS07    
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
      JOIN ORDERDETAIL AS ORDET WITH (NOLOCK) ON ORDET.orderkey = ORD.OrderKey AND ORDET.SKU = PDET.SKU     --(KY01)     
      WHERE PDET.LabelNo = @c_Getlabelno  
    
      /*CS03 start*/  
      --SELECT TOP 1 @c_Altsku = S.ALTSKU                                                         --(CS03)  
      --            ,@c_sku = S.SKU                                                               --(CS03)  
      -- FROM SKU S WITH (NOLOCK)  
      -- JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku  
      -- WHERE PDET.LabelNo = @c_Getlabelno   
     
      IF @c_ORDDETU04 <> '' AND ISNUMERIC(@c_ORDDETU04) = 1  
      BEGIN  
         SET @c_GetORDDETU04 = SUBSTRING(@c_ORDDETU04,0,7)+ '-' + SUBSTRING(@c_ORDDETU04,7,2) + '-' + SUBSTRING(@c_ORDDETU04,9,3)   
      END  
    
      SET @c_UpcCode = ''  
  
      IF @c_ORDSpecialHD IN ('1','2','3')  
      BEGIN  
     
         IF EXISTS (SELECT 1 FROM BillofMaterial WITH (NOLOCK)  
                    WHERE UDF01 = @c_ODUDef03 AND storerkey =@c_Storerkey)                          --(CS04)  --(CS08)  
     
         BEGIN  
           
            SELECT TOP 1 @c_Altsku = s.altsku  
                       , @c_skusize = ISNULL(( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size),'')  
            FROM BillofMaterial BOM WITH (NOLOCK)  
            JOIN SKU S WITH (NOLOCK) ON S.StorerKey = BOM.Storerkey  
            AND S.sku = BOM.Sku  
            WHERE UDF01=@c_ODUDef03                                             --(CS08)  
            AND BOM.Storerkey = @c_Storerkey                                    --(CS04)  
            AND BOM.UDF01 <> '' AND BOM.UDF01 IS NOT NULL   --WL03   --WL04
            OPTION (FORCE ORDER)   --WL05
     
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
         --AND RIGHT(ORDET.UserDefine03,LEN(ORDET.UserDefine03)-CHARINDEX('-',ORDET.UserDefine03))= @c_ODUDef03                        --IN00249672  
         AND RIGHT(RTRIM(ORDET.UserDefine03),LEN(RTRIM(ORDET.UserDefine03))-CHARINDEX('-',RTRIM(ORDET.UserDefine03)))= @c_ODUDef03     --IN00249672        
      END  
      ELSE  
      BEGIN  
         SELECT @n_freegoodqty = CASE WHEN SUM(ORDET.freegoodqty) = 0 THEN 1 ELSE SUM(ORDET.freegoodqty) END  --@n_freegoodqty = ISNULL(SUM(ORDET.freegoodqty),0)   --(CS05)                                             
         FROM ORDERS ORD WITH (NOLOCK) --ON ORD.Orderkey = PIDET.Orderkey  
         JOIN ORDERDETAIL AS ORDET WITH (NOLOCK) ON ORDET.orderkey = ORD.OrderKey  
         --WHERE PDET.LabelNo = @c_Getlabelno  
         WHERE ORD.OrderKey =@c_orderkey  
      END  
    
      /*CS03 End*/  
  
      IF @c_ORDSpecialHD = '0'  
      BEGIN   
         IF @n_CntSKU > 1  
         BEGIN  
            --CS03  
            SET @c_UpcCode = 'Mixed'  
            SET @c_skusize = 'Mixed'  
            --UPDATE #TempKidsRUSCartonLBL  
            --SET SKUSize = 'Mixed'  
            ----  ,ORDHUserDef04 = ''  
            --Where labelno=@c_Getlabelno  
         END  
         ELSE  
         BEGIN  
            SELECT @c_skusize = ( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size)  
                  ,@c_GetAltsku = S.ALTSKU                                                     --(CS03)  
            FROM SKU S WITH (NOLOCK)  
            JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku  
            WHERE PDET.LabelNo = @c_Getlabelno   
     
            --WL02 START
            SELECT TOP 1 @c_GetAltsku = CASE WHEN S.BUSR1='1'  THEN CSKU.ALTSKU  
                                             WHEN S.BUSR1<>'1' THEN s.ALTSKU   
                                        END   
            FROM SKU S WITH (NOLOCK)  
            JOIN Pickdetail PD WITH (NOLOCK) ON PD.Sku = S.Sku AND PD.Storerkey = S.Storerkey
            INNER JOIN dbo.BillOfMaterial BOM (NOLOCK) ON s.Sku=BOM.Sku  AND BOM.Storerkey=s.Storerkey
            INNER JOIN dbo.SKU CSKU (NOLOCK) ON bom.ComponentSku=CSKU.Sku AND bom.Storerkey=CSKU.Storerkey  
            INNER JOIN orders OH (nolock) ON PD.orderkey=OH.orderkey  
            WHERE PD.caseid = @c_Getlabelno AND PD.OrderKey=@c_orderkey --AND OH.ContainerType IN ('12','012','112')  
            --WL02 END
 
            SET @c_UpcCode = @c_GetAltsku                   --(CS03)  
            --UPDATE #TempKidsRUSCartonLBL  
            --SET --freegoodqty = CASE WHEN @n_freegoodqty = 0 THEN 1 ELSE @n_freegoodqty END,  
            --   SKUSize =@c_skusize  
            --Where labelno=@c_Getlabelno  
   
         END  
      END  
  
      /*CS03 start*/  
      UPDATE #TempKidsRUSCartonLBL  
      SET UPCCode = @c_UpcCode  
         ,SKUSize = @c_skusize  
         ,ORDHUserDef04 = @c_GetORDDETU04  
         ,freegoodqty = ISNULL(@n_freegoodqty,1)  
      Where labelno=@c_Getlabelno  
      /*CS03 End*/  
  
      /*CS01 Start*/  
      SET @c_ExternOrdKey =''  
      SET @c_GetExternOrdKey =''  
      SET @n_CTNExtOrdkey =1  
    
      SELECT --@c_Externordkey = ORD.ExternOrderkey,   
             @n_CtnExtOrdkey = COUNT(DISTINCT Ord.ExternOrderKey)  
      FROM PACKHEADER PH WITH (NOLOCK)  
      JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
      JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno  AND PIDET.SKU = PDET.SKU     --CS07    
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
         SELECT TOP 1 @c_GetExternOrdKey = CASE WHEN LEN(ORD.ExternOrderkey) > 10 THEN RIGHT(ORD.ExternOrderkey,10)  --(CS06)  
                                           ELSE ORD.ExternOrderkey END                                               --(CS06)  
         FROM PACKHEADER PH WITH (NOLOCK)  
         JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
         JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     --CS07    
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
         WHERE PDET.Labelno = @c_LabelNo  
      END  
    
  /*CS01 End*/  
  /*CS03 start*/  
   --SELECT TOP 1 @c_getSKU = MAX(SKU),  
   --             @n_Pqty =  SUM(qty),  
   --             @c_GetStorer = MAX(storerkey)  
   --FROM PACKDETAIL WITH (NOLOCK)  
   --WHERE Labelno = @c_Getlabelno  
  
   --SELECT @c_busr1 = busr1  
   --FROM SKU WITH (NOLOCK)  
   --WHERE Storerkey = @c_GetStorer  
   --AND SKU = @c_getSKU  
  
   --SET @n_PackQty = (@n_Pqty * CONVERT(decimal(6,2),@c_busr1))  
     
     
      SELECT @n_PackQty = sum(pd.qty*s.BUSR1)  
      FROM PACKDETAIL PD WITH (NOLOCK)  
      JOIN sku s WITH (NOLOCK) ON s.Sku=pd.sku AND s.StorerKey=pd.StorerKey  
      WHERE Labelno = @c_Getlabelno  
  
    /*CS03 End*/  
      UPDATE #TempKidsRUSCartonLBL  
      SET Caseqty = @n_PackQty  
      -- ,Mqty    = @n_PackQty  
         ,ExternOrderkey = @c_GetExternOrdKey                 --(CS01)  
      Where labelno=@c_Getlabelno  
     
    
   FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno  
   END   
     
   CLOSE C_Lebelno  
   DEALLOCATE C_Lebelno    
  
  
   SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)  
   FROM PACKHEADER PH WITH (NOLOCK)  
   JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno AND PIDET.SKU = PDET.SKU     --CS07    
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey  
   WHERE PDET.Labelno = @c_LabelNo  
  
   --SET @n_prncopy = 1  
   WHILE @n_prncopy > 1  
   BEGIN  
     
   INSERT INTO #TempKidsRUSCartonLBL  
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
              SpecialMark           --col34   --WL01   
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
              SpecialMark           --col34   --WL01   
      FROM   #TempKidsRUSCartonLBL  
  
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
              SpecialMark           --col34   --WL01            
      FROM   #TempKidsRUSCartonLBL  
   END  
  
   DROP TABLE #TempKidsRUSCartonLBL  
END    

GO