SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Receipt11                              */
/* Creation Date: 07-JAN-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: CHONGCS                                                   */
/*                                                                       */
/* Purpose: WMS-18684 - PH_Young Living - CAS Delivery Receipt Report    */
/*                                                                       */
/* Called By: report dw = r_dw_Delivery_Receipt11                        */
/*                                                                       */
/* GitLab Version: 1.2                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author     Ver. Purposes                                 */
/* 06-JAN-2022  CSCHONG    1.0  Devops Scripts Combine                   */
/* 04-FEB-2022  CSCHONG    1.1  WMS-18684 revised field logic (CS01)     */
/* 24-Nov-2022  WLChooi    1.2  WMS-21238 - Add new Logic (WL01)         */
/*************************************************************************/
CREATE PROC [dbo].[isp_Delivery_Receipt11] (  
      @c_Orderkey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_CODSKU         NVARCHAR(20)   = N'COD'
         , @c_ExternOrderkey NVARCHAR(50)   = N''
         , @n_OrderInfo03    DECIMAL(30, 2) = 0.00


   DECLARE @c_moneysymbol  NVARCHAR(20)   = N'₱'
         , @n_balance      DECIMAL(10, 2) = 0.00
         , @n_TTLUnitPrice DECIMAL(10, 2)
         , @n_OIF03        DECIMAL(10, 2) = 0.00
         , @c_OIF03        NVARCHAR(30)   = N''
         , @c_Clkudf01     NVARCHAR(150)  = N''
         , @c_Clkudf02     NVARCHAR(150)  = N''
         , @c_Clkudf03     NVARCHAR(150)  = N''
         , @c_Clkudf04     NVARCHAR(150)  = N''
         , @c_Clkudf05     NVARCHAR(150)  = N''
         , @c_Clknotes2    NVARCHAR(150)  = N''
         , @c_storerkey    NVARCHAR(20)   = N''
         , @c_Reprint      NVARCHAR(1)    = N'N'
         , @c_xdockFlag    NVARCHAR(5)    = N''
         , @c_ShowQR       NVARCHAR(1)    = N'N'   --WL01

   --WL01 S
   DECLARE @T_SKU_ShowQR TABLE ( 
         Storerkey   NVARCHAR(15)  NULL
       , SKU         NVARCHAR(20)  NULL
       , Notes       NVARCHAR(500) NULL
   )

   DECLARE @T_GenQR TABLE ( 
         Descr       NVARCHAR(500)  NULL
       , [URL]       NVARCHAR(1000) NULL
   )
   --WL01 E

   DECLARE @c_OHUDF06     NVARCHAR(30)
         , @c_PrevOHUDF06 NVARCHAR(30)
         , @c_OHUDF02     NVARCHAR(30)
         , @c_ODUDF02     NVARCHAR(30)
         , @c_getclkudf01 NVARCHAR(20)
         , @c_sbusr5      NVARCHAR(30)
         , @c_lott01      NVARCHAR(20)
         , @c_Prvlott01   NVARCHAR(20)
         , @c_sku         NVARCHAR(20)
         , @c_getsku      NVARCHAR(150)
         , @n_odqty       INT
         , @c_sdescr      NVARCHAR(250)
         , @c_getorderkey NVARCHAR(20)
         , @c_getodqty    NVARCHAR(20)
         , @c_getsdescr   NVARCHAR(250)
         , @c_GetOHUDF06  NVARCHAR(30)
         , @c_prefix      NVARCHAR(20)
         , @c_CompSKU     NVARCHAR(200)
         , @c_Combinesku  NVARCHAR(20) = N''
         , @c_skipinsert  NVARCHAR(1)  = N'N'
         , @n_lineno      INT

   DECLARE @b_COD INT = 0

   --IF EXISTS (SELECT TOP 1 1 FROM ORDERDETAIL (NOLOCK)
   --           WHERE OrderKey = @c_Orderkey AND SKU = @c_CODSKU
   --           AND UserDefine02 = 'PN')
   --BEGIN
   --   SET @b_COD = 1 
   --END

   SET @c_prefix = N'(OOS-To Follow)'

   SELECT @c_storerkey = OH.StorerKey
        , @c_xdockFlag = OH.XDockFlag
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.OrderKey = @c_Orderkey

   IF @c_xdockFlag = 'Y'
   BEGIN
      SET @c_Reprint = N'Y'
   END

   CREATE TABLE #TMPBOMSKU
   (
      RowID     INT           IDENTITY(1, 1) PRIMARY KEY
    , StorerKey NVARCHAR(20)  NOT NULL DEFAULT ('')
    , Orderkey  NVARCHAR(20)  NOT NULL DEFAULT ('')
    , SKU       NVARCHAR(20)  NOT NULL DEFAULT ('')
    , CompSKU   NVARCHAR(200) NOT NULL DEFAULT ('')
    , Qty       NVARCHAR(20)  NULL
    , Sdescr    NVARCHAR(200) NULL
   )

   SELECT @c_Clkudf01 = ISNULL(clk.UDF01, '')
        , @c_Clkudf02 = ISNULL(clk.UDF02, '')
        , @c_Clkudf03 = ISNULL(clk.UDF03, '')
        , @c_Clkudf04 = ISNULL(clk.UDF04, '')
        , @c_Clkudf05 = ISNULL(clk.UDF05, '')
        , @c_Clknotes2 = ISNULL(clk.Notes2, '')
   FROM dbo.CODELKUP clk WITH (NOLOCK)
   WHERE clk.LISTNAME = 'YLDefVal' AND clk.Short = 'CR' AND clk.Storerkey = @c_storerkey

   --WL01 S
   INSERT INTO @T_SKU_ShowQR (Storerkey, SKU, Notes)
   SELECT DISTINCT CL.Storerkey, ISNULL(CL.Short,''), ISNULL(CL.Notes,'')
   FROM CODELKUP CL (NOLOCK) 
   WHERE CL.LISTNAME = 'YLCASDRQR' AND CL.Storerkey = @c_storerkey

   INSERT INTO @T_GenQR (Descr, [URL])
   SELECT TOP 1 ISNULL(CL.[Description],''), ISNULL(CL.Long,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'YLCASINVQR' AND CL.Storerkey = @c_storerkey
   --WL01 E

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT od.StorerKey AS storerkey
        , od.OrderKey AS orderkey
        , od.UserDefine06 AS ODUDF06
        , od.Sku AS sku
        , (od.QtyAllocated + od.QtyPicked + od.ShippedQty) AS qty
        , S.DESCR AS sdescr
        , CLK.UDF01
        , S.BUSR5
        , od.Lottable01
        , CAST(od.ExternLineNo AS INT)
        , od.UserDefine02
   FROM ORDERDETAIL od (NOLOCK)
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = od.StorerKey AND S.Sku = od.Sku
   LEFT JOIN CODELKUP CLK WITH (NOLOCK) ON CLK.LISTNAME = 'YLLineType' AND CLK.Code = od.UserDefine02
   WHERE od.StorerKey = 'yleo'
   AND   od.OrderKey = @c_Orderkey
   AND   (ISNULL(CLK.UDF01, '') = 'Y' OR ISNULL(S.BUSR5, '') = 'Y')
   --AND od.Lottable01 = (SELECT TOP 1 odet.sku FROM orderdetail odet (nolock) WHERE odet.UserDefine06 = 'KIT' AND odet.storerkey='yleo' and odet.orderkey='0016883700' )
   --AND od.UserDefine06 = 'KIT' 
   --AND od.Lottable01='546337'
   ORDER BY CAST(od.ExternLineNo AS INT)

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_storerkey
      , @c_getorderkey
      , @c_OHUDF06
      , @c_sku
      , @n_odqty
      , @c_sdescr
      , @c_getclkudf01
      , @c_sbusr5
      , @c_lott01
      , @n_lineno
      , @c_ODUDF02

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_getodqty = N'0'
      SET @c_CompSKU = N''
      SET @c_getsku = @c_sku
      SET @c_getsdescr = @c_sdescr
      SET @c_skipinsert = N'N'
      --SET @c_Combinesku = ''

      IF @n_odqty = 0
      BEGIN
         IF @c_ODUDF02 IN ( 'N', 'PN' )
         BEGIN
            SET @c_getodqty = CAST(@n_odqty AS NVARCHAR(10))
         END
         ELSE
         BEGIN
            SET @c_getodqty = CAST(@n_odqty AS NVARCHAR(10)) + SPACE(1) + @c_prefix
         END
      END
      ELSE
      BEGIN
         SET @c_getodqty = CAST(@n_odqty AS NVARCHAR(10))
      END

      IF @c_ODUDF02 = 'K' AND @n_odqty >= 0
      BEGIN
         SET @c_getodqty = N''
      END

      --   SELECT @c_PrevOHUDF06 '@c_PrevOHUDF06',@c_sku '@c_sku', @c_lott01 '@c_lott01'

      IF UPPER(@c_OHUDF06) = 'KIT' AND @c_sku = @c_lott01
      BEGIN
         --IF @c_sku = @c_lott01
         --BEGIN
         SET @c_Combinesku = @c_sku
      --END       
      END
      --SELECT @c_PrevOHUDF06 '@c_PrevOHUDF06',@n_lineno 'lineno'

      IF @c_PrevOHUDF06 = 'KIT'
      BEGIN

         IF @c_Prvlott01 = @c_lott01 AND @c_Combinesku = @c_lott01
         BEGIN

            SET @c_getodqty = N'NS'
            SET @c_getsku = N''
            SET @c_getsdescr = N''
            SET @c_CompSKU = @c_OHUDF06 + SPACE(2) + CAST(@n_odqty AS NVARCHAR(5)) + SPACE(2) + @c_sku + SPACE(2)
                             + @c_sdescr

            INSERT INTO #TMPBOMSKU (StorerKey, Orderkey, SKU, CompSKU, Qty, Sdescr)
            VALUES (@c_storerkey, @c_getorderkey, @c_getsku, @c_CompSKU, @c_getodqty, @c_getsdescr)

            SET @c_skipinsert = N'Y'
         END
      END
      ELSE
      BEGIN
         -- SELECT @c_Combinesku '@c_Combinesku',@c_lott01 '@c_lott01',@c_Prvlott01 '@c_Prvlott01'
         IF @c_Prvlott01 = @c_lott01 AND ISNULL(@c_Combinesku, '') <> '' AND @c_Combinesku = @c_lott01
         BEGIN

            SET @c_getodqty = N'NS'
            SET @c_getsku = N''
            SET @c_getsdescr = N''
            SET @c_CompSKU = @c_OHUDF06 + SPACE(2) + CAST(@n_odqty AS NVARCHAR(5)) + SPACE(2) + @c_sku + SPACE(2)
                             + @c_sdescr

            INSERT INTO #TMPBOMSKU (StorerKey, Orderkey, SKU, CompSKU, Qty, Sdescr)
            VALUES (@c_storerkey, @c_getorderkey, @c_getsku, @c_CompSKU, @c_getodqty, @c_getsdescr)

            SET @c_skipinsert = N'Y'

         END
      END

      IF @c_skipinsert = 'N'
      BEGIN
         INSERT INTO #TMPBOMSKU (StorerKey, Orderkey, SKU, CompSKU, Qty, Sdescr)
         VALUES (@c_storerkey, @c_getorderkey, @c_getsku, @c_CompSKU, @c_getodqty, @c_getsdescr)
      END

      --WL01 S
      IF EXISTS ( SELECT 1
                  FROM @T_SKU_ShowQR TSSQ
                  WHERE TSSQ.Storerkey = @c_storerkey
                  AND TSSQ.SKU = @c_sku)
      BEGIN
         SET @c_ShowQR = N'Y'
      END
      --WL01 E

      SET @c_PrevOHUDF06 = @c_OHUDF06
      SET @c_Prvlott01 = @c_lott01

      FETCH NEXT FROM CUR_LOOP
      INTO @c_storerkey
         , @c_getorderkey
         , @c_OHUDF06
         , @c_sku
         , @n_odqty
         , @c_sdescr
         , @c_getclkudf01
         , @c_sbusr5
         , @c_lott01
         , @n_lineno
         , @c_ODUDF02
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP


   SELECT OH.ConsigneeKey
        , LTRIM(RTRIM(ISNULL(OH.C_Address1, ''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address2, ''))) + SPACE(1)
          + LTRIM(RTRIM(ISNULL(OH.C_Address3, ''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_Address4, ''))) + SPACE(1)
          + LTRIM(RTRIM(ISNULL(OH.C_City, ''))) + SPACE(1) + LTRIM(RTRIM(ISNULL(OH.C_State, ''))) + SPACE(1)
          + LTRIM(RTRIM(ISNULL(OH.C_Zip, ''))) AS C_Addresses
        , OH.C_vat
        , OH.InvoiceNo
        , OH.ExternOrderKey
        , CASE WHEN BS.CompSKU <> '' THEN ' -' + BS.CompSKU
               ELSE '' END AS compsku
        , BS.SKU AS sku
        , BS.Sdescr AS sdescr
        , RptHeaer = 'DELIVERY RECEIPT'
        , RptCompany = 'YOUNG LIVING PHILIPPINES LLC'
        , RptConsignee = 'YOUNG LIVING PHILIPPINES LLC - PHILIPPINES BRANCH'
        , RptCompanyAddL1 = 'Unit G07, G08 & G09, 12th Floor,'
        , RptCompanyAddL2 = 'Twenty-Five Seven McKinley Building, '
        , RptCompanyAddL3 = '25th Street corner 7th Avenue, Bonifacio Global City, '
        , RptCompanyAddL4 = 'Fort Bonifacio, Taguig City' --CS01
        , RptCompanyRegCode = 'VAT REG TIN: 009-915-795-000'
        , RptBusinessname = 'Other WholeSaling'
        , 'No.' + SPACE(2) + OH.DeliveryNote AS OHDELNote
        , OrdDate = RIGHT('00' + CAST(DAY(OH.OrderDate) AS NVARCHAR(2)), 2) + '-'
                    + LEFT(DATENAME(MONTH, OH.OrderDate), 3) + '-' + CAST(YEAR(OH.OrderDate) AS NVARCHAR(5))
        , BS.Qty AS qty
        , '' AS Balance
        , 'Accreditation No.' + SPACE(1) + @c_Clkudf01 AS Remarks1
        , 'Date of Accreditation:' + SPACE(1) + @c_Clkudf02 AS Remarks2
        , 'Acknowledgement Certificate No.:' + SPACE(1) + @c_Clkudf03 AS Remarks3 --CS01
        , 'Date Issued: ' + SPACE(1) + @c_Clkudf04 AS Remarks4
        , 'Valid Until: ' + SPACE(1) + @c_Clkudf05 AS Remarks4a
        , 'Approved Series No.:' + SPACE(1) + @c_Clknotes2 AS Remarks5
        , 'THIS DOCUMENT IS NOT VALID FOR CLAIM OF INPUT TAX' AS RptFooter1
        , 'THIS INVOICE/RECEIPT SHALL BE VALID FOR FIVE (5) YEARS FROM THE DATE OF THE ' AS RptFooter2
        , 'ACKNOWLEDGEMENT CERTIFICATE.' AS Rptfooter2a
        , CASE WHEN @c_Reprint = 'Y' THEN '** REPRINT **'
               ELSE '' END AS Reprint
        , OH.C_contact1 AS c_contact1
        , CASE WHEN @c_ShowQR = 'Y' THEN T1.Notes ELSE '' END QRDESCR1   --WL01
        , CASE WHEN @c_ShowQR = 'Y' THEN T2.Descr ELSE '' END QRDESCR2   --WL01
        , CASE WHEN @c_ShowQR = 'Y' THEN 'YLEO_QR_001.png' ELSE '' END AS QRCODE1   --WL01
        , CASE WHEN @c_ShowQR = 'Y' THEN T2.[URL] ELSE '' END QRCODE2    --WL01
        , @c_ShowQR AS ShowQR   --WL01
   FROM ORDERS OH (NOLOCK)
   --JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   LEFT JOIN OrderInfo OIF (NOLOCK) ON OIF.OrderKey = OH.OrderKey
   OUTER APPLY (SELECT TOP 1 TSSQ.Notes             --WL01
                FROM @T_SKU_ShowQR TSSQ) AS T1      --WL01
   OUTER APPLY (SELECT TOP 1 TGQ.Descr, TGQ.[URL]   --WL01
                FROM @T_GenQR TGQ) AS T2            --WL01
   JOIN #TMPBOMSKU BS ON BS.StorerKey = OH.StorerKey AND BS.Orderkey = OH.OrderKey
   WHERE OH.OrderKey = @c_Orderkey
   ORDER BY BS.Orderkey
          , BS.RowID

   IF @c_Reprint = 'N'
   BEGIN
      UPDATE [dbo].[ORDERS] WITH (ROWLOCK)
      SET [XDockFlag] = 'Y'
        , TrafficCop = NULL
        , EditDate = GETDATE()
        , EditWho = SUSER_SNAME()
      WHERE [OrderKey] = @c_Orderkey

   END

   IF OBJECT_ID('tempdb..#TMPBOMSKU') IS NOT NULL
      DROP TABLE #TMPBOMSKU

END

GO