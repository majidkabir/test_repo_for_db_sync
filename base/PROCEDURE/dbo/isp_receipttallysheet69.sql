SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_ReceiptTallySheet69                             */
/* Creation Date: 2020-05-08                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-13294 - [JP] Desigual - Tally Sheet - Data Window(New)  */
/*                                                                      */
/* Called By: r_receipt_tallysheet69                                    */
/*                                                                      */
/* PVCS Version: 1.0 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author Ver.   Purposes                                  */
/* 02-NOV-2021  NJOW01 1.0    WMS-18279 Fix SUM qty expected & received */
/* 02-NOV-2021  NJOW01 1.0    DEVOPS combine script                     */
/************************************************************************/

CREATE PROC [dbo].[isp_ReceiptTallySheet69] (
                  @c_ReceiptKeyStart NVARCHAR(10),
                  @c_ReceiptKeyEnd   NVARCHAR(10),
                  @c_StorerkeyStart  NVARCHAR(15),
                  @c_StorerkeyEnd    NVARCHAR(15),
                  @c_UserID          NVARCHAR(50) = '' )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ReceiptKey          NVARCHAR(10),
           @n_Continue            INT = 1,
           @c_SQL                 NVARCHAR(4000),
           @c_Custom1             NVARCHAR(4000),
           @c_Custom2             NVARCHAR(4000)

   CREATE TABLE #TEMP_RECEIPT (
      Receiptkey          NVARCHAR(10),
      ReceiptLineNumber   NVARCHAR(5),
      SKU                 NVARCHAR(20),
      QtyExpected         INT,
      QtyReceived         INT )
   
   CREATE TABLE #TEMP_RECEIPT_RESULT (
      Receiptkey          NVARCHAR(10),
      ExternReceiptkey    NVARCHAR(20) NULL,
      ReceiptDate         Datetime NULL,
      Storerkey           NVARCHAR(15) NULL,
      Userdefine01        NVARCHAR(30) NULL,
      ToID                NVARCHAR(18) NULL,
      SKU                 NVARCHAR(20) NULL,
      ItemClass           NVARCHAR(50) NULL,
      QtyExpected         INT,
      QtyReceived         INT,
      VarianceQty         INT,
      A16                 NVARCHAR(255) NULL,
      A17                 NVARCHAR(255) NULL,
      RUserdefine01       NVARCHAR(50)  NULL,
      A19                 NVARCHAR(255) NULL,
      A20                 NVARCHAR(255) NULL,
      A21                 NVARCHAR(255) NULL )

   INSERT INTO #TEMP_RECEIPT
   SELECT RD.Receiptkey,
          RD.ReceiptLineNumber,
          RD.SKU,
          CASE WHEN RD.Userdefine04 = 'NotInASN' THEN 0 ELSE RD.QtyExpected END,
          CASE WHEN RD.FinalizeFlag = 'N' THEN RD.BeforeReceivedQty ELSE RD.QtyReceived END
   FROM RECEIPTDETAIL RD (NOLOCK)
   WHERE RD.Receiptkey BETWEEN @c_ReceiptKeyStart AND @c_ReceiptKeyEnd
   AND RD.StorerKey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
   ORDER BY RD.Receiptkey, RD.ReceiptLineNumber

   --SELECT * FROM #TEMP_RECEIPT

   SELECT @c_Custom1 = ISNULL(CL.UDF01,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'DSTALLYSHT' AND CL.Code = 'A6'
   AND CL.Storerkey = @c_StorerkeyStart

   SELECT @c_Custom2 = ISNULL(CL.UDF01,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'DSTALLYSHT' AND CL.Code = 'A7'
   AND CL.Storerkey = @c_StorerkeyStart

   IF (ISNULL(@c_Custom1,'') = '')
      SET @c_Custom1 = 'UserDefine01'

   IF (ISNULL(@c_Custom2,'') = '')
      SET @c_Custom2 = 'ToID'

   SET @c_SQL = N'
   INSERT INTO #TEMP_RECEIPT_RESULT
   SELECT R.Receiptkey
        , R.ExternReceiptkey
        , R.ReceiptDate
        , R.Storerkey
        , RD. ' + @c_Custom1 + ' AS UserDefine01
        , RD. ' + @c_Custom2 + ' AS ToID
        , RD.SKU
        , ISNULL(CL.Long,'''') AS ItemClass
        , SUM(t.QtyExpected) AS QtyExpected
        , SUM(t.QtyReceived) AS QtyReceived
        , SUM(t.QtyReceived) - SUM(t.QtyExpected) AS VarianceQty
        , (SELECT ISNULL(CL.Long,'''') FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND CL.Code = ''A16'') AS A16
        , (SELECT ISNULL(CL.Long,'''') FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND CL.Code = ''A17'') AS A17
        , R.UserDefine01 AS RUserDefine01
        , (SELECT ISNULL(CL.Long,'''') FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND CL.Code = ''A19'') AS A19
        , (SELECT ISNULL(CL.Long,'''') FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND CL.Code = ''A20'') AS A20
        , (SELECT ISNULL(CL.Long,'''') FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND CL.Code = ''A21'') AS A21
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   JOIN SKU S (NOLOCK) ON S.StorerKey = R.StorerKey AND S.SKU = RD.SKU
   JOIN #TEMP_RECEIPT t ON t.Receiptkey = R.Receiptkey AND t.SKU = RD.SKU AND T.ReceiptLineNumber = RD.ReceiptLineNumber
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = ''DSTALLYSHT'' AND CL.Storerkey = R.Storerkey AND S.SKUGROUP = CL.Short
   GROUP BY R.Receiptkey
          , R.ExternReceiptkey
          , R.ReceiptDate
          , R.Storerkey
          , RD.SKU
          , ISNULL(CL.Long,'''')
          , R.UserDefine01
          , RD.Userdefine04
          , RD. ' + @c_Custom1 +'
          , RD. ' + @c_Custom2 +'
   ORDER BY R.ReceiptKey '

   EXEC sp_executesql @c_SQL 

   SELECT Receiptkey
        , ExternReceiptkey
        , ReceiptDate
        , Storerkey
        , UserDefine01
        , ToID
        , SKU
        , ItemClass
        , QtyExpected
        , QtyReceived
        , VarianceQty
        , A16
        , A17
        , RUserDefine01
        , A19
        , A20
        , A21
   FROM #TEMP_RECEIPT_RESULT 
   ORDER BY Receiptkey, UserDefine01
END

GO