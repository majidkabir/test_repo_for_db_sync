SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_tw_return_list_eat                             */
/* Creation Date: 05-Apr-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22146 - [TW]EAT_ViewReport ReturnList_IDST058_CR        */
/*          Convert from query to SP                                    */
/*                                                                      */
/* Called By: r_dw_tw_return_list_eat                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 05-Apr-2023  WLChooi  1.0  DevOps Combine Script                     */
/* 25-May-2023  WLChooi  1.1  WMS-22146 - Modify column (WL01)          */
/************************************************************************/

CREATE   PROC [dbo].[isp_tw_return_list_eat]
   @c_Storerkey          NVARCHAR(15) = ''
 , @c_RecType            NVARCHAR(10) = ''
 , @dt_EffectiveDateFrom DATETIME
 , @dt_EffectiveDateTo   DATETIME
 , @dt_AddDateFrom       DATETIME
 , @dt_AddDateTo         DATETIME
 , @dt_ReceiptDate_From  DATETIME
 , @dt_ReceiptDate_To    DATETIME
 , @c_Carrierkey         NVARCHAR(50) = ''
 , @c_ReceiptkeyFrom     NVARCHAR(10) = ''
 , @c_ReceiptkeyTo       NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT
         , @n_StartTCnt    INT
         , @n_Err          INT
         , @c_ErrMsg       NVARCHAR(250)
         , @b_Success      INT
         , @c_GetStorerkey NVARCHAR(15)
         , @c_GetSKU       NVARCHAR(20)
         , @c_ComponentSKU NVARCHAR(500)

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = N''
        , @b_Success = 1

   DECLARE @T_TEMP AS TABLE
   (
      Company          NVARCHAR(100)
    , ReceiptKey       NVARCHAR(100)
    , BC               NVARCHAR(100)
    , BARCODE          NVARCHAR(100)
    , ExternReceiptKey NVARCHAR(100)
    , CarrierKey       NVARCHAR(100)
    , CarrierName      NVARCHAR(100)
    , CarrierAddress1  NVARCHAR(100)
    , ReceiptDate      DATETIME
    , AddDate          DATETIME
    , EffectiveDate    DATETIME
    , Sku              NVARCHAR(20)
    , DESCR            NVARCHAR(250)
    , Y                INT
    , SKUGROUP         NVARCHAR(100)
    , ComponentSku     NVARCHAR(500)
    , Qty              INT
    , Q                INT
    , Storerkey        NVARCHAR(15)
    , RetailSKU        NVARCHAR(50)
   )

   INSERT INTO @T_TEMP (Company, ReceiptKey, BC, BARCODE, ExternReceiptKey, CarrierKey, CarrierName, CarrierAddress1
                      , ReceiptDate, AddDate, EffectiveDate, Sku, DESCR, Y, SKUGROUP, ComponentSku, Qty, Q, Storerkey
                      , RetailSKU)
   SELECT STORER.Company
        , RH.ReceiptKey
        , dbo.fn_Encode_IDA_Code128(RTRIM(RH.ReceiptKey)) AS BC
        , dbo.fn_Encode_IDA_Code128(RTRIM(RH.ReceiptKey)) AS BARCODE
        , RH.ExternReceiptKey
        , RH.CarrierKey
        , RH.CarrierName
        , RH.CarrierAddress1
        , RH.ReceiptDate
        , RH.AddDate
        , RH.EffectiveDate
        , RD.Sku
        , SKU.DESCR
        , (SKU.ShelfLife / 365) AS Y   --WL01
        , SKU.SKUGROUP
        , '' --BOM.ComponentSku
        , 0 --BOM.Qty
        , SUM(RD.QtyExpected) AS Q
        , RH.StorerKey
        , ISNULL(TRIM(SKU.RetailSKU),'') AS RetailSKU
   FROM RECEIPT AS RH (NOLOCK)
   JOIN RECEIPTDETAIL AS RD (NOLOCK) ON RH.ReceiptKey = RD.ReceiptKey
   JOIN STORER ON STORER.StorerKey = RH.StorerKey AND STORER.type = '1'
   JOIN SKU (NOLOCK) ON RD.StorerKey = SKU.StorerKey AND RD.Sku = SKU.Sku
   --LEFT JOIN BillOfMaterial AS BOM (NOLOCK) ON RD.StorerKey = BOM.Storerkey AND RD.Sku = BOM.Sku
   WHERE RH.DOCTYPE = 'R'
   AND   RH.StorerKey = @c_Storerkey
   AND   RH.EffectiveDate BETWEEN @dt_EffectiveDateFrom AND @dt_EffectiveDateTo
   AND   RH.AddDate BETWEEN @dt_AddDateFrom AND @dt_AddDateTo
   AND   RH.ReceiptDate BETWEEN @dt_ReceiptDate_From AND @dt_ReceiptDate_To
   AND   RH.CarrierKey = CASE WHEN ISNULL(@c_Carrierkey, '') = '' THEN RH.CarrierKey
                              ELSE @c_Carrierkey END
   AND   RH.ReceiptKey >= CASE WHEN ISNULL(@c_ReceiptkeyFrom, '') = '' THEN RH.ReceiptKey
                               ELSE @c_ReceiptkeyFrom END
   AND   RH.ReceiptKey <= CASE WHEN ISNULL(@c_ReceiptkeyTo, '') = '' THEN RH.ReceiptKey
                               ELSE @c_ReceiptkeyTo END
   AND   RH.RECType = CASE WHEN ISNULL(@c_RecType, '') = '' THEN RH.RECType
                           ELSE @c_RecType END
   GROUP BY STORER.Company
          , RH.ReceiptKey
          , dbo.fn_Encode_IDA_Code128(RTRIM(RH.ReceiptKey))
          , RH.ExternReceiptKey
          , RH.CarrierKey
          , RH.CarrierName
          , RH.CarrierAddress1
          , RH.ReceiptDate
          , RH.AddDate
          , RH.EffectiveDate
          , RD.Sku
          , SKU.DESCR
          , (SKU.ShelfLife / 365)   --WL01
          , SKU.SKUGROUP
          , RH.StorerKey
          , ISNULL(TRIM(SKU.RetailSKU),'')

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT TT.Storerkey
                 , TT.Sku
   FROM @T_TEMP TT

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_GetStorerkey
      , @c_GetSKU

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ComponentSKU = ''

      SELECT @c_ComponentSKU = STUFF((  SELECT '+ ' + TRIM(BOM.ComponentSku) + '*' + CAST(BOM.Qty AS NVARCHAR)
                                        FROM dbo.BillOfMaterial BOM (NOLOCK)
                                        WHERE BOM.Storerkey = @c_GetStorerkey AND BOM.Sku = @c_GetSKU
                                        ORDER BY 1
                                        FOR XML PATH(''))
                                   , 1
                                   , 1
                                   , '')

      IF ISNULL(@c_ComponentSKU,'') <> ''
      BEGIN
         UPDATE @T_TEMP
         SET ComponentSku = @c_ComponentSKU
         WHERE Sku = @c_GetSKU AND Storerkey = @c_GetStorerkey
      END

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetStorerkey
         , @c_GetSKU
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   QUIT_SP:

   SELECT  TT.Company         
         , TT.ReceiptKey      
         , TT.BC              
         , TT.BARCODE         
         , TT.ExternReceiptKey
         , TT.CarrierKey      
         , TT.CarrierName     
         , TT.CarrierAddress1 
         , TT.ReceiptDate     
         , TT.AddDate         
         , TT.EffectiveDate   
         , TT.Sku             
         , REPLACE(TT.DESCR,'+','+ ') AS DESCR    
         , TT.Y               
         , TT.SKUGROUP        
         , TT.ComponentSku    
         , TT.Qty             
         , TT.Q  
         , TT.RetailSKU
   FROM @T_TEMP TT
   ORDER BY TT.ReceiptKey, TT.SKU

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'isp_tw_return_list_eat'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO