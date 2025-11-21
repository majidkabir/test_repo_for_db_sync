SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_Packing_List_113_multi_rdt                            */
/* Creation Date: 13-DEC-2017                                                 */
/* Copyright: IDS                                                             */
/* Written by: MINGLE                                                         */
/*                                                                            */
/* Purpose: WMS-17816 [CN] UA_ECOM PACKING LIST_CR                            */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_packing_list_113_multi_rdt                                */
/*                                                                            */
/* PVCS Version:                                                              */
/*                                                                            */
/* Version: 1.2                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 07-Dec-2021  WLChooi   1.1   DevOps Combine Script                         */
/* 07-Dec-2021  WLChooi   1.1   WMS-18534 - Remove Hardcoded Storerkey (WL01) */
/* 11-Oct-2022  WLChooi   1.2   WMS-20917 - Add new Codelkup (WL02)           */
/******************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_113_multi_rdt]
(
   @c_Orderkey NVARCHAR(10)
 , @c_labelno  NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_MCompany       NVARCHAR(45)
         , @c_Externorderkey NVARCHAR(50)
         , @c_C_Addresses    NVARCHAR(200)
         , @c_loadkey        NVARCHAR(10)
         , @c_Userdef03      NVARCHAR(20)
         , @c_salesman       NVARCHAR(30)
         , @c_phone1         NVARCHAR(18)
         , @c_contact1       NVARCHAR(30)
         , @n_TTLQty         INT
         , @c_shippername    NVARCHAR(45)
         , @c_Sku            NVARCHAR(20)
         , @c_Size           NVARCHAR(5)
         , @c_PickLoc        NVARCHAR(10)
         , @c_getOrdKey      NVARCHAR(10)
         , @c_OrdGrp         NVARCHAR(30)
         , @c_ChildOrd       NVARCHAR(20)

         --For 2D barcode    
         , @c_QRSTRING       NVARCHAR(4000)
         , @C_APPKEY         NVARCHAR(45)
         , @c_SignatureOut   NVARCHAR(500)
         , @c_VB_ErrMsg      NVARCHAR(4000)
         , @c_UrlOut         NVARCHAR(4000)
         , @c_OHINVAmt       NVARCHAR(100)
         , @c_OrdDate        NVARCHAR(100)
         , @c_Cudf05         NVARCHAR(45)

         --For BASE64 encoding    
         , @c_OutputString   NVARCHAR(4000)
         , @c_vbErrMsg       NVARCHAR(4000)
         , @c_UrlPrefix      NVARCHAR(4000)
         , @c_isLoadKey      NVARCHAR(1)
         , @c_isBatchNo      NVARCHAR(1)
         , @c_isOrdKey       NVARCHAR(1)
         , @n_ErrMsg         NVARCHAR(200)

   DECLARE @c_UDF02        NVARCHAR(500) = N''
         , @c_UDF01        NVARCHAR(500) = N''
         , @c_Storerkey    NVARCHAR(15)  = N''
         , @c_UserDefine03 NVARCHAR(50)  = N''

   SET @c_isOrdKey = N'0'
   SET @c_isLoadKey = N'0'
   SET @c_isBatchNo = N'0'
   SET @c_getOrdKey = N''
   SET @n_ErrMsg = N'Error! Value entered by user is found among LoadKey, BatchNo and OrderKey'

   IF LEFT(@c_Orderkey, 1) = 'P'
   BEGIN
      SELECT @c_Orderkey = OrderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE PickHeaderKey = @c_Orderkey
   END

   CREATE TABLE #MULTIPACKLIST20
   (
      c_company       NVARCHAR(45)   NULL
    , c_Contact1      NVARCHAR(30)   NULL
    , C_Addresses     NVARCHAR(200)  NULL
    , c_Phone1        NVARCHAR(18)   NULL
    , c_Phone2        NVARCHAR(18)   NULL
    , c_zip           NVARCHAR(18)   NULL
    , MCompany        NVARCHAR(45)   NULL
    , Externorderkey  NVARCHAR(50)   NULL
    , PickLOC         NVARCHAR(10)   NULL
    , Style           NVARCHAR(20)   NULL
    , SKUColor        NVARCHAR(10)   NULL
    , SKUSize         NVARCHAR(10)   NULL
    , ORDUdef01       NVARCHAR(120)  NULL
    , ORDDETUDef01    NVARCHAR(50)   NULL
    , SKU             NVARCHAR(20)   NULL
    , Openqty         INT
    , UnitPrice       FLOAT
    , storename       NVARCHAR(60)   NULL
    , UPC             NVARCHAR(20)   NULL
    , CUdf02          NVARCHAR(400)  NULL
    , ReturnAddress   NVARCHAR(400)  NULL
    , OrderKey        NVARCHAR(10)   NULL
    , OHNotes2        NVARCHAR(80)   NULL
    , PQty            INT            DEFAULT (0)
    , OHINVAmt        FLOAT
    --, SAddress1       NVARCHAR(45)  NULL            
    --, SZip            NVARCHAR(45)  NULL            
    --, SContact1       NVARCHAR(30)  NULL             
    --, SPhone1         NVARCHAR(18)  NULL            
    , Pickslipno      NVARCHAR(45)
    , DevPosition     NVARCHAR(45)
    , OrdDate         DATETIME
    , Cudf05          NVARCHAR(400)  NULL
    , OriString       NVARCHAR(4000) NULL
    , QRCODE          NVARCHAR(4000) NULL
    , LocationGroup   NVARCHAR(60)   NULL
    , LocLevel        INT
    , LogicalLocation NVARCHAR(36)   NULL
    , SortNo          NVARCHAR(50)   NULL   --WL02
   )

   CREATE TABLE #TEMP_ORDERKEY
   (
      OrderKey NVARCHAR(10) NOT NULL
   )

   CREATE TABLE #TEMP_CHILDORDER
   (
      OrderKey NVARCHAR(10) NOT NULL
   )


   IF EXISTS (  SELECT 1
                FROM ORDERS WITH (NOLOCK)
                WHERE OrderKey = @c_Orderkey)
   BEGIN
      INSERT INTO #TEMP_ORDERKEY (OrderKey)
      VALUES (@c_Orderkey)

      SET @c_isOrdKey = N'1'
   END
   ELSE IF EXISTS (  SELECT 1
                     FROM PICKDETAIL WITH (NOLOCK)
                     WHERE PICKDETAIL.PickSlipNo = @c_Orderkey)
   BEGIN
      INSERT INTO #TEMP_ORDERKEY (OrderKey)
      SELECT DISTINCT OrderKey
      FROM PICKDETAIL AS PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_Orderkey
      SET @c_isBatchNo = N'1'
   END
   ELSE IF EXISTS (  SELECT 1
                     FROM LoadPlanDetail WITH (NOLOCK)
                     WHERE LoadPlanDetail.LoadKey = @c_Orderkey)
   BEGIN
      INSERT INTO #TEMP_ORDERKEY (OrderKey)
      SELECT DISTINCT OrderKey
      FROM LoadPlanDetail AS LPD WITH (NOLOCK)
      WHERE LPD.LoadKey = @c_Orderkey
      SET @c_isLoadKey = N'1'
   END

   --Error checking    
   IF (CONCAT(@c_isLoadKey, @c_isOrdKey, @c_isBatchNo)) IN ( 011, 101, 110, 111 )
   BEGIN
      SELECT @n_ErrMsg
      GOTO EXIT_SP
   END

   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM #TEMP_ORDERKEY
   ORDER BY OrderKey

   OPEN CUR_ORDKEY

   FETCH NEXT FROM CUR_ORDKEY
   INTO @c_getOrdKey
   WHILE @@FETCH_STATUS = 0
   BEGIN

      SET @c_OrdGrp = N''
      SET @c_ChildOrd = N''

      SELECT @c_OrdGrp = OH.OrderGroup
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OrderKey = @c_getOrdKey

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

         INSERT INTO #MULTIPACKLIST20 (c_company, c_Contact1, C_Addresses, c_Phone1, c_Phone2, c_zip, MCompany
                                     , Externorderkey, PickLOC, Style, SKUColor, SKUSize, ORDUdef01, ORDDETUDef01, SKU
                                     , Openqty, UnitPrice, storename, UPC, CUdf02, ReturnAddress, OrderKey, OHNotes2
                                     , PQty, OHINVAmt, Pickslipno, DevPosition, OrdDate, Cudf05, OriString
                                     , LocationGroup, LocLevel, LogicalLocation, SortNo)   --WL02
         --                        , SAddress1                  
         --                        , SZip                      
         --                        , SContact1                  
         --                        , SPhone1 )                 
         SELECT ISNULL(OH.C_Company, '')
              , ISNULL(OH.C_contact1, '')
              , (OH.C_Address1 + OH.C_Address2 + OH.C_Address3)
              , ISNULL(OH.C_Phone1, '')
              , ISNULL(OH.C_Phone2, '')
              , ISNULL(OH.C_Zip, '') --ISNULL(OH.M_Company,''),    
              --CASE WHEN OH.ordergroup = 'COM_ORDER' THEN ORDDET.userdefine07 ELSE OH.m_company END ,        
              , CASE WHEN CHILDORD.OrderGroup = 'COM_ORDER' THEN ORDDET.UserDefine07
                     ELSE CHILDORD.M_Company END
              , OH.ExternOrderKey
              , PD.Loc
              , S.Style
              , S.Color
              , S.Size
              , ISNULL(CHILDORD.UserDefine01, '')
              , ISNULL(S.DESCR, '')
              --CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN    
              --          S.descr ELSE    
              --          (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,          
              , PD.Sku
              , PD.Qty
              , ORDDET.UnitPrice
              --                   CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf01    
              --                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf01 ELSE '' END,            
              --                     C2.UDF01,                                               
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.UDF01
                     ELSE C3.UDF01 END
              , COALESCE(S.ALTSKU, S.RETAILSKU, S.MANUFACTURERSKU, U.UPC)
              --                   ,CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf02    
              --                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf02 ELSE '' END                          
              -- C2.notes,C2.Notes2,            --CS05    
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.Notes
                     ELSE C3.Notes END
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.Notes2
                     ELSE C3.Notes2 END
              , OH.OrderKey --STO.Address1,STO.Zip,STO.Contact1,STO.Phone1                          
              --, CASE WHEN OH.ordergroup = 'COM_ORDER' THEN OH.notes2 ELSE OH.m_company END                  
              , CASE WHEN CHILDORD.OrderGroup = 'COM_ORDER' THEN CHILDORD.Notes2
                     ELSE CHILDORD.M_Company END
              , ISNULL(PD.Qty, 0)
              , CHILDORD.InvoiceAmount
              , ISNULL(PD.PickSlipNo, '')
              , ISNULL(PT.DevicePosition, '')
              , CHILDORD.OrderDate
              , ISNULL(C2.UDF05, '') --WL01     
              , OriString = 'billNo' + CHILDORD.M_Company + 'totalAmount'
                            + CONVERT(NVARCHAR(100), CHILDORD.InvoiceAmount) + 'billDate'
                            + CONVERT(VARCHAR(100), CHILDORD.OrderDate, 112) + 'orderSource' + ISNULL(C2.UDF05, '') --WL01        
              , ISNULL(LocationGroup, '')
              , ISNULL(LocLevel, 0)
              , ISNULL(LogicalLocation, '')
              , ISNULL(C4.Short,'') AS SortNo   --WL02
         FROM ORDERS OH WITH (NOLOCK)
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.OrderKey = OH.OrderKey
         JOIN PICKDETAIL PD WITH (NOLOCK) ON  PD.OrderKey = OH.OrderKey
                                          AND PD.Sku = ORDDET.Sku
                                          AND PD.OrderLineNumber = ORDDET.OrderLineNumber
         JOIN SKU S WITH (NOLOCK) ON  S.Sku = PD.Sku
                                  AND S.StorerKey = PD.Storerkey
         JOIN STORER STO WITH (NOLOCK) ON OH.StorerKey = STO.StorerKey
         LEFT JOIN ORDERS CHILDORD WITH (NOLOCK) ON CHILDORD.OrderKey = ORDDET.ConsoOrderKey
         LEFT JOIN PackTask PT WITH (NOLOCK) ON PT.Orderkey = PD.OrderKey
         LEFT JOIN UPC U WITH (NOLOCK) ON  U.StorerKey = PD.Storerkey
                                       AND U.SKU = PD.Sku
         LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'UAEPLOCN'
                                             AND C1.Storerkey = OH.StorerKey --AND C1.Storerkey='UA'   --WL01      
         LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON  C2.LISTNAME = 'UAEPLCN'
                                             AND C2.Storerkey = OH.StorerKey --AND C2.Storerkey='UA'   --WL01      
                                             AND C2.Long = OH.UserDefine03
         LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON  C3.LISTNAME = 'UASUBPLAT'
                                             AND C3.Storerkey = OH.StorerKey --AND C3.Storerkey='UA'   --WL01      
                                             AND C3.Long = OH.UserDefine03
                                             AND C3.UDF02 = OH.C_Company
         --LEFT JOIN CODELKUP CLR (NOLOCK) ON CLR.LISTNAME = 'UAEPLCN' AND CLR.LONG = OH.UserDefine03   --WL01    
         LEFT JOIN CODELKUP C4 WITH (NOLOCK) ON  C4.LISTNAME = 'WSSORTNO'   --WL02
                                             AND C4.Storerkey = OH.StorerKey    
                                             AND C4.Code = PT.UDF01
         JOIN LOC WITH (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE PD.OrderKey = @c_getOrdKey

      --FETCH NEXT FROM CUR_CHILDORDKEY INTO @c_ChildOrd    
      --END    
      --CLOSE CUR_CHILDORDKEY    
      --DEALLOCATE CUR_CHILDORDKEY    

      END
      ELSE
      BEGIN
         INSERT INTO #MULTIPACKLIST20 (c_company, c_Contact1, C_Addresses, c_Phone1, c_Phone2, c_zip, MCompany
                                     , Externorderkey, PickLOC, Style, SKUColor, SKUSize, ORDUdef01, ORDDETUDef01, SKU
                                     , Openqty, UnitPrice, storename, UPC, CUdf02, ReturnAddress, OrderKey, OHNotes2
                                     , PQty, OHINVAmt, Pickslipno, DevPosition, OrdDate, Cudf05, OriString
                                     , LocationGroup, LocLevel, LogicalLocation, SortNo)   --WL02
         --                        , SAddress1                  
         --                        , SZip                      
         --                        , SContact1                  
         --                        , SPhone1 )                 
         SELECT ISNULL(OH.C_Company, '')
              , ISNULL(OH.C_contact1, '')
              , (OH.C_Address1 + OH.C_Address2 + OH.C_Address3)
              , ISNULL(OH.C_Phone1, '')
              , ISNULL(OH.C_Phone2, '')
              , ISNULL(OH.C_Zip, '') --ISNULL(OH.M_Company,''),    
              , CASE WHEN OH.OrderGroup = 'COM_ORDER' THEN ORDDET.UserDefine07
                     ELSE OH.M_Company END
              , OH.ExternOrderKey
              , PD.Loc
              , S.Style
              , S.Color
              , S.Size
              , ISNULL(OH.UserDefine01, '')
              , ISNULL(S.DESCR, '')
              --CASE WHEN ISNULL(ORDDET.Userdefine01 + ORDDET.Userdefine02,'') = '' THEN    
              --          S.descr ELSE    
              --          (ISNULL(ORDDET.Userdefine01,'')+ ISNULL(ORDDET.Userdefine02,'')) END ,          
              , PD.Sku
              , PD.Qty
              , ORDDET.UnitPrice
              --                   CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf01    
              --                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf01 ELSE '' END,            
              --                     C2.UDF01,                                                                               
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.UDF01
                     ELSE C3.UDF01 END
              , COALESCE(S.ALTSKU, S.RETAILSKU, S.MANUFACTURERSKU, U.UPC)
              --                   ,CASE WHEN OH.UserDefine03 = N'UA官方商城' THEN C1.Udf02    
              --                        WHEN OH.Userdefine03=N'UA天猫官方旗舰店' THEN C2.Udf02 ELSE '' END                          
              -- C2.notes,C2.Notes2,            --CS05    
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.Notes
                     ELSE C3.Notes END
              , CASE WHEN (  ISNULL(OH.C_Company, '') = ''
                        OR   ISNULL(OH.BuyerPO, '') = '') THEN C2.Notes2
                     ELSE C3.Notes2 END
              , OH.OrderKey --STO.Address1,STO.Zip,STO.Contact1,STO.Phone1                          
              , CASE WHEN OH.OrderGroup = 'COM_ORDER' THEN OH.Notes2
                     ELSE OH.M_Company END
              , ISNULL(PD.Qty, 0)
              , OH.InvoiceAmount
              , ISNULL(PD.PickSlipNo, '')
              , ISNULL(PT.DevicePosition, '')
              , OH.OrderDate
              , ISNULL(C2.UDF05, '') --WL01     
              , OriString = 'billNo' + OH.M_Company + 'totalAmount' + CONVERT(NVARCHAR(100), OH.InvoiceAmount)
                            + 'billDate' + CONVERT(VARCHAR(100), OH.OrderDate, 112) + 'orderSource'
                            + ISNULL(C2.UDF05, '') --WL01        
              , ISNULL(LocationGroup, '')
              , ISNULL(LocLevel, 0)
              , ISNULL(LogicalLocation, '')
              , ISNULL(C4.Short,'') AS SortNo   --WL02
         FROM ORDERS OH WITH (NOLOCK)
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.OrderKey = OH.OrderKey
         JOIN PICKDETAIL PD WITH (NOLOCK) ON  PD.OrderKey = OH.OrderKey
                                          AND PD.Sku = ORDDET.Sku
                                          AND PD.OrderLineNumber = ORDDET.OrderLineNumber
         JOIN SKU S WITH (NOLOCK) ON  S.Sku = PD.Sku
                                  AND S.StorerKey = PD.Storerkey
         JOIN STORER STO WITH (NOLOCK) ON OH.StorerKey = STO.StorerKey
         LEFT JOIN PackTask PT WITH (NOLOCK) ON PT.Orderkey = PD.OrderKey
         LEFT JOIN UPC U WITH (NOLOCK) ON  U.StorerKey = PD.Storerkey
                                       AND U.SKU = PD.Sku
         LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'UAEPLOCN'
                                             AND C1.Storerkey = OH.StorerKey --AND C1.Storerkey='UA'   --WL01    
         LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON  C2.LISTNAME = 'UAEPLCN'
                                             AND C2.Storerkey = OH.StorerKey --AND C2.Storerkey='UA'   --WL01       
                                             AND C2.Long = OH.UserDefine03
         LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON  C3.LISTNAME = 'UASUBPLAT'
                                             AND C3.Storerkey = OH.StorerKey --AND C3.Storerkey='UA'   --WL01       
                                             AND C3.Long = OH.UserDefine03
                                             AND C3.UDF02 = OH.C_Company
         --LEFT JOIN CODELKUP CLR (NOLOCK) ON CLR.LISTNAME = 'UAEPLCN' AND CLR.LONG = OH.UserDefine03   --WL01  
         LEFT JOIN CODELKUP C4 WITH (NOLOCK) ON  C4.LISTNAME = 'WSSORTNO'   --WL02
                                             AND C4.Storerkey = OH.StorerKey    
                                             AND C4.Code = PT.UDF01
         JOIN LOC WITH (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE PD.OrderKey = @c_getOrdKey
      --AND PD.Caseid = CASE WHEN ISNULL(@c_labelno,'') <> '' THEN  @c_labelno ELSE PD.Caseid END    

      END
      FETCH NEXT FROM CUR_ORDKEY
      INTO @c_getOrdKey
   END
   CLOSE CUR_ORDKEY
   DEALLOCATE CUR_ORDKEY

   DECLARE BARCODE_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderKey
                 , OriString
                 , MCompany
                 , CONVERT(NVARCHAR(100), OHINVAmt)
                 , CONVERT(VARCHAR(100), OrdDate, 112)
                 , Cudf05
   FROM #MULTIPACKLIST20
   ORDER BY OriString


   --SET @C_APPKEY = (SELECT UDF02 FROM CODELKUP (NOLOCK) where LISTNAME = 'UAINVOICE') + '&'    
   --SET @c_UrlPrefix = (SELECT UDF01 FROM CODELKUP  (NOLOCK) WHERE LISTNAME = 'UAINVOICE')    

   OPEN BARCODE_INFO

   FETCH NEXT FROM BARCODE_INFO
   INTO @c_getOrdKey
      , @c_QRSTRING
      , @c_MCompany
      , @c_OHINVAmt
      , @c_OrdDate
      , @c_Cudf05
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @c_Storerkey = StorerKey
           , @c_UserDefine03 = ISNULL(UserDefine03, '')
      FROM ORDERS (NOLOCK)
      WHERE OrderKey = @c_getOrdKey

      IF ISNULL(@c_UserDefine03, '') <> ''
      BEGIN
         SELECT @c_UDF02 = ISNULL(CL.UDF02, '')
              , @c_UDF01 = ISNULL(CL.UDF01, '')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'UAINVOICE'
         AND   CL.Storerkey = @c_Storerkey
         AND   CL.Code = @c_UserDefine03

         IF  ISNULL(@c_UDF02, '') = ''
         AND ISNULL(@c_UDF01, '') = '' --Use default value (Code = 001)
         BEGIN
            SELECT @c_UDF02 = ISNULL(CL.UDF02, '')
                 , @c_UDF01 = ISNULL(CL.UDF01, '')
            FROM CODELKUP CL (NOLOCK)
            WHERE CL.LISTNAME = 'UAINVOICE'
            AND   CL.Storerkey = @c_Storerkey
            AND   CL.Code = '001'
         END
      END
      ELSE --@c_UserDefine03 = ''
      BEGIN
         SELECT @c_UDF02 = ISNULL(CL.UDF02, '')
              , @c_UDF01 = ISNULL(CL.UDF01, '')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'UAINVOICE'
         AND   CL.Storerkey = @c_Storerkey
         AND   CL.Code = '001'
      END

      SET @C_APPKEY = LTRIM(RTRIM(@c_UDF02)) + N'&'
      SET @c_UrlPrefix = LTRIM(RTRIM(@c_UDF01))

      EXEC master.[dbo].[isp_HMACSHA1Encrypt] @c_QRSTRING
                                            , @C_APPKEY
                                            , @c_SignatureOut OUTPUT
                                            , @c_VB_ErrMsg OUTPUT

      IF ISNULL(RTRIM(@c_VB_ErrMsg), '') = ''
      BEGIN
         SET @c_SignatureOut = LOWER(@c_SignatureOut)
         EXEC master.[dbo].[isp_Base64Encode] 'UTF-8'
                                            , @c_SignatureOut
                                            , @c_OutputString OUTPUT
                                            , @c_vbErrMsg OUTPUT

         IF ISNULL(RTRIM(@c_vbErrMsg), '') = ''
         BEGIN
            SET @c_UrlOut = @c_UrlPrefix + N'billNo=' + @c_MCompany + N'&totalAmount=' + @c_OHINVAmt + N'&billDate='
                            + @c_OrdDate + N'&orderSource=' + @c_Cudf05 + N'&sign=' + @c_OutputString
            UPDATE #MULTIPACKLIST20
            SET QRCODE = @c_UrlOut
            WHERE OrderKey = @c_getOrdKey
            AND   MCompany = @c_MCompany
         END
      END

      FETCH NEXT FROM BARCODE_INFO
      INTO @c_getOrdKey
         , @c_QRSTRING
         , @c_MCompany
         , @c_OHINVAmt
         , @c_OrdDate
         , @c_Cudf05
   END
   CLOSE BARCODE_INFO
   DEALLOCATE BARCODE_INFO

   SELECT c_company
        , c_Contact1
        , C_Addresses
        , c_Phone1
        , c_Phone2
        , c_zip
        , MCompany
        , Externorderkey
        , ISNULL(PickLOC, '') AS PickLOC
        , ISNULL(Style, '') AS Style
        , ISNULL(SKUColor, '') AS SKUColor
        , ISNULL(SKUSize, '') AS skusize
        , ORDUdef01
        , ORDDETUDef01
        , ISNULL(SKU, '') AS SKU
        , SUM(Openqty) AS openqty
        , UnitPrice
        , ISNULL(storename, '') AS storename
        , ISNULL(UPC, '') AS upc
        , ISNULL(CUdf02, '') AS cudf02
        , ISNULL(ReturnAddress, '') AS ReturnAddress
        , OrderKey
        --,SAddress1,SZip,SContact1,SPhone1                 
        , OHNotes2
        , SUM(PQty) AS PQTY
        , OHINVAmt
        , Pickslipno
        , DevPosition
        , Cudf05
        , QRCODE
        , SortNo   --WL02
   -- ,ORISTRING    
   --,ISNULL(LocationGroup,'')          
   --,ISNULL(LocLevel,0)                
   --,ISNULL(LogicalLocation,'')             
   FROM #MULTIPACKLIST20
   GROUP BY c_company
          , c_Contact1
          , C_Addresses
          , c_Phone1
          , c_Phone2
          , c_zip
          , MCompany
          , Externorderkey
          , ISNULL(PickLOC, '')
          , ISNULL(Style, '')
          , ISNULL(SKUColor, '')
          , ISNULL(skusize, '')
          , ORDUdef01
          , ORDDETUDef01
          , ISNULL(SKU, '')
          -- , openqty                      
          , UnitPrice
          , ISNULL(storename, '')
          , ISNULL(upc, '')
          , ISNULL(cudf02, '')
          , ISNULL(ReturnAddress, '')
          , OrderKey
          --,SAddress1,SZip,SContact1,SPhone1                 
          , OHNotes2
          , OHINVAmt
          , Pickslipno
          , DevPosition
          , Cudf05
          , QRCODE
          --  ,ORISTRING    
          , ISNULL(LocationGroup, '')
          , ISNULL(LocLevel, 0)
          , ISNULL(LogicalLocation, '')
          , SortNo   --WL02
   ORDER BY CASE WHEN @c_isLoadKey = '1' THEN Pickslipno
                 ELSE DevPosition END
          , CASE WHEN @c_isLoadKey = '1'
                 OR   @c_isBatchNo = '1' THEN DevPosition
                 ELSE Pickslipno END
          -- ,PickLoc      
          , ISNULL(LocationGroup, '')
          , ISNULL(LocLevel, 0)
          , ISNULL(LogicalLocation, '')
          , ISNULL(PickLOC, '')

END
EXIT_SP:


GO