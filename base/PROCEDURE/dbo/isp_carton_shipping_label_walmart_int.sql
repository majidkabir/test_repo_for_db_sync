SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_carton_shipping_label_walmart_Int                     */
/* Creation Date: 14-Sep-2016                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose:  WMS-255 - Carters SZ - Shpping Label change request              */
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
/* 14-Feb-2017  CSCHONG   1.3   WMS-1072 - Revise field logic (CS01)          */
/* 29-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length           */
/* 20-Sep-2019  CSCHONG   1.5  WMS-10392 Performance tunning (CS02)           */
/* 22-Feb-2020  WinSern   1.6  INC1050350 Fix multiple UD04 retrieved (WS01)  */
/* 02-May-2021  CheeMun   1.7  INC1472814 - Revise to fulfill FBR requirement */
/* 21-Oct_2021  SYChua    1.8   JSM-27275 - Add storerkey as BillOfMaterial   */
/*                              condition, for faster performance (SY01)      */
/******************************************************************************/

CREATE PROC [dbo].[isp_carton_shipping_label_walmart_Int] (@c_LabelNo NVARCHAR(20))
AS
SET ANSI_WARNINGS OFF
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
           @c_ExternOrderkey     NVARCHAR(50),  --tlting_ext
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
           @c_SKU                NVARCHAR(20),  --INC1472814
           @c_busr1              NVARCHAR(30) ,
           @n_PQty               INT,
           @n_CntSKU             INT,
           @n_PackQty            INT,
           @n_prncopy            INT,
           @c_skusize            NVARCHAR(50),
           @c_GTIN               NVARCHAR(20),
           @c_ExternOrdKey       NVARCHAR(20),
           @c_GetExternOrdKey    NVARCHAR(20),
           @n_CTNExtOrdkey       INT,
           @c_MCountry           NVARCHAR(30),
           @c_GetMCountry        NVARCHAR(1) ,
           @c_BarcodeGTIN        NVARCHAR(20),
           @c_OHNotes2           NVARCHAR(150),   --(CS01)
           @c_ODNotes2           NVARCHAR(150),   --(CS01)
           @c_ODUdef03           NVARCHAR(50),    --(CS01)
           @n_CntDelimiters      INT,             --(CS01)
           @c_Altsku             NVARCHAR(20),    --(CS01)
           @n_cntBOMSku          INT,              --(CS01)
           @n_cntRow             INT               --(CS01)


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
   SET @n_CntSKU = 1
   SET @n_PackQty = 0
   SET @n_prncopy = 0
   SET @c_skusize =''
   SET @c_GTIN = ''
   SET @c_MCountry = ''
   SET @c_GetMCountry = 'N'
   SET @c_BarcodeGTIN = ''

   CREATE TABLE #TempWalmartIntCartonLBL
   (
      FromAdd            NVARCHAR(250) NULL,
      ToAdd              NVARCHAR(250) NULL,
      ShipAdd            NVARCHAR(250) NULL,
      ExternOrderkey     NVARCHAR(50) NULL,        --(CS02)
      EffectiveDate      DATETIME,
      --CartonType         NVARCHAR(10) NULL,
      DCNo               NVARCHAR(10) NULL,
   -- DEPT               NVARCHAR(20) NULL,
   --   PONo               NVARCHAR(20) NULL,
   --   StoreBarcode       NVARCHAR(35) NULL,
      StoreNo            NVARCHAR(5) NULL,
      Labelno     NVARCHAR(20) NULL,
      containerType      NVARCHAR(50) NULL,
      Caseqty            INT,
      SKUSize            NVARCHAR(60) NULL,
      PONo               NVARCHAR(100) NULL,
      ORDHUserDef04      NVARCHAR(20)  NULL,
      GTIN               NVARCHAR(20)  NULL,
      OrdFacility        NVARCHAR(5)  NULL,
      MQty               INT,
      OrdType            NVARCHAR(10) NULL,
      OrdUDef02          NVARCHAR(20) NULL,
      OrdBuyerPo         NVARCHAR(20) NULL

   )



   INSERT INTO #TempWalmartIntCartonLBL
     (
      FromAdd            ,
      ToAdd              ,
      ShipAdd            ,
      ExternOrderkey     ,
      EffectiveDate      ,
      --CartonType         ,
      DCNo               ,
   -- DEPT               ,
   --   PONo               ,
  --    StoreBarcode       ,
      StoreNo            ,
      Labelno            ,
      containerType      ,
      Caseqty            ,
   SKUSize            ,
      PONo               ,
      ORDHUserDef04      ,
      GTIN               ,
      OrdFacility        ,
      MQty               ,
      OrdType            ,
      OrdUDef02          ,
      OrdBuyerPo
     )

SELECT DISTINCT (FAC.descr + CASE WHEN ISNULL(FAC.descr,'') <> '' THEN ' ' END +FAC.address1 + ' ' +
                 FAC.Address2 + ' ' +FAC.Address3 + ' ' +FAC.Address4 + ' ' +
                 FAC.City + ' ' +  FAC.State + ' ' + FAC.Zip + ' ' + FAC.Country) AS COl01,   --(CS01)
         (ORD.M_Company + CHAR(13) +
         ORD.M_Address1 + CHAR(13) +
         ORD.M_Address2 + CHAR(13) +
         ORD.M_Address3 + CHAR(13) +
         ORD.M_city + ',' +
         ORD.M_State + ' ' +
         ORD.M_Zip + ' ' +
         ORD.M_Country ),
         ISNULL(C.notes,''),
         '',
         CASE WHEN ISNULL(ORD.EffectiveDate,'') <> '' THEN ORD.EffectiveDate
         ELSE CAST (ORD.UserDefine06 as datetime) END,
         CASE WHEN ISNULL(ORD.Stop,'') <> '' THEN ORD.Stop
         ELSE ORD.M_ISOCntryCode END ,
          CASE WHEN LEN(ORD.C_Contact2) > 5 THEN LEFT(ORD.C_Contact2,5)  --(CS01)
                  ELSE RIGHT('00000'+ISNULL(ORD.C_Contact2,''),5) END ,  --(CS01)
         PDET.labelno,
         'label type:'+ ISNULL(ORD.ContainerType,''),
         0,
         '',
         (ORD.stop),
         ISNULL(ORDDET.userdefine04,''),'',ORD.Facility,0, '' , ORD.userdefine02, ORD.buyerpo
  FROM PACKHEADER PH WITH (NOLOCK)
  JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
  JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
  JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORD.Orderkey = ORDDET.Orderkey
         AND ORDDET.SKU = PDET.SKU     -- WS01
  JOIN STORER STO WITH (NOLOCK) ON STO.Storerkey = ORD.consigneekey
  JOIN FACILITY FAC WITH (NOLOCK) ON FAC.Facility = ORD.Facility
  LEFT JOIN Packinfo PI WITH (NOLOCK) ON PI.Pickslipno = PDET.Pickslipno
                                 AND PI.Cartonno = PDET.Cartonno
  JOIN SKU  S WITH (NOLOCK)  ON S.SKU = PDET.SKU AND S.storerkey = PDET.Storerkey
  LEFT JOIN PO WITH (NOLOCK) ON PO.Externpokey = ORD.ExternPOKey
 LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.Short=ORD.ContainerType AND C.Storerkey=ORD.StorerKey AND C.listname='CAWMINTLBL'
  WHERE PDET.Labelno = @c_LabelNo



  DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT Labelno
  FROM #TempWalmartIntCartonLBL
  WHERE Labelno = @c_LabelNo

  OPEN C_Lebelno
  FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno

  WHILE (@@FETCH_STATUS <> -1)
  BEGIN

  /*CS05 Start*/
   SET @c_OHNotes2 = ''
   SET @c_ODNotes2 = ''
   SET @n_CntDelimiters = 0
   SET @c_ODUdef03 = ''
   SET @n_cntBOMSku = 1

  SELECT DISTINCT @c_ODNotes2=   OD.Notes2
         --,@n_CntDelimiters = (LEN(OD.Notes2)-LEN(REPLACE(OD.Notes2, '|', '')))
         ,@c_ODUdef03 = RIGHT(RTRIM(OD.UserDefine03),LEN(RTRIM(OD.UserDefine03))-CHARINDEX('-',RTRIM(OD.UserDefine03)))
         ,@c_Storerkey = PD.StorerKey     --SY01
    FROM PICKDETAIL PD (NOLOCK)
    JOIN PackDetail AS PADET WITH (NOLOCK) ON padet.LabelNo=pd.CaseID
    JOIN orderdetail OD (NOLOCK) ON OD.OrderKey = pd.OrderKey AND OD.Sku = PD.Sku
    AND od.OrderLineNumber = pd.OrderLineNumber
    WHERE PD.caseid = @c_LabelNo
  --GROUP BY ORD.notes2,OD.Notes2

    SELECT @n_cntRow = @@ROWCOUNT

   IF @c_ODNotes2 LIKE '%MU-04-%'
   BEGIN
      IF @n_cntRow = 1
      BEGIN


         --SET @c_Altsku = LEFT(RTRIM(@c_ODNotes2),LEN(RTRIM(@c_ODNotes2))-CHARINDEX('|',RTRIM(@c_ODNotes2)))
          SELECT @c_Altsku= CASE WHEN  CHARINDEX('|',@c_ODNotes2,CHARINDEX ('MU-04-',@c_ODNotes2))=0 THEN
                              SUBSTRING (@c_ODNotes2,CHARINDEX ('MU-04-',@c_ODNotes2)+6, LEN(@c_ODNotes2)-CHARINDEX ('MU-04-',@c_ODNotes2))
                              WHEN  CHARINDEX('|',@c_ODNotes2,CHARINDEX ('MU-04-',@c_ODNotes2))>0 THEN
                                SUBSTRING (@c_ODNotes2,CHARINDEX ('MU-04-',@c_ODNotes2)+6,
                                           CHARINDEX('|',@c_ODNotes2,CHARINDEX ('MU-04-',@c_ODNotes2))-CHARINDEX ('MU-04-',@c_ODNotes2)-6)
                              END
      END
      ELSE
      BEGIN
         SET @c_Altsku = ''
      END

        /*CS04 Start*/
        SET @c_BarcodeGTIN = ''
          IF @c_Altsku <> ''
          BEGIN
            SET @c_GTIN =  @c_Altsku--('1' + '0' + substring(@c_Altsku,1,1) + substring(@c_Altsku,2,10))     --CS05   --CS05a
          END

        --IF ISNULL(@c_GTIN,'') <> ''
        --BEGIN
        --   SELECT @c_BarcodeGTIN = [dbo].[fnc_CalcCheckDigit_M10] (@c_GTIN,1)
        --END
        /*CS04 End*/
   END
   ELSE
   BEGIN
      --Assortment_No
      IF ISNULL(@c_ODUdef03,'') <> '' AND (RTRIM(@c_ODUdef03) NOT IN ('P','P-') AND ISNULL(CHARINDEX('-',RTRIM(@c_ODUdef03)),0) > 1)  --INC1472814
      BEGIN
        IF EXISTS (SELECT 1 FROM BillOfMaterial AS bom WITH (NOLOCK)
                   WHERE bom.UDF01 = @c_ODUdef03 AND bom.Storerkey = @c_Storerkey)             --(CS02)   --SY01
        BEGIN --check BOM exists
            SELECT @n_cntBOMSku = COUNT(1)
            FROM BillOfMaterial AS bom WITH (NOLOCK)
            WHERE UDF01 = @c_ODUdef03                          --(CS02)
            AND bom.Storerkey = @c_Storerkey         --SY01

            IF @n_cntBOMSku > 1
            BEGIN
                SELECT DISTINCT @c_Altsku = S.altsku
                FROM Billofmaterial BOM WITH (NOLOCK)
                JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.Sku AND S.Storerkey = BOM.Storerkey         --SY01
                WHERE BOM.UDF01 = @c_ODUdef03                                  --(CS02)
                AND BOM.Storerkey = @c_Storerkey     --SY01

                IF @@ROWCOUNT > 1
                BEGIN
                    SET  @c_Altsku = ''
                END
            END
            ELSE
            BEGIN
                SELECT @c_Altsku = S.altsku
                FROM Billofmaterial BOM WITH (NOLOCK)
                JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.ComponentSku AND S.Storerkey = BOM.Storerkey      --SY01
                WHERE BOM.UDF01 = @c_ODUdef03                                 --(CS02)
                AND BOM.Storerkey = @c_Storerkey     --SY01

                IF @@ROWCOUNT > 1
                BEGIN
                    SET  @c_Altsku = ''
                END

            END
        END --End check BOM exists
        ELSE
        BEGIN --start check BOM not exists
            SET @n_CntSKU = 1

            SELECT @n_CntSKU = COUNT(SKU)
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE Labelno = @c_Getlabelno

            IF @n_CntSKU > 1
            BEGIN
                SET @c_Altsku = ''
            END
            --INC1472814 (START)
            ELSE   --1 SKU in 1 carton
            BEGIN
                SELECT @c_SKU = SKU
                FROM PACKDETAIL WITH (NOLOCK)
                WHERE Labelno = @c_Getlabelno

           IF EXISTS (SELECT 1 FROM BillOfMaterial AS bom WITH (NOLOCK) WHERE SKU = @c_SKU
                      AND bom.Storerkey = @c_Storerkey)   --SY01
                BEGIN --check BOM exists
                    SELECT @n_cntBOMSku = COUNT(1)
                    FROM BillOfMaterial AS bom WITH (NOLOCK)
                    WHERE SKU = @c_SKU
                    AND bom.Storerkey = @c_Storerkey    --SY01

                    IF @n_cntBOMSku > 1
                    BEGIN
                        SELECT TOP 1 @c_Altsku = S.altsku
                        FROM Billofmaterial BOM WITH (NOLOCK)
                        JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.sku AND S.Storerkey = BOM.Storerkey    --SY01
                        WHERE BOM.SKU = @c_SKU
                        AND BOM.Storerkey = @c_Storerkey     --SY01
                    END
                    ELSE
                    BEGIN
                        SELECT @c_Altsku = S.altsku
                        FROM Billofmaterial BOM WITH (NOLOCK)
                        JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.ComponentSku AND S.Storerkey = BOM.Storerkey    --SY01
                        WHERE BOM.SKU = @c_SKU
                        AND BOM.Storerkey = @c_Storerkey     --SY01
                    END
                END
                --INC1472814 (END)
                ELSE    --SKU not in BillOfMaterial.SKU
                BEGIN
                    SELECT @c_Altsku = S.ALTSKU
                    FROM SKU S WITH (NOLOCK)
                    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku
                    WHERE PDET.LabelNo = @c_Getlabelno
                END
            END
        END
      END
      ELSE
      BEGIN --start no assortment no
        SET @n_CntSKU = 1

        SELECT @n_CntSKU = COUNT(SKU)
        FROM PACKDETAIL WITH (NOLOCK)
        WHERE Labelno = @c_Getlabelno

        IF @n_CntSKU > 1
        BEGIN
            SET @c_Altsku = ''
        END
        --INC1472814 (START)
        ELSE   --1 SKU in 1 carton
        BEGIN
            SELECT @c_SKU = SKU
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE Labelno = @c_Getlabelno

            IF EXISTS (SELECT 1 FROM BillOfMaterial AS bom WITH (NOLOCK) WHERE SKU = @c_SKU
                       AND bom.Storerkey = @c_Storerkey)   --SY01
            BEGIN --check BOM exists
               SELECT @n_cntBOMSku = COUNT(1)
               FROM BillOfMaterial AS bom WITH (NOLOCK)
               WHERE SKU = @c_SKU
               AND bom.Storerkey = @c_Storerkey   --SY01

               IF @n_cntBOMSku > 1
               BEGIN
                  SELECT TOP 1 @c_Altsku = S.altsku
                  FROM Billofmaterial BOM WITH (NOLOCK)
                  JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.sku AND S.Storerkey = BOM.Storerkey    --SY01
                  WHERE BOM.SKU = @c_SKU
                  AND BOM.Storerkey = @c_Storerkey     --SY01
               END
               ELSE
               BEGIN
                  SELECT @c_Altsku = S.altsku
                  FROM Billofmaterial BOM WITH (NOLOCK)
                  JOIN SKU S WITH (NOLOCK) ON S.sku = BOM.ComponentSku AND S.Storerkey = BOM.Storerkey    --SY01
                  WHERE BOM.SKU = @c_SKU
                  AND BOM.Storerkey = @c_Storerkey     --SY01
               END
            END
            --INC1472814 (END)
            ELSE    --SKU not in BillOfMaterial.SKU
            BEGIN
               SELECT @c_Altsku = S.ALTSKU
               FROM SKU S WITH (NOLOCK)
               JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku
               WHERE PDET.LabelNo = @c_Getlabelno
            END
         END
      END


      /*CS04 Start*/
      SET @c_BarcodeGTIN = ''

       IF @c_Altsku <> ''
        BEGIN
          SET @c_GTIN =  @c_Altsku--('1' + '0' + substring(@c_Altsku,1,1) + substring(@c_Altsku,2,10))     --CS05   --CS05a
        END

      --IF ISNULL(@c_GTIN,'') <> ''
      --BEGIN
      --   SELECT @c_BarcodeGTIN = [dbo].[fnc_CalcCheckDigit_M10] (@c_GTIN,1)
      --END
      /*CS04 End*/

   END


 /*CS05 End*/

  SELECT @n_CntSKU = COUNT(SKU)
  FROM PACKDETAIL WITH (NOLOCK)
  WHERE Labelno = @c_Getlabelno

  /*CS01 start - -Remove*/
 /* SET @c_Mcountry = ''

    SELECT @c_Mcountry = ORD.M_Country
    FROM PACKHEADER PH WITH (NOLOCK)
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
    JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
    WHERE PDET.Labelno = @c_LabelNo


    SELECT @c_GetMCountry = CASE WHEN ISNULL(CL.Short,'') <> '' THEN 'Y' ELSE 'N' END
    FROM CODELKUP CL WITH (NOLOCK)
    WHERE listname='CAWMGTIN'
    AND CL.Short=@c_MCountry */

  IF @n_CntSKU > 1
  BEGIN

  SET @c_skusize = 'Mixed'
  --SET @c_GTIN = ''

  END
  ELSE
  BEGIN

       SET @c_BarcodeGTIN = ''

       SELECT @c_skusize = ( S.Style + ' ' + S.Color + ' ' + S.Measurement + ' ' + S.Size)
       FROM SKU S WITH (NOLOCK)
       JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Sku = S.Sku
       WHERE PDET.LabelNo = @c_Getlabelno
       /*CS01 --Remove*/
      /*  IF @c_GetMCountry = 'Y'
        BEGIN
            SELECT @c_BarcodeGTIN = ('1' + '00' + substring(S.Altsku,1,1) + substring(S.Altsku,2,10) )--+ [dbo].[fnc_CalcCheckDigit_M10] (s.altsku,1))
            FROM PACKDETAIL PDET WITH (NOLOCK)
            JOIN SKU S WITH (NOLOCK) ON s.sku = PDET.sku AND s.StorerKey = PDET.StorerKey
            WHERE PDET.LabelNo = @c_Getlabelno

            IF ISNULL(@c_BarcodeGTIN,'') <> ''
            BEGIN
              SELECT @c_GTIN = [dbo].[fnc_CalcCheckDigit_M10] (@c_BarcodeGTIN,1)
            END

        END
        ELSE
        BEGIN
            SELECT @c_GTIN = S.Altsku
            FROM PACKDETAIL PDET WITH (NOLOCK)
            JOIN SKU S WITH (NOLOCK) ON s.sku = PDET.sku AND s.StorerKey = PDET.StorerKey
            WHERE PDET.LabelNo = @c_Getlabelno
        END*/
  END

     /*CS01 Start*/
        --SET @c_BarcodeGTIN = ''       --(CS01)

       -- SET @c_BarcodeGTIN =  ('1' + '00' + substring(@c_Altsku,1,1) + substring(@c_Altsku,2,10))      --(CS01)

       -- SELECT @c_GTIN = S.Altsku
       --Remove CS01
       /* SELECT @c_GTIN = ('1' + '0' + substring(S.Altsku,1,1) + substring(S.Altsku,2,10)) --+ [dbo].[fnc_CalcCheckDigit_M10] (s.altsku,1))
        FROM PACKDETAIL PDET WITH (NOLOCK)
        JOIN SKU S WITH (NOLOCK) ON s.sku = PDET.sku AND s.StorerKey = PDET.StorerKey
        WHERE PDET.LabelNo = @c_Getlabelno */

        /*CS01 - Remove*/
      --  IF ISNULL(@c_BarcodeGTIN,'') <> ''
       --BEGIN
         --  SELECT @c_GTIN = [dbo].[fnc_CalcCheckDigit_M10] (@c_BarcodeGTIN,1)
    -- END


     /*CS01 End*/

     SET @c_ExternOrdKey =''
     SET @c_GetExternOrdKey =''
     SET @n_CTNExtOrdkey =1

    SELECT
           @n_CtnExtOrdkey = COUNT(DISTINCT Ord.ExternOrderKey)
    FROM PACKHEADER PH WITH (NOLOCK)
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
    JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
    WHERE PDET.Labelno = @c_LabelNo



   IF @n_CTNExtOrdkey>1
   BEGIN
      SET @c_GetExternOrdKey = 'MULTIPLE'
   END
   ELSE
      BEGIN
         SET @c_GetExternOrdKey =@c_Externordkey
          SELECT TOP 1 @c_GetExternOrdKey = CASE WHEN LEN(ORD.ExternOrderkey) > 10 THEN RIGHT(ORD.ExternOrderkey,10)  --(CS01)
                                            ELSE ORD.ExternOrderkey END                                               --(CS01)
          FROM PACKHEADER PH WITH (NOLOCK)
          JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
          JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno
          JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
          WHERE PDET.Labelno = @c_LabelNo
      END


   UPDATE #TempWalmartIntCartonLBL
   SET SKUSize =@c_skusize
      ,GTIN    =@c_GTIN
      ,ORDHUserDef04 = CASE WHEN @c_skusize ='Mixed' THEN '' ELSE ORDHUserDef04 END
      ,ExternOrderkey = @c_GetExternOrdKey
   Where Labelno=@c_Getlabelno

   SELECT TOP 1 @c_getSKU = MAX(SKU),
                @n_Pqty =  SUM(qty),
                @c_GetStorer = MAX(storerkey)
   FROM PACKDETAIL WITH (NOLOCK)
   WHERE Labelno = @c_Getlabelno

   SELECT @c_busr1 = busr1
   FROM SKU WITH (NOLOCK)
   WHERE Storerkey = @c_GetStorer
   AND SKU = @c_getSKU

   SET @n_PackQty = (@n_Pqty * CONVERT(decimal(6,4),@c_busr1))

   UPDATE #TempWalmartIntCartonLBL
   SET Caseqty = @n_PackQty
      ,Mqty    = @n_PackQty
   Where Labelno=@c_Getlabelno


  FETCH NEXT FROM C_Lebelno INTO @c_Getlabelno
  END

  CLOSE C_Lebelno
  DEALLOCATE C_Lebelno

    SELECT TOP 1 @n_prncopy=ISNULL(ORD.ContainerQty,0)
    FROM PACKHEADER PH WITH (NOLOCK)
    JOIN PACKDETAIL PDET WITH (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno
    JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.Caseid = PDET.Labelno
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
    WHERE PDET.Labelno = @c_LabelNo


WHILE @n_prncopy > 1
BEGIN

INSERT INTO #TempWalmartIntCartonLBL
     (
      FromAdd        ,
      ToAdd          ,
      ShipAdd    ,
      ExternOrderkey ,
      EffectiveDate  ,
      --CartonType   ,
      DCNo           ,
   -- DEPT           ,
    --  PONo         ,
   --   StoreBarcode ,
      StoreNo        ,
      Labelno        ,
      containerType  ,
      Caseqty        ,
      SKUSize        ,
      PONo           ,
      ORDHUserDef04  ,
      GTIN           ,
      OrdFacility    ,
      MQty           ,
      OrdType        ,
      OrdUDef02      ,
      OrdBuyerPo
  )
SELECT TOP 1 FromAdd         ,
             ToAdd           ,
             ShipAdd         ,
             ExternOrderkey  ,
             EffectiveDate   ,
            --CartonType     ,
             DCNo            ,
         -- DEPT             ,
          --  PONo           ,
         --   StoreBarcode   ,
            StoreNo          ,
            Labelno          ,
            containerType    ,
            Caseqty          ,
            SKUSize          ,
    PONo             ,
            ORDHUserDef04    ,
            GTIN             ,
            OrdFacility      ,
            MQty             ,
            OrdType          ,
            OrdUDef02        ,
            OrdBuyerPo
   FROM   #TempWalmartIntCartonLBL


   SET @n_prncopy = @n_prncopy - 1

END

IF @n_prncopy >= 1
BEGIN

   SELECT FromAdd        ,
      ToAdd              ,
      ShipAdd            ,
      ExternOrderkey     ,
      EffectiveDate      ,
      --CartonType       ,
      DCNo               ,
   -- DEPT               ,
    --  PONo             ,
   --   StoreBarcode     ,
      StoreNo            ,
      Labelno            ,
      containerType      ,
      Caseqty            ,
      SKUSize            ,
      PONo               ,
      ORDHUserDef04      ,
      GTIN               ,
      OrdFacility        ,
      MQty               ,
      OrdType            ,
      OrdUDef02          ,
      OrdBuyerPo
   FROM   #TempWalmartIntCartonLBL
END

   DROP TABLE #TempWalmartIntCartonLBL
END

GO