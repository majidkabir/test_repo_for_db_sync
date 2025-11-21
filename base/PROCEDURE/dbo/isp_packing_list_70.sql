SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_70                                */
/* Creation Date: 22-OCT-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-10877  CN - PVHQHW Retail Packing List                   */
/*                                                                      */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_70                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2020-09-02   WLChooi   1.1   WMS-14919 - Modify Sorting & Logic(WL01)*/
/* 2020-09-10   WLChooi   1.2   WMS-14919 - Add ISNULL (WL02)           */
/* 2020-10-23   WLChooi   1.3   Bug fix                                 */
/* 2021-02-19   CSCHONG   1.3   WMS-16343 add additional parameter(CS01)*/
/* 2023-09-18   CSCHONG   1.4   WMS-23587 add repoft config (CS02)      */
/************************************************************************/

CREATE   PROC [dbo].[isp_Packing_List_70] (
  @cMBOLKey NVARCHAR( 10)
, @c_consigneekey NVARCHAR(45) = ''   --CS01
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid           int,
           @c_cartontype      NVARCHAR(10),
           @c_prevcartontype  NVARCHAR(10),
           @n_cnt             int


   DECLARE @c_CompanyName        NVARCHAR(45),
           @c_RptName            NVARCHAR(150),
           @c_ST_Secondary       NVARCHAR(15),
           @c_storerkey          NVARCHAR(20),
           @c_GetConsigneekey    NVARCHAR(45),    --CS01
           @c_CCompany           NVARCHAR(45),
           @c_Loadkey            NVARCHAR(20),
           @c_ExtOrderkey        NVARCHAR(50),
           @c_CAddress1          NVARCHAR(45),
           @c_CAddress2          NVARCHAR(45),
           @c_CAddress3          NVARCHAR(45),
           @c_CAddress4          NVARCHAR(45),
           @c_Ccity              NVARCHAR(45),
           @c_Ccountry           NVARCHAR(45),
           @c_mbolkey            NVARCHAR(20),
           @c_salesman           NVARCHAR(30),
           @c_labelno            NVARCHAR(20),
           @c_sku                NVARCHAR(20),
           @c_susr1              NVARCHAR(20),
           @c_style              NVARCHAR(20),
           @c_color              NVARCHAR(10),
           @c_ssize              NVARCHAR(10),
           @c_measurement        NVARCHAR(10),
           @c_Getmeasurement     NVARCHAR(10),
           @c_FullAddress        NVARCHAR(250),
           @n_Pqty               INT,
           @n_cntExtOrdkey       INT,
           @n_cntLoadkey         INT,
           @c_storeCode          NVARCHAR(100),
           @c_GetStyle           NVARCHAR(80),
           @c_GetSize            NVARCHAR(50),
           @c_SHOWCTNBARCODE     NVARCHAR(1) = 'N'         --CS02


   CREATE TABLE #PACKLIST70
         ( ROWID           INT IDENTITY (1,1) NOT NULL
         , companyName     NVARCHAR(30) NULL
         , C_Addresses     NVARCHAR(250) NULL
         , RptName         NVARCHAR(150) NULL
         , StoreCode       NVARCHAR(100) NULL
         , mbolkey         NVARCHAR(20) NULL
         , CCompany        NVARCHAR(45) NULL
         , Externorderkey  NVARCHAR(50) NULL
         , Salesman        NVARCHAR(30)  NULL
         , labelno         NVARCHAR(20) NULL
         , SKUSize         NVARCHAR(50) NULL
         , Scolor          NVARCHAR(10) NULL
         , Style           NVARCHAR(80) NULL
         , SKU             NVARCHAR(20)  NULL
         , PQty            INT   DEFAULT(0)
         , Loadkey         NVARCHAR(20) NULL
         , SHOWCTNBARCODE  NVARCHAR(1)                  --CS02
         )

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CASE WHEN LEFT(ORDERS.Ordergroup,1) = 'R' THEN ISNULL(C.notes,'') ELSE ST.company END AS CompanyName,
   --'Tommy Detail Packing List' as rptname,
      ISNULL(C1.Notes,'') as rptname,
      ORDERS.c_Company AS ord_company,
      ORDERS.c_Address1 AS ord_address1,
      ISNULL(ORDERS.c_Address2,'') AS ord_Address2,
      ISNULL(ORDERS.c_Address3,'') AS ord_Address3,
      ISNULL(ORDERS.c_Address4,'') AS ord_Address4,
      ISNULL(ORDERS.C_City,'') AS ord_City,
      ISNULL(ORDERS.c_country,'') AS ord_ccountry,
      COUNT(DISTINCT ORDERS.ExternOrderkey) AS ExtOrdKey,
      COUNT(DISTINCT ORDERS.loadkey) as loadKey,
      ORDERS.MbolKey AS MBOLKEY,
      ORDERS.Salesman AS Salesman,
      ORDERS.StorerKey,
      PACKDETAIL.labelno AS Labelno,
      ISNULL(SKU.susr1,'') AS susr1,   --WL02
      SKU.[size] AS [ssize],
      SKU.style AS [sstyle],
      sku.color as [scolor],
      SKU.Measurement as measurement ,
      OD.SKU as sku,
      ISNULL(ST.[Secondary],''),   --WL01
      ORDERS.ConsigneeKey,
      --SUM(PACKDETAIL.qty) as Pqty  WL03
      (SELECT SUM(PD.Qty) FROM PACKDETAIL PD (NOLOCK)
       WHERE PD.SKU = OD.SKU
       AND PD.LabelNo = PACKDETAIL.LabelNo
       AND PD.Storerkey = ORDERS.StorerKey)
   FROM ORDERS WITH (NOLOCK) --ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   LEFT JOIN ORDERDETAIL OD (NOLOCK) ON (ORDERS.OrderKey = OD.OrderKey)
   INNER JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
   INNER JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   INNER JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.Loadkey = PACKHEADER.Loadkey)
   INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND
                                           OD.Storerkey = PACKDETAIL.Storerkey AND
                                           OD.Sku = PACKDETAIL.Sku)
   LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = 'PVH-' + ORDERS.consigneekey
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'PVHRPTNAME' AND C.storerkey = ORDERS.storerkey
                                     AND C.code = ORDERS.c_country
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'PVHQHW' and C1.code = ORDERS.Facility
   WHERE ORDERS.MBOLKey = @cMBOLKey
   AND ORDERS.ConsigneeKey = CASE WHEN ISNULL(@c_Consigneekey,'') <> '' THEN @c_Consigneekey ELSE ORDERS.ConsigneeKey END  --CS01
   GROUP by CASE WHEN LEFT(ORDERS.Ordergroup,1) = 'R' THEN ISNULL(C.notes,'') ELSE ST.company END ,
      ORDERS.c_Company ,
      ORDERS.c_Address1 ,
      ISNULL(ORDERS.c_Address2,'') ,
      ISNULL(ORDERS.c_Address3,'') ,
      ISNULL(ORDERS.c_Address4,'') ,
      ISNULL(ORDERS.C_City,''),
      ISNULL(ORDERS.c_country,'') ,
      ORDERS.MbolKey ,
      ORDERS.Salesman ,
      PACKDETAIL.labelno,
      ORDERS.StorerKey,
      ISNULL(SKU.susr1,''),SKU.[size],SKU.style,   --WL02
      sku.color,SKU.Measurement,OD.sku,
      ISNULL(ST.[Secondary],''),   --WL01
      ORDERS.ConsigneeKey
     ,ISNULL(C1.Notes,'')
   ORDER BY ORDERS.MBOLKey, ISNULL(ST.[Secondary],'') + SPACE(2) + ORDERS.ConsigneeKey, PACKDETAIL.labelno, OD.sku, Case When SKU.[size] = 'XS' then '0'   --WL01
            When SKU.[size] = 'S' then '1'
            When SKU.[size] = 'M' then '2'
            When SKU.[size] = 'L' then '3'
            When SKU.[size] = 'XL' then '4'
            When SKU.[size] = 'XL' then '5'
            Else SKU.[size] End

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT INTO @c_CompanyName ,@c_RptName , @c_CCompany , @c_CAddress1, @c_CAddress2 , @c_CAddress3 ,@c_CAddress4 ,@c_Ccity ,
                                   @c_Ccountry , @n_cntExtOrdkey,@n_cntloadkey,@c_mbolkey , @c_salesman , @c_storerkey,@c_labelno ,
                                   @c_susr1 ,@c_ssize ,@c_style , @c_color ,  @c_measurement , @c_sku ,@c_ST_Secondary , @c_GetConsigneekey, @n_Pqty   --CS01

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_ExtOrderkey = ''
      SET @c_Loadkey = ''
      SET @c_Getmeasurement = ''
      SET @c_FullAddress = ''
      SET @c_storeCode = ''
      SET @c_GetStyle = ''
      SET @c_GetSize  = ''

      SET @c_FullAddress = @c_CAddress1 + SPACE(2) +  @c_CAddress2 + SPACE(2) + @c_CAddress3 + SPACE(2) + @c_CAddress4 + SPACE(2) + @c_Ccity + SPACE(2) +  @c_Ccountry
      SET @c_storeCode = ISNULL(@c_ST_Secondary,'') + SPACE(2) + @c_GetConsigneekey   --WL01    --CS01
      SET @c_GetStyle = @c_style + @c_susr1

      IF @n_cntLoadkey = 1
      BEGIN
         SELECT TOP 1 @c_Loadkey = Loadkey
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.MBOLKey = @cMBOLKey
      END
      ELSE
      BEGIN
         SET @c_Loadkey = '*'
      END

      --WL01 S
      /*IF @n_cntExtOrdkey = 1
      BEGIN
         SELECT TOP 1 @c_ExtOrderkey = ExternOrderKey
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.MBOLKey = @cMBOLKey
      END
      ELSE
      BEGIN
         SET @c_ExtOrderkey = '*'
      END*/

      SELECT @c_ExtOrderkey = MIN(ExternOrderKey)
      FROM ORDERS (NOLOCK)
      LEFT JOIN STORER ST (NOLOCK) ON ST.Storerkey = 'PVH-' + ORDERS.consigneekey
      WHERE ORDERS.MBOLKey = @cMBOLKey
      AND ISNULL(ST.[Secondary],'') + SPACE(2) + ORDERS.Consigneekey = @c_storeCode
      --WL01 E

      IF @c_measurement IN ('0','00')
      BEGIN
         SET @c_Getmeasurement =''
      END
      ELSE
      BEGIN
         IF LEFT(@c_measurement,1) = '0'
         BEGIN
            -- SELECT @c_Getmeasurement = SUBSTRING(S.dim,2,10)
            --FROM SKU S WITH (NOLOCK)
            --WHERE S.Sku = @c_sku AND S.StorerKey = @c_storerkey
            SET @c_Getmeasurement = SUBSTRING(@c_measurement,2,10)
         END
         ELSE
         BEGIN
            SET @c_Getmeasurement = @c_measurement
         END
      END

      SET @c_GetSize = @c_ssize + @c_Getmeasurement
      --END


     --CS02 S
     SET @c_SHOWCTNBARCODE = 'N'

    --SELECT @c_SHOWCTNBARCODE = ISNULL(CLR.Short,'N')
    --FROM Codelkup CLR (NOLOCK) 
    --WHERE  CLR.Code = @c_Ccountry
    --AND CLR.Listname = 'barcode' AND ISNULL(CLR.Short,'') <> 'N'
    --AND CLR.storerkey = @c_storerkey
    IF EXISTS (SELECT 1 FROM Codelkup CLR (NOLOCK) 
               WHERE  CLR.Code = @c_Ccountry
               AND CLR.Listname = 'barcode' 
               AND CLR.storerkey = @c_storerkey)
    BEGIN
       SET @c_SHOWCTNBARCODE = 'Y'
    END


     --CS02 E

      INSERT INTO #PACKLIST70(companyName
                            , C_Addresses
                            , RptName
                            , StoreCode
                            , mbolkey
                            , CCompany
                            , Externorderkey
                            , Salesman
                            , labelno
                            , SKUSize
                            , Scolor
                            , Style
                            , SKU
                            , PQty
                            , Loadkey
                            , SHOWCTNBARCODE               --CS02
      )
      VALUES (@c_CompanyName,@c_FullAddress,@c_RptName,@c_storeCode,@c_mbolkey,@c_CCompany,@c_ExtOrderkey,@c_salesman,
              @c_labelno,@c_GetSize,@c_color,@c_GetStyle,@c_sku,@n_Pqty,@c_Loadkey,@c_SHOWCTNBARCODE)             --CS02


      FETCH NEXT FROM CUR_RESULT INTO  @c_CompanyName ,@c_RptName , @c_CCompany , @c_CAddress1, @c_CAddress2 , @c_CAddress3 ,@c_CAddress4 ,@c_Ccity ,
                                       @c_Ccountry , @n_cntExtOrdkey,@n_cntloadkey,@c_mbolkey , @c_salesman , @c_storerkey, @c_labelno ,
                                       @c_susr1 ,@c_ssize ,@c_style , @c_color ,  @c_measurement , @c_sku ,@c_ST_Secondary , @c_GetConsigneekey, @n_Pqty     --CS01

   END

   SELECT companyName
        , Externorderkey
        , C_Addresses
        , CCompany
        , RptName
        , StoreCode
        , mbolkey
        , Salesman
        , '(' + substring(labelno,1,2) + ')' + substring(labelno,3,18)  as labelno
        , Scolor
        , Style
        , SKU
        , PQty
        , Loadkey
        , SKUSize
        , SHOWCTNBARCODE                    --CS02
   FROM #PACKLIST70 (nolock)
   ORDER BY ROWID

END

GO