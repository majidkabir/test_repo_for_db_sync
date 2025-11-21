SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_ASN_POSTRECV_002                              */
/* Creation Date:  17-Oct-2023                                             */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-23849 - TH-Create a new WMS Report Of ReportType PostRecv  */
/*                                                                         */
/* Called By: RPT_ASN_POSTRECV_002                                         */
/*                                                                         */
/* GitHub Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 17-Oct-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_ASN_POSTRECV_002] (
      @c_Receiptkey        NVARCHAR(10)
    , @c_ReceiptLineStart  NVARCHAR(5) = ''
    , @c_ReceiptLineEnd    NVARCHAR(5) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1

   SET @c_ReceiptLineStart = IIF(ISNULL(@c_ReceiptLineStart,'') = '', '00001', @c_ReceiptLineStart)
   SET @c_ReceiptLineEnd   = IIF(ISNULL(@c_ReceiptLineEnd,'')   = '', '99999', @c_ReceiptLineEnd)

   SELECT DISTINCT
          RECEIPT.Signatory
        , RECEIPT.WarehouseReference
        , RECEIPTDETAIL.Lottable02
        , CONVERT(NVARCHAR(10), RECEIPTDETAIL.Lottable05, 103) AS Lottable05
        , TotalID = CAST(ISNULL(RECEIPTDETAIL.Userdefine01,'') AS NVARCHAR) + ' / ' + 
          CAST((SELECT COUNT(DISTINCT RD.ToID) FROM RECEIPTDETAIL RD (NOLOCK) WHERE RD.Receiptkey = RECEIPTDETAIL.Receiptkey) AS NVARCHAR)
        , RECEIPTDETAIL.ToID
        , Facility.Userdefine12
        , RECEIPTDETAIL.PutawayLoc
   FROM RECEIPTDETAIL (NOLOCK)
   JOIN RECEIPT (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey
   JOIN Facility (NOLOCK) ON Facility.Facility = RECEIPT.Facility
   WHERE RECEIPTDETAIL.Receiptkey = @c_Receiptkey
   AND RECEIPTDETAIL.ReceiptLineNumber BETWEEN @c_ReceiptLineStart AND @c_ReceiptLineEnd
   ORDER BY RECEIPTDETAIL.ToID

END

GO