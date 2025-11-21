SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                  
/* Store Procedure: isp_Packing_List_20_multi_rdt                             */                  
/* Creation Date: 13-DEC-2017                                                 */                  
/* Copyright: IDS                                                             */                  
/* Written by: WLCHOOI                                                        */                  
/*                                                                            */                  
/* Purpose: WMS-3600 - Under Armour ECOM packing list report for multi orders */      
/*                                                                            */                  
/*                                                                            */                  
/* Called By:  r_dw_packing_list_20_multi_rdt                                 */                  
/*                                                                            */                  
/* PVCS Version: 1.6                                                          */                  
/*                                                                            */                  
/* Version: 1.0                                                               */                  
/*                                                                            */                  
/* Data Modifications:                                                        */                  
/*                                                                            */                  
/* Updates:                                                                   */                  
/* Date         Author    Ver.  Purposes                                      */    
/* 2018-03-13   CSCHONG   1.0   WMS-4206 - revised field logic (CS01a)        */    
/* 2018-06-06   Wendy     1.1   Change for ECOM Packing(WWANG01)              */    
/* 2018-12-20   TLTING01  1.2   MISSING nolock                                */    
/* 2019-01-24   WLCHOOI   1.3   WMS-7761 - Add new sorting condition (WL01)   */   
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length           */   
/* 02-Apr-2019  WLCHOOI   1.5   WMS-7761 - Revise logic (WL01)                */
/* 12-May-2021  WLChooi   1.6   WMS-17035 - Add new logic for QRCode (WL02)   */
/******************************************************************************/         
      
CREATE PROC [dbo].[isp_Packing_List_20_multi_rdt]                 
       (@c_Orderkey NVARCHAR(10),    
        @c_labelno  NVARCHAR(20))                  
AS                
BEGIN                
   SET NOCOUNT ON                
   SET ANSI_WARNINGS OFF                
   SET QUOTED_IDENTIFIER OFF                
   SET CONCAT_NULL_YIELDS_NULL OFF        
      
   DECLARE @c_MCompany        NVARCHAR(45)      
         , @c_Externorderkey  NVARCHAR(50)    --tlting_ext  
         , @c_C_Addresses     NVARCHAR(200)       
         , @c_loadkey         NVARCHAR(10)      
         , @c_Userdef03       NVARCHAR(20)      
         , @c_salesman        NVARCHAR(30)      
         , @c_phone1          NVARCHAR(18)    
         , @c_contact1        NVARCHAR(30)      
      
         , @n_TTLQty          INT       
         , @c_shippername     NVARCHAR(45)      
         , @c_Sku             NVARCHAR(20)      
         , @c_Size            NVARCHAR(5)      
         , @c_PickLoc         NVARCHAR(10)     
         , @c_getOrdKey       NVARCHAR(10)     
         , @c_OrdGrp          NVARCHAR(30)               --(CS01)    
         , @c_ChildOrd        NVARCHAR(20)               --(CS01)    
       
         --For 2D barcode    
         ,@c_QRSTRING NVARCHAR(4000)    
         ,@C_APPKEY NVARCHAR(45)    
         ,@c_SignatureOut NVARCHAR(500)    
         ,@c_VB_ErrMsg NVARCHAR(4000)    
         ,@c_UrlOut NVARCHAR(4000)    
         ,@c_OHINVAmt NVARCHAR(100)    
         ,@c_OrdDate NVARCHAR(100)    
         ,@c_Cudf05 NVARCHAR(45)    
    
         --For BASE64 encoding    
         ,@c_OutputString NVARCHAR(4000)    
         ,@c_vbErrMsg   NVARCHAR(4000)    
         ,@c_UrlPrefix   NVARCHAR(4000)    
    
         ,@c_isLoadKey NVARCHAR(1)    
         ,@c_isBatchNo NVARCHAR(1)    
         ,@c_isOrdKey  NVARCHAR(1)    
         ,@n_ErrMsg NVARCHAR(200)   
         
   --WL02 S
   DECLARE @c_UDF02          NVARCHAR(500) = ''
         , @c_UDF01          NVARCHAR(500) = ''
         , @c_Storerkey      NVARCHAR(15)  = ''
         , @c_UserDefine03   NVARCHAR(50)  = ''
   --WL02 E 
    
   SET @c_isOrdKey = '0'     
   SET @c_isLoadKey = '0'    
   SET @c_isBatchNo = '0'    
   SET @c_getOrdKey = ''    
   SET @n_ErrMsg = 'Error! Value entered by user is found among LoadKey, BatchNo and OrderKey'    
    
   --WWANG01    
   IF LEFT(@c_OrderKey, 1) = 'P'    
   BEGIN    
      SELECT @c_OrderKey = OrderKey    
      FROM PICKHEADER WITH(NOLOCK)    
      WHERE PickHeaderKey = @c_OrderKey    
   END    
   --WWANG01 
      
   CREATE TABLE #MULTIPACKLIST20      
         ( c_company       NVARCHAR(45)  NULL    
         , c_Contact1      NVARCHAR(30)  NULL     
         , C_Addresses     NVARCHAR(200) NULL    
         , c_Phone1        NVARCHAR(18)  NULL    
         , c_Phone2        NVARCHAR(18)  NULL    
         , c_zip           NVARCHAR(18)  NULL    
         , MCompany        NVARCHAR(45)  NULL     
         , Externorderkey  NVARCHAR(50)  NULL   --tlting_ext  
         , PickLOC         NVARCHAR(10)  NULL    
         , Style           NVARCHAR(20)  NULL    
         , SKUColor        NVARCHAR(10)  NULL     
         , SKUSize         NVARCHAR(10)  NULL       
         , ORDUdef01       NVARCHAR(120) NULL          --(CS05)    
         , ORDDETUDef01    NVARCHAR(50)  NULL           --(CS04)    
         , SKU             NVARCHAR(20)  NULL    
         , Openqty         INT               
         , UnitPrice       FLOAT    
         , storename       NVARCHAR(60)  NULL    
         , UPC             NVARCHAR(20)  NULL     
         , CUdf02          NVARCHAR(400) NULL     
         , ReturnAddress   NVARCHAR(400) NULL          --(CS02)    
         , OrderKey        NVARCHAR(10)  NULL          --(CS02)    
         , OHNotes2        NVARCHAR(80)  NULL          --(CS05)    
         , PQty            INT   DEFAULT(0)           --(CS05)    
         , OHINVAmt        FLOAT                      --(CS05)    
       --, SAddress1       NVARCHAR(45)  NULL        --(CS01)    
       --, SZip            NVARCHAR(45)  NULL        --(CS01)    
       --, SContact1       NVARCHAR(30)  NULL        --(CS01)     
       --, SPhone1         NVARCHAR(18)  NULL        --(CS01)    
         , Pickslipno    NVARCHAR(45)    
         , DevPosition     NVARCHAR(45)      
         , OrdDate     DATETIME    
         , Cudf05     NVARCHAR(400)     NULL     
         , OriString    NVARCHAR(4000)  NULL    
         , QRCODE     NVARCHAR(4000)    NULL      
         , LocationGroup   NVARCHAR(60) NULL        --WL01    
         , LocLevel        INT                      --WL01    
         , LogicalLocation NVARCHAR(36) NULL        --WL01    
   )      
    
   CREATE TABLE #TEMP_ORDERKEY    
   (     
      OrderKey    NVARCHAR(10)   NOT NULL    
   )    
      
   /*CS01 Start*/    
   CREATE TABLE #TEMP_CHILDORDER    
   (     
      OrderKey    NVARCHAR(10)   NOT NULL    
   )    
      
   /*CS01 End*/    
    
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
              WHERE Orderkey = @c_Orderkey)    
   BEGIN    
      INSERT INTO #TEMP_ORDERKEY (ORDERKEY)    
      VALUES( @c_Orderkey)    
      
      SET @c_isOrdKey = '1'    
   END    
                 
   ELSE IF EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK)    
                   WHERE PickDetail.PickSlipNo = @c_Orderkey)    
   BEGIN    
      INSERT INTO #TEMP_ORDERKEY (ORDERKEY)               
      SELECT DISTINCT OrderKey    
      FROM PickDetail AS PD WITH (NOLOCK)    
      WHERE PD.PickSlipNo=@c_Orderkey    
      SET @c_isBatchNo = '1'    
   END      
   ELSE IF EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK)    
                   WHERE LOADPLANDETAIL.LOADKEY = @c_Orderkey)    
   BEGIN    
      INSERT INTO #TEMP_ORDERKEY (ORDERKEY)    
      SELECT DISTINCT OrderKey    
      FROM LOADPLANDETAIL AS LPD WITH (NOLOCK)    
      WHERE LPD.LOADKEY=@c_Orderkey    
      SET @c_isLoadKey = '1'    
   END    
    
   --Error checking    
   IF(CONCAT(@c_isLoadKey,@c_isOrdkey,@c_isBatchNo))IN(011,101,110,111)    
   BEGIN    
      SELECT @n_ErrMsg    
      GOTO EXIT_SP    
   END    
    
   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Orderkey    
      FROM #TEMP_ORDERKEY    
      ORDER BY Orderkey    
    
   OPEN CUR_ORDKEY    
    
   FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
           
      /*CS01 Start*/      
      SET @c_OrdGrp = ''    
      SET @c_ChildOrd = ''    
          
      SELECT @c_OrdGrp = OH.Ordergroup     
      FROM ORDERS OH WITH (NOLOCK)    
      WHERE Orderkey = @c_getOrdKey      
            
      --   SELECT @c_getOrdKey '@c_getOrdKey',@c_OrdGrp '@c_OrdGrp'    
           
      IF @c_OrdGrp = 'COM_ORDER'    
      BEGIN    
          
    --  INSERT INTO #TEMP_CHILDORDER (OrderKey)    
    --  SELECT DISTINCT ConsoOrderKey FROM ORDERDETAIL (NOLOCK) WHERE OrderKey = @c_getOrdKey       
          
          
    --  SELECT * FROM #TEMP_CHILDORDER    
          
    --DECLARE CUR_CHILDORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
    --  SELECT Orderkey    
    --  FROM #TEMP_CHILDORDER    
    --  ORDER BY Orderkey    
    
    --OPEN CUR_CHILDORDKEY    
    
    --  FETCH NEXT FROM CUR_CHILDORDKEY INTO @c_ChildOrd    
    --WHILE @@FETCH_STATUS = 0    
    --  BEGIN    
    
         INSERT INTO #MULTIPACKLIST20 (c_company           
                                     , c_Contact1            
                                     , C_Addresses          
                                     , c_Phone1      
                                     , c_phone2         
                                     , c_zip            
                                     , MCompany     
                                     , Externorderkey          
                                     , PickLOC                     
                                     , Style     
                                     , SKUColor              
                                     , SKUSize                          
                                     , ORDUdef01          
                                     , ORDDETUDef01         
                                     , SKU                
                                     , openqty                      
                                     , UnitPrice          
                                     , storename          
                                     , UPC        
                                     , CUdf02    
                                     , ReturnAddress          --(CS02)     
                                     , OrderKey               --(CS02)    
                                     , OHNotes2               --(CS05)    
                                     , PQty                    --(CS05)    
                                     , OHINVAmt                --(CS05)    
                                     , Pickslipno    
                                     , DevPosition    
                                     , OrdDate    
                                     , Cudf05    
                                     , OriString    
                                     , LocationGroup   --WL01    
                                     , LocLevel        --WL01    
                                     , LogicalLocation --WL01    
         )                      
--                        , SAddress1             --(CS01)     
--                        , SZip                  --(CS01)    
--                        , SContact1             --(CS01)     
--                        , SPhone1 )             --(CS01)    
         SELECT ISNULL(OH.C_company,''),ISNULL(OH.c_Contact1,''),(OH.C_address1 + OH.C_address2 + OH.C_address3),  --IN00467807    
                ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.c_zip,''),--ISNULL(OH.M_Company,''),    
                --CASE WHEN OH.ordergroup = 'COM_ORDER' THEN ORDDET.userdefine07 ELSE OH.m_company END ,  --(CS05)  --(CS01a)    
                CASE WHEN CHILDORD.ordergroup = 'COM_ORDER' THEN ORDDET.userdefine07 ELSE CHILDORD.m_company END,  --(CS01a)    
                OH.Externorderkey,PD.LOC,S.Style,s.color,s.size,    
                ISNULL(CHILDORD.Userdefine01,''), 
                ISNULL(S.descr,''),        --WL01                    
                --CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN    
                --          S.descr ELSE    
                --          (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,      --(CS05)    
                PD.SKU,PD.qty,ORDDET.UnitPrice,    
--                   CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf01    
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf01 ELSE '' END,            
--                     C2.UDF01,                                           --(CS05)    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.UDF01 ELSE                     --(CS05)    
                C3.UDF01 END,    
                COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),    
--                   ,CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf02    
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf02 ELSE '' END                          
                     -- C2.notes,C2.Notes2,            --CS05    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.notes ELSE                  --(CS05)    
                C3.notes END,    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.Notes2 ELSE                     --(CS05)    
                C3.Notes2 END,    
                OH.OrderKey--STO.Address1,STO.Zip,STO.Contact1,STO.Phone1          --(CS01)  --(CS02)          
                /*CS05 Start*/    
                --, CASE WHEN OH.ordergroup = 'COM_ORDER' THEN OH.notes2 ELSE OH.m_company END           --(CS05)  --(CS01a)      
                ,CASE WHEN CHILDORD.ordergroup = 'COM_ORDER' THEN CHILDORD.notes2 ELSE CHILDORD.m_company END  --(CS01a)    
                ,ISNULL(PD.qty,0) ,CHILDORD.InvoiceAmount       --(CS05)   --(CS01a)    
                ,ISNULL(PD.Pickslipno,'')    
                ,ISNULL(PT.DevicePosition,'')    
                ,CHILDORD.OrderDate, ISNULL(CLR.UDF05,'')     
                ,OriString = 'billNo' + CHILDORD.M_COMPANY + 'totalAmount' + CONVERT(NVARCHAR(100),CHILDORD.InvoiceAmount) + 'billDate' +       
                 CONVERT(VARCHAR(100), CHILDORD.OrderDate, 112) + 'orderSource' +  ISNULL(CLR.UDF05,'')        
                ,ISNULL(LocationGroup,'')      --WL01    
                ,ISNULL(LocLevel,0)            --WL01    
                ,ISNULL(LogicalLocation,'')    --WL01                                                                                                                                                             
         FROM ORDERS OH WITH (NOLOCK)    
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey    
         JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.SKU = ORDDET.SKU AND pd.OrderLineNumber=ORDDET.OrderLineNumber    
         JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey    
         JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey                           --(CS01)    
         LEFT JOIN ORDERS CHILDORD WITH (NOLOCK) ON CHILDORD.OrderKey=ORDDET.ConsoOrderKey       --(CS01a)    
         LEFT JOIN PACKTASK PT WITH (NOLOCK) ON PT.Orderkey = PD.Orderkey    
         LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey = PD.storerkey and u.sku=PD.sku    
         LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'UAEPLOCN' AND C1.Storerkey = OH.Storerkey AND C1.Storerkey='UA'    
         LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'UAEPLCN' AND C2.Storerkey = OH.Storerkey AND C2.Storerkey='UA'    
                                             AND C2.long = OH.UserDefine03     
         /*CS05 start*/    
         LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.Listname = 'UASUBPLAT' AND C3.Storerkey = OH.Storerkey AND C3.Storerkey='UA'    
                                             AND C3.long = OH.UserDefine03 AND C3.UDF02 = OH.C_Company      
         LEFT JOIN CODELKUP CLR (NOLOCK) ON CLR.LISTNAME = 'UAEPLCN' AND CLR.LONG = OH.UserDefine03    
         JOIN LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC  --WL01    
                                       
         /*CS05 End*/                                      
         WHERE PD.Orderkey = @c_getOrdKey    
    
      --FETCH NEXT FROM CUR_CHILDORDKEY INTO @c_ChildOrd    
      --END    
      --CLOSE CUR_CHILDORDKEY    
      --DEALLOCATE CUR_CHILDORDKEY    
           
      END    
      ELSE    
      BEGIN       
         INSERT INTO #MULTIPACKLIST20 (c_company           
                                     , c_Contact1            
                                     , C_Addresses          
                                     , c_Phone1      
                                     , c_phone2         
                                     , c_zip            
                                     , MCompany     
                                     , Externorderkey          
                                     , PickLOC                     
                                     , Style     
                                     , SKUColor              
                                     , SKUSize                          
                                     , ORDUdef01          
                                     , ORDDETUDef01         
                                     , SKU                
                                     , openqty                      
                                     , UnitPrice          
                                     , storename          
                                     , UPC        
                                     , CUdf02    
                                     , ReturnAddress          --(CS02)     
                                     , OrderKey               --(CS02)    
                                     , OHNotes2               --(CS05)    
                                     , PQty                    --(CS05)    
                                     , OHINVAmt                --(CS05)    
                                     , Pickslipno    
                                     , DevPosition    
                                     , OrdDate    
                                     , Cudf05    
                                     , OriString    
                                     , LocationGroup   --WL01    
                                     , LocLevel        --WL01    
                                     , LogicalLocation --WL01    
         )                      
--                        , SAddress1             --(CS01)     
--                        , SZip                  --(CS01)    
--                        , SContact1             --(CS01)     
--                        , SPhone1 )             --(CS01)    
         SELECT ISNULL(OH.C_company,''),ISNULL(OH.c_Contact1,''),(OH.C_address1 + OH.C_address2 + OH.C_address3),  --IN00467807    
                ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Phone2,''),ISNULL(OH.c_zip,''),--ISNULL(OH.M_Company,''),    
                CASE WHEN OH.ordergroup = 'COM_ORDER' THEN ORDDET.userdefine07 ELSE OH.m_company END ,  --(CS05)    
                OH.Externorderkey,PD.LOC,S.Style,s.color,s.size,    
                ISNULL(OH.Userdefine01,''),  
                ISNULL(S.descr,''),        --WL01                     
                --CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN    
                --          S.descr ELSE    
                --          (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,      --(CS05)    
                PD.SKU,PD.qty,ORDDET.UnitPrice,    
--                   CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf01    
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf01 ELSE '' END,            
--                     C2.UDF01,                                                                           --(CS05)    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.UDF01 ELSE                     --(CS05)    
                C3.UDF01 END,    
                COALESCE(S.AltSku,S.RetailSku,S.ManufacturerSku,U.UPC),    
--                   ,CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf02    
--                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf02 ELSE '' END                          
                     -- C2.notes,C2.Notes2,            --CS05    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.notes ELSE                     --(CS05)    
                C3.notes END,    
                CASE WHEN (ISNULL(OH.c_company,'') = '' OR ISNULL(OH.BuyerPO,'') ='' ) THEN C2.Notes2 ELSE                     --(CS05)    
                C3.Notes2 END,    
                OH.OrderKey--STO.Address1,STO.Zip,STO.Contact1,STO.Phone1          --(CS01)  --(CS02)          
                /*CS05 Start*/    
                , CASE WHEN OH.ordergroup = 'COM_ORDER' THEN OH.notes2 ELSE OH.m_company END           --(CS05)        
                ,ISNULL(PD.qty,0) ,OH.InvoiceAmount       --(CS05)    
                ,ISNULL(PD.Pickslipno,'')    
                ,ISNULL(PT.DevicePosition,'')    
                ,OH.OrderDate, ISNULL(CLR.UDF05,'')     
                ,OriString = 'billNo' + OH.M_COMPANY + 'totalAmount' + CONVERT(NVARCHAR(100),OH.InvoiceAmount) + 'billDate' +       
                 CONVERT(VARCHAR(100), OH.OrderDate, 112) + 'orderSource' +  ISNULL(CLR.UDF05,'')        
                ,ISNULL(LocationGroup,'')      --WL01    
                ,ISNULL(LocLevel,0)            --WL01    
                ,ISNULL(LogicalLocation,'')    --WL01                                                                                                                                                                    
         FROM ORDERS OH WITH (NOLOCK)    
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey    
         JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.SKU = ORDDET.SKU AND pd.OrderLineNumber=ORDDET.OrderLineNumber    
         JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey    
         JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey                           --(CS01)    
         LEFT JOIN PACKTASK PT WITH (NOLOCK) ON PT.Orderkey = PD.Orderkey    
         LEFT JOIN UPC U WITH (NOLOCK) ON U.Storerkey = PD.storerkey and u.sku=PD.sku    
         LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'UAEPLOCN' AND C1.Storerkey = OH.Storerkey AND C1.Storerkey='UA'    
         LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'UAEPLCN' AND C2.Storerkey = OH.Storerkey AND C2.Storerkey='UA'    
                                             AND C2.long = OH.UserDefine03     
         /*CS05 start*/    
         LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.Listname = 'UASUBPLAT' AND C3.Storerkey = OH.Storerkey AND C3.Storerkey='UA'    
                                             AND C3.long = OH.UserDefine03 AND C3.UDF02 = OH.C_Company      
         LEFT JOIN CODELKUP CLR (NOLOCK) ON CLR.LISTNAME = 'UAEPLCN' AND CLR.LONG = OH.UserDefine03    
         JOIN LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC  --WL01    
                                             
         /*CS05 End*/                                      
         WHERE PD.Orderkey = @c_getOrdKey    
         --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END    
             
      END   --CS01    
      FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey    
   END    
   CLOSE CUR_ORDKEY    
   DEALLOCATE CUR_ORDKEY    
    
   DECLARE BARCODE_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT ORDERKEY,    
                      ORISTRING,    
                      MCompany,    
                      CONVERT(NVARCHAR(100),OHINVAmt),    
                      CONVERT(VARCHAR(100), OrdDate, 112),    
                      Cudf05    
      FROM #MULTIPACKLIST20    
      ORDER BY ORISTRING    
    
   --tlting01  
   --WL02 S  
   --SET @C_APPKEY = (SELECT UDF02 FROM CODELKUP (NOLOCK) where LISTNAME = 'UAINVOICE') + '&'    
   --SET @c_UrlPrefix = (SELECT UDF01 FROM CODELKUP  (NOLOCK) WHERE LISTNAME = 'UAINVOICE')    
   --WL02 E

   OPEN BARCODE_INFO    
    
   FETCH NEXT FROM BARCODE_INFO INTO @c_getOrdKey,@c_QRSTRING,@c_MCompany,@c_OHINVAmt,@c_OrdDate,@c_Cudf05    
   WHILE @@FETCH_STATUS = 0    
   BEGIN        
      --WL02 S      
      SELECT @c_Storerkey    = Storerkey
           , @c_UserDefine03 = ISNULL(UserDefine03,'')
      FROM ORDERS (NOLOCK)
      WHERE Orderkey = @c_getOrdKey
      
      IF ISNULL(@c_UserDefine03,'') <> ''
      BEGIN
         SELECT @c_UDF02 = ISNULL(CL.UDF02,'')
              , @c_UDF01 = ISNULL(CL.UDF01,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'UAINVOICE' 
         AND CL.Storerkey = @c_Storerkey
         AND CL.Code = @c_UserDefine03
      
         IF ISNULL(@c_UDF02,'') = '' AND ISNULL(@c_UDF01,'') = '' --Use default value (Code = 001)
         BEGIN
            SELECT @c_UDF02 = ISNULL(CL.UDF02,'')
                 , @c_UDF01 = ISNULL(CL.UDF01,'')
            FROM CODELKUP CL (NOLOCK)
            WHERE CL.LISTNAME = 'UAINVOICE' 
            AND CL.Storerkey = @c_Storerkey
            AND CL.Code = '001'
         END
      END
      ELSE   --@c_UserDefine03 = ''
      BEGIN
         SELECT @c_UDF02 = ISNULL(CL.UDF02,'')
              , @c_UDF01 = ISNULL(CL.UDF01,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'UAINVOICE' 
         AND CL.Storerkey = @c_Storerkey
         AND CL.Code = '001'
      END

      SET @C_APPKEY    = LTRIM(RTRIM(@c_UDF02)) + '&'
      SET @c_UrlPrefix = LTRIM(RTRIM(@c_UDF01))
      --WL02 E   

      EXEC MASTER.[dbo].[isp_HMACSHA1Encrypt]       
            @c_QRSTRING,       
            @c_APPKEY,       
            @c_SignatureOut OUTPUT,       
            @c_VB_ErrMsg    OUTPUT    
        
      IF ISNULL(RTRIM(@c_VB_ErrMsg),'') = ''     
      BEGIN    
         SET @c_SignatureOut = LOWER(@c_SignatureOut)    
         EXEC MASTER.[dbo].[isp_Base64Encode]    
               'UTF-8' ,    
               @c_SignatureOut,    
               @c_OutputString OUTPUT,       
               @c_vbErrMsg     OUTPUT    
    
         IF ISNULL(RTRIM(@c_vbErrMsg),'') = ''    
         BEGIN    
            SET @c_UrlOut = @c_UrlPrefix + 'billNo=' + @c_MCompany + '&totalAmount=' + @c_OHINVAmt +    
                            '&billDate=' + @c_OrdDate + '&orderSource=' + @c_Cudf05 + '&sign=' + @c_OutputString    
            UPDATE #MULTIPACKLIST20    
            SET QRCODE = @c_UrlOut    
            WHERE ORDERKEY = @c_getOrdKey    
            AND MCompany = @c_MCompany    
         END    
      END    
    
      FETCH NEXT FROM BARCODE_INFO INTO @c_getOrdKey,@c_QRSTRING,@c_MCompany,@c_OHINVAmt,@c_OrdDate,@c_Cudf05    
   END    
   CLOSE BARCODE_INFO    
   DEALLOCATE BARCODE_INFO    
    
   SELECT c_company           
        , c_Contact1            
        , C_Addresses          
        , c_Phone1      
        , c_phone2         
        , c_zip            
        , MCompany     
        , Externorderkey           
        , ISNULL(PickLOC,'')  as   PickLOC                 
        , ISNULL(Style,'') AS Style    
        , ISNULL(SKUColor,'')  AS SKUColor             
        , ISNULL(SKUSize,'') AS skusize                          
        , ORDUdef01          
        , ORDDETUDef01         
        , ISNULL(SKU,'')  AS SKU              
        , sum(openqty) AS openqty                      
        , UnitPrice          
        , ISNULL(storename,'') AS storename         
        , ISNULL(UPC,'')  AS upc      
        , ISNULL(CUdf02,'') AS cudf02    
        , ISNULL(ReturnAddress,'')  AS ReturnAddress  --(CS02)    
        , OrderKey                                    --(CS02)    
        --,SAddress1,SZip,SContact1,SPhone1          --(CS01)  --(CS02)     
        , OHNotes2,SUM(PQty) AS PQTY                  --(CS05)    
        , OHINVAmt                                   --(CS05)    
        , Pickslipno    
        , DevPosition    
        , Cudf05    
        , QRCODE    
        -- ,ORISTRING    
        --,ISNULL(LocationGroup,'')      --WL01    
        --,ISNULL(LocLevel,0)            --WL01    
        --,ISNULL(LogicalLocation,'')    --WL01         
   FROM #MULTIPACKLIST20      
   GROUP BY c_company           
          , c_Contact1            
          , C_Addresses          
          , c_Phone1      
          , c_phone2         
          , c_zip            
          , MCompany     
          , Externorderkey           
          , ISNULL(PickLOC,'')                
          , ISNULL(Style,'')     
          , ISNULL(SKUColor,'')             
          , ISNULL(SKUSize,'')                          
          , ORDUdef01          
          , ORDDETUDef01         
          , ISNULL(SKU,'')           
          -- , openqty                      
          , UnitPrice          
          , ISNULL(storename,'')          
          , ISNULL(UPC,'')        
          , ISNULL(CUdf02,'')     
          , ISNULL(ReturnAddress,'')                    --(CS02)    
          , OrderKey                                    --(CS02)    
          --,SAddress1,SZip,SContact1,SPhone1          --(CS01)  --(CS02)     
          , OHNotes2    
          , OHINVAmt                                   --(CS05)    
          , Pickslipno    
          , DevPosition    
          , Cudf05    
          , QRCODE    
           --  ,ORISTRING    
          , ISNULL(LocationGroup,'')      --WL01    
          , ISNULL(LocLevel,0)            --WL01    
          , ISNULL(LogicalLocation,'')    --WL01         
   ORDER BY CASE WHEN @c_isLoadKey = '1' THEN Pickslipno ELSE DevPosition END    
           , CASE WHEN @c_isLoadKey = '1' OR @c_isBatchNo = '1' THEN DevPosition ELSE Pickslipno END    
           -- ,PickLoc      
           , ISNULL(LocationGroup,''),ISNULL(LocLevel,0),ISNULL(LogicalLocation,''),ISNULL(PickLOC,'')     --WL01         
               
END    
EXIT_SP:   


GO