SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPackDetailQCCLabel04_sg_rdt                 */
/* Creation Date: 20-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:  WMS-22048 - TBLSG - QCC Label Sticker for Product Care     */
/*           Copy from isp_GetPackDetailQCCLabel01                      */
/*                                                                      */
/* Input Parameters:  @c_labelno - pickdetail.labelno                   */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_receipt_qcc_label04_sg_rdt         */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from ASN                                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 20-Mar-2023  WLChooi   1.0   DevOps Combine Script                   */
/* 10-Aug-2023  WLChooi   1.1   WMS-23336 - Add new logic (WL01)        */
/************************************************************************/

CREATE   PROC [dbo].[isp_GetPackDetailQCCLabel04_sg_rdt]
(
   @c_labelno    NVARCHAR(20)
 , @c_SKU        NVARCHAR(20)
 , @c_Lottable01 NVARCHAR(18)
 , @c_qty        NVARCHAR(5)
 , @b_Debug      CHAR(1) = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT
         , @c_errmsg   NVARCHAR(255)
         , @b_success  INT
         , @n_err      INT
         , @n_rowid    INT
         , @n_cnt      INT

   DECLARE @c_style           NVARCHAR(30)
         , @c_busr7           NVARCHAR(30)
         , @c_color           NVARCHAR(10)
         , @c_susr1           NVARCHAR(30)
         , @c_susr2           NVARCHAR(30)
         , @c_ivas            NVARCHAR(30)
         , @c_susr5           NVARCHAR(30)
         , @c_countryorigin   NVARCHAR(50)
         , @n_cost            NVARCHAR(30)
         , @c_cocompany       NVARCHAR(45)
         , @c_coaddress1      NVARCHAR(45)
         , @c_grade           NVARCHAR(50)
         , @c_company         NVARCHAR(45)
         , @c_address1        NVARCHAR(45)
         , @c_address2        NVARCHAR(45)
         , @c_model           NVARCHAR(50)
         , @n_count           INT
         , @c_busr4           NVARCHAR(30)
         , @c_busr8           NVARCHAR(30)
         , @c_phone1          NVARCHAR(18)
         , @c_note1           NVARCHAR(215)
         , @c_itemclass       NVARCHAR(10)
         , @c_extendedfield12 NVARCHAR(30)
         , @c_extendedfield03 NVARCHAR(30)
         , @c_company1        NVARCHAR(215)
         , @n_TTLQty          INT
         , @n_qty             INT
         , @c_EANCode         NVARCHAR(15)

   DECLARE @n_from       INT
         , @n_len        INT
         , @n_i          INT
         , @n_RowNo      INT
         , @c_fieldvalue NVARCHAR(45)
         , @c_storerkey  NVARCHAR(15)

   SELECT @n_continue = 1
        , @n_err = 0
        , @b_success = 1
        , @c_errmsg = N''
        , @n_TTLQty = 0
        , @n_count = 1
   SELECT @n_qty = CONVERT(INT, @c_qty)

   IF ISNULL(@n_qty, 0) = 0
   BEGIN
      SELECT @n_qty = 0
   END

   CREATE TABLE #TMP_LABEL
   (
      rowid           INT           IDENTITY(1, 1)
    , style           NVARCHAR(30)  NULL
    , busr7           NVARCHAR(30)  NULL
    , color           NVARCHAR(10)  NULL
    , susr1           NVARCHAR(30)  NULL
    , susr2           NVARCHAR(30)  NULL
    , ivas            NVARCHAR(30)  NULL
    , susr5           NVARCHAR(30)  NULL
    , countryorigin   NVARCHAR(50)  NULL
    , cost            NVARCHAR(30)  NULL
    , cocompany       NVARCHAR(45)  NULL
    , coaddress1      NVARCHAR(45)  NULL
    , grade           NVARCHAR(50)  NULL
    , company         NVARCHAR(45)  NULL
    , address1        NVARCHAR(45)  NULL
    , address2        NVARCHAR(45)  NULL
    , model           NVARCHAR(50)  NULL
    , busr4           NVARCHAR(30)  NULL
    , busr8           NVARCHAR(30)  NULL
    , phone1          NVARCHAR(18)  NULL
    , note1           NVARCHAR(215) NULL
    , itemclass       NVARCHAR(10)  NULL
    , extendedfield12 NVARCHAR(30)  NULL
    , extendedfield03 NVARCHAR(30)  NULL
    , company1        NVARCHAR(215) NULL
    , storerkey       NVARCHAR(15)  NULL
    , EANCode         NVARCHAR(15)  NULL
   )

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOP 1 IDENTITY(INT, 1, 1) AS rowid
                 , (ISNULL(SIF.ExtendedField11, '')) AS Style
                 , ISNULL(SIF.ExtendedField06, '') AS busr7
                 , ISNULL(SIF.ExtendedField06, '') AS Color
                 , '' AS susr1
                 , '' AS susr2
                 , ISNULL(SIF.ExtendedField09, '') AS ivas
                 , ISNULL(SIF.ExtendedField03, '') AS susr5
                 , ISNULL(SIF.ExtendedField07, '') AS Cost
                 , CASE WHEN LOTB.Lottable01 NOT IN ( 'CN', 'CNAP' ) THEN CLC.UDF01
                        ELSE SIF.ExtendedField04 END AS CountryOrigin
                 , CASE WHEN LOTB.Lottable01 IN ( 'CN', 'CNAP' ) THEN COOSTORER.Company
                        ELSE '' END AS COCompany
                 , CASE WHEN LOTB.Lottable01 IN ( 'CN', 'CNAP' ) THEN COOSTORER.Address1
                        ELSE '' END AS COAddress1
                 , CASE WHEN ISNULL(SIF.ExtendedField15, '') <> '' THEN SIF.ExtendedField15
                        ELSE CLQ.Long END AS Grade
                 , STORER.Company
                 , STORER.Address1
                 , STORER.Address2
                 --WL01 S
                 , IIF(
                       ISNULL(SIF.ExtendedField02, '') = 'PC'
                   AND 1 = (  SELECT TOP 1 1
                              FROM CODELKUP C1 WITH (NOLOCK)
                              WHERE C1.LISTNAME = 'TBLPCSKU' AND C1.Storerkey = PD.Storerkey AND C1.Code = PD.SKU)
                   AND 1 = (  SELECT TOP 1 1
                              FROM CODELKUP C2 WITH (NOLOCK)
                              WHERE C2.LISTNAME = 'TBLQCCLBL' AND C2.Storerkey = SKU.StorerKey AND C2.Code = SKU.Size)
                     , SIF.ExtendedField14
                     , (SIF.ExtendedField14 + SPACE(1) + RTRIM(SKU.Size))) AS Model
                 --WL01 E
                 , SKU.Sku
                 , ISNULL(SIF.ExtendedField05, '') AS busr4
                 , '' AS busr8
                 , STORER.Phone1
                 , SIF.ExtendedField21 AS Note1
                 , SIF.ExtendedField02 AS Itemclass
                 , ISNULL(SIF.ExtendedField12, '') AS ExtendedField12
                 , ISNULL(SIF.ExtendedField03, '') AS ExtendedField03
                 , STORER.Notes1 AS Company1
                 , STORER.StorerKey
                 , [dbo].[fnc_CalcCheckDigit_M10](SIF.ExtendedField13, 1) AS EANCode
      INTO #TMP_REC
      FROM PackHeader PH WITH (NOLOCK)
      JOIN PackDetail PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
      JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.Sku)
      LEFT JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
      CROSS APPLY (  SELECT TOP 1 OrdDet.UserDefine04
                                , OrdDet.UserDefine02
                     FROM ORDERDETAIL OrdDet WITH (NOLOCK)
                     WHERE OrdDet.OrderKey = ORD.OrderKey AND OrdDet.Sku = PD.SKU
                     ORDER BY Sku) ORDDET1
      LEFT JOIN SkuInfo SIF WITH (NOLOCK) ON (PD.StorerKey = SIF.Storerkey AND PD.SKU = SIF.Sku)
      LEFT JOIN PICKDETAIL PICKDET WITH (NOLOCK) ON PICKDET.OrderKey = PH.OrderKey AND PICKDET.Sku = PD.SKU
      LEFT JOIN LOTATTRIBUTE LOTB WITH (NOLOCK) ON (PICKDET.Lot = LOTB.Lot AND PICKDET.Sku = LOTB.Sku)
      LEFT JOIN CODELKUP CLC WITH (NOLOCK) ON (CLC.LISTNAME = 'VFCOO' AND CLC.Code = LOTB.Lottable01)
      LEFT JOIN STORER COOSTORER WITH (NOLOCK) ON (   COOSTORER.StorerKey = SIF.ExtendedField04
                                                  AND COOSTORER.ConsigneeFor = ORD.StorerKey)
      LEFT JOIN CODELKUP CLQ WITH (NOLOCK) ON (CLQ.LISTNAME = 'TBLQual' AND SUBSTRING(SKU.Sku, 12, 1) = CLQ.Code)
      JOIN STORER WITH (NOLOCK) ON (ORD.StorerKey = STORER.StorerKey)
      LEFT JOIN STORER CNTRORG WITH (NOLOCK) ON (   SIF.ExtendedField04 = CNTRORG.StorerKey
                                                AND ORD.StorerKey = CNTRORG.ConsigneeFor)
      WHERE SIF.ExtendedField02 IN ( 'FT', 'PC' )
      AND   PD.LabelNo = @c_labelno
      AND   PD.SKU = CASE WHEN ISNULL(RTRIM(@c_SKU), '') <> '' THEN @c_SKU
                          ELSE PD.SKU END
      AND   LOTB.Lottable01 = CASE WHEN ISNULL(RTRIM(@c_Lottable01), '') <> '' THEN @c_Lottable01
                                   ELSE LOTB.Lottable01 END
   END

   DECLARE C_Initial_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT rowid
        , StorerKey
   FROM #TMP_REC
   ORDER BY rowid

   OPEN C_Initial_Record
   FETCH NEXT FROM C_Initial_Record
   INTO @n_RowNo
      , @c_storerkey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_fieldvalue = N''

      SET @n_from = 1
      SET @n_len = 0
      SET @n_i = 1

      WHILE @n_i <= 4
      BEGIN
         SELECT @n_len = PATINDEX('%' + CHAR(13) + CHAR(10) + '%', SUBSTRING(Notes1, @n_from, 1000)) - 1
         FROM STORER WITH (NOLOCK)
         WHERE StorerKey = @c_storerkey

         SELECT @n_len = CASE WHEN @n_len > 0 THEN @n_len
                              ELSE 1000 END

         SELECT @c_fieldvalue = SUBSTRING(Notes1, @n_from, @n_len)
         FROM STORER WITH (NOLOCK)
         WHERE StorerKey = @c_storerkey

         IF @n_i = 1
         BEGIN
            UPDATE #TMP_REC
            SET Company = @c_fieldvalue
            WHERE rowid = @n_RowNo
         END
         ELSE IF @n_i = 2
         BEGIN
            UPDATE #TMP_REC
            SET Address1 = @c_fieldvalue
            WHERE rowid = @n_RowNo
         END
         ELSE IF @n_i = 3
         BEGIN
            UPDATE #TMP_REC
            SET Address2 = @c_fieldvalue
            WHERE rowid = @n_RowNo
         END
         ELSE IF @n_i = 4
         BEGIN
            UPDATE #TMP_REC
            SET Phone1 = @c_fieldvalue
            WHERE rowid = @n_RowNo
         END

         SET @n_from = @n_from + @n_len + 2
         SET @n_i = @n_i + 1
      END

      FETCH NEXT FROM C_Initial_Record
      INTO @n_RowNo
         , @c_storerkey

   END
   CLOSE C_Initial_Record
   DEALLOCATE C_Initial_Record
   SET @c_errmsg = N''
   IF @n_qty <> 0
   BEGIN
      WHILE (@n_count < @n_qty)
      BEGIN
         INSERT INTO #TMP_REC (Style, susr1, susr2, busr7, Color, ivas, susr5, Cost, CountryOrigin, COCompany
                             , COAddress1, Grade, Company, Address1, Address2, Model, Sku, busr4, busr8, Phone1, note1
                             , itemclass, ExtendedField12, ExtendedField03, Company1, StorerKey, EANCode)
         SELECT TOP 1 Style
                    , susr1
                    , susr2
                    , busr7
                    , Color
                    , ivas
                    , susr5
                    , Cost
                    , CountryOrigin
                    , COCompany
                    , COAddress1
                    , Grade
                    , Company
                    , Address1
                    , Address2
                    , Model
                    , Sku
                    , busr4
                    , busr8
                    , Phone1
                    , note1
                    , itemclass
                    , ExtendedField12
                    , ExtendedField03
                    , Company1
                    , StorerKey
                    , EANCode
         FROM #TMP_REC
         ORDER BY rowid

         SELECT @n_count = @n_count + 1
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @n_rowid = 0
      WHILE 1 = 1
      BEGIN
         SET ROWCOUNT 1
         SELECT @n_rowid = rowid
              , @c_style = Style
              , @c_susr1 = susr1
              , @c_susr2 = susr2
              , @c_busr7 = busr7
              , @c_color = Color
              , @c_ivas = ivas
              , @c_susr5 = susr5
              , @n_cost = Cost
              , @c_countryorigin = CountryOrigin
              , @c_cocompany = COCompany
              , @c_coaddress1 = COAddress1
              , @c_grade = Grade
              , @c_company = Company
              , @c_address1 = Address1
              , @c_address2 = Address2
              , @c_model = Model
              , @c_SKU = Sku
              , @c_busr4 = busr4
              , @c_busr8 = busr8
              , @c_phone1 = Phone1
              , @c_note1 = note1
              , @c_itemclass = itemclass
              , @c_extendedfield12 = ExtendedField12
              , @c_extendedfield03 = ExtendedField03
              , @c_company1 = Company1
              , @c_EANCode = EANCode
         FROM #TMP_REC
         WHERE rowid > @n_rowid
         ORDER BY rowid
         SELECT @n_cnt = @@ROWCOUNT
         SET ROWCOUNT 0

         IF @n_cnt = 0
            BREAK

         INSERT #TMP_LABEL (style, busr7, color, susr1, susr2, ivas, susr5, countryorigin, cost, cocompany, coaddress1
                          , grade, company, address1, address2, model, busr4, busr8, phone1, note1, itemclass
                          , extendedfield12, extendedfield03, company1, EANCode)
         VALUES (@c_style, @c_busr7, @c_color, @c_susr1, @c_susr2, @c_ivas, @c_susr5, @c_countryorigin, @n_cost
               , @c_cocompany, @c_coaddress1, @c_grade, @c_company, @c_address1, @c_address2, @c_model, @c_busr4
               , @c_busr8, @c_phone1, @c_note1, @c_itemclass, @c_extendedfield12, @c_extendedfield03, @c_company1
               , @c_EANCode)
      END
   END

   IF @n_continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptQCCLabel01'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      SELECT style
           , busr7
           , color
           , ivas
           , susr5
           , countryorigin
           , cost
           , cocompany
           , coaddress1
           , grade
           , company
           , address1
           , address2
           , model
           , busr4
           , busr8
           , phone1
           , note1
           , itemclass
           , extendedfield12
           , extendedfield03
           , company1
           , EANCode
           , Title01 = N''
      FROM #TMP_LABEL
      WHERE 1 = 2
      RETURN
   END
   ELSE
      SELECT style
           , busr7
           , color
           , susr1
           , susr2
           , ivas
           , SUSR5 = IIF((ISNULL(extendedfield12, '') = '' AND ISNULL(extendedfield03, '') = '')
                      OR (ISNULL(extendedfield12, '') = '-' AND ISNULL(extendedfield03, '') = '-')
                       , ''
                       , CASE WHEN TRIM(itemclass) <> 'FT' THEN TRIM(susr5)
                              ELSE '' END + ' ' + TRIM(extendedfield12))
           , countryorigin
           , cost
           , cocompany
           , coaddress1
           , grade
           , company
           , address1
           , address2
           , model
           , busr4
           , busr8
           , phone1
           , note1
           , itemclass
           , extendedfield12
           , extendedfield03
           , company1
           , rowid
           , EANCode
           --WL01 S
           , Title01 = IIF((ISNULL(extendedfield12, '') = '' AND ISNULL(extendedfield03, '') = '')
                        OR (ISNULL(extendedfield12, '') = '-' AND ISNULL(extendedfield03, '') = '-')
                         , ''
                         , CASE WHEN TRIM(itemclass) = 'FT' THEN N'三包期'
                                ELSE N'生产日期' END + N'/失效日期:')
           --WL01 E
      FROM #TMP_LABEL
      ORDER BY rowid
END

GO