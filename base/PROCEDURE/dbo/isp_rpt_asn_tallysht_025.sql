SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_RPT_ASN_TALLYSHT_025                                */
/* Creation Date: 12-JAN-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: Pavithra                                                 */
/*                                                                      */
/* Purpose: WMS-21526 -Migrate WMS Report To LogiReport                 */
/*                                                                      */
/* Called By: RPT_ASN_TALLYSHT_025                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 13-Jan-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_TALLYSHT_025]
   @c_Receiptkey NVARCHAR(10)
 , @c_Username   NVARCHAR(250) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT           = 1
         , @n_err             INT           = 0
         , @c_errmsg          NVARCHAR(255) = N''
         , @b_Success         INT           = 1
         , @n_StartTCnt       INT           = @@TRANCOUNT
         , @c_GetReceiptKey   NVARCHAR(10)
         , @c_GetUserDefine03 NVARCHAR(30)
         , @c_GetUserDefine07 DATETIME

   SELECT RECEIPT.StorerKey
        , RECEIPT.Facility
        , RECEIPT.ReceiptKey
        , RECEIPT.RECType
        , RECEIPT.ExternReceiptKey
        , CONVERT(NVARCHAR(10), RECEIPT.AddDate, 101) AS AddDate
        , RECEIPTDETAIL.ExternLineNo
        , SKU.Style
        , SKU.Size
        , LTRIM(RTRIM(RECEIPTDETAIL.UserDefine01)) AS UserDefine01
        , SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp
        , RECEIPTDETAIL.ReceiptLineNumber
        , RECEIPT.UserDefine03
        , ISNULL(RECEIPT.UserDefine07, '1900/01/01') AS UserDefine07
   INTO #TLYSHEET63
   FROM RECEIPT (NOLOCK)
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku
   WHERE (RECEIPT.ReceiptKey = @c_Receiptkey)
   GROUP BY RECEIPT.StorerKey
          , RECEIPT.Facility
          , RECEIPT.ReceiptKey
          , RECEIPT.RECType
          , RECEIPT.ExternReceiptKey
          , CONVERT(NVARCHAR(10), RECEIPT.AddDate, 101)
          , RECEIPTDETAIL.ExternLineNo
          , SKU.Style
          , SKU.Size
          , LTRIM(RTRIM(RECEIPTDETAIL.UserDefine01))
          , RECEIPTDETAIL.ReceiptLineNumber
          , RECEIPT.UserDefine03
          , ISNULL(RECEIPT.UserDefine07, '1900/01/01')
   ORDER BY RECEIPT.ReceiptKey
          , RECEIPTDETAIL.ReceiptLineNumber

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ReceiptKey
                 , UserDefine03
                 , UserDefine07
   FROM #TLYSHEET63

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_GetReceiptKey
      , @c_GetUserDefine03
      , @c_GetUserDefine07
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF LTRIM(RTRIM(ISNULL(@c_GetUserDefine03, ''))) NOT IN ( 'Y', 'N' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
              , @n_err = 90001
         SELECT @c_errmsg = "NSQL" + CONVERT(CHAR(5), @n_err)
                            + ": Please update the value in Receipt.Userdefine03. (isp_RPT_ASN_TALLYSHT_025)" + " ( "
                            + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
      END

      IF ISNULL(@c_GetUserDefine07, '1900/01/01') = '1900/01/01'
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
              , @n_err = 90002
         SELECT @c_errmsg = "NSQL" + CONVERT(CHAR(5), @n_err)
                            + ": Please update the value in Receipt.Userdefine07. (isp_RPT_ASN_TALLYSHT_025)" + " ( "
                            + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
      END

      FETCH NEXT FROM CUR_LOOP
      INTO @c_GetReceiptKey
         , @c_GetUserDefine03
         , @c_GetUserDefine07
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT DISTINCT StorerKey
                    , Facility
                    , ReceiptKey
                    , RECType
                    , ExternReceiptKey
                    , AddDate
                    , ExternLineNo
                    , Style
                    , Size
                    , UserDefine01
                    , QtyExp
                    , ReceiptLineNumber
      FROM #TLYSHEET63
      ORDER BY ReceiptKey
             , ReceiptLineNumber
   END

   IF @n_continue = 3
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_ASN_TALLYSHT_025'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN;
END

GO