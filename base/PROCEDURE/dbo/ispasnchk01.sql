SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: ispASNCHK01                                             */
/* Creation Date: 30-NOV-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15570 - CN_PVH_ReceiptFinalizeValidation_SP_New         */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-08-23  SYCHUA   1.0   Bug Fix: Do not reset errmsg to EMPTY     */
/*                            when errmsg already have value (SY01)     */
/************************************************************************/
CREATE PROC [dbo].[ispASNCHK01]
           @c_ReceiptKey       NVARCHAR(20)
         , @b_Success          INT            OUTPUT
         , @n_Err              INT            OUTPUT
         , @c_ErrMsg           NVARCHAR(255)  OUTPUT
         , @c_ReceiptLineNumber NVARCHAR(5) = ''
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt          INT
         , @n_Continue           INT

         , @c_Facility           NVARCHAR(5)
         , @c_PhysicalFac        NVARCHAR(5)
         , @c_SuggestLoc         NVARCHAR(10)

         , @c_QCLineNo           NVARCHAR(5)
         , @c_hostwhcode         NVARCHAR(20)

         , @c_Storerkey          NVARCHAR(15)
         , @c_Sku                NVARCHAR(20)
         , @c_channel            NVARCHAR(20)
         , @c_FromLoc            NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)
         , @n_PABookingKey       INT

         , @c_UserName           NVARCHAR(18)
         , @c_Maxline            NVARCHAR(10)
         , @c_GetStorerkey       NVARCHAR(20)

         , @c_lineErr            NVARCHAR(1)
         , @c_SetErrMsg          NVARCHAR(255)
         , @c_GetErrMsg          NVARCHAR(255)

         , @n_BFREVQTY           INT
         , @n_CHQty              INT
         , @n_BLQTY              INT

         , @n_lineNo              INT
         , @n_MaxQcline           INT

         , @CUR_ASN              CURSOR
         , @b_debug              NVARCHAR(1) = '0'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   IF (ISNULL(@c_errmsg,'') = '')     --SY01
       SET @c_errmsg   = ''
   SET @c_UserName = SUSER_NAME()
   SET @c_SetErrMsg     = ''
   SET @n_lineNo        = 1
   SET @c_Maxline       = 1
   SET @c_Maxline     = '1'
   SET @c_GetErrMsg     = ''
   SET @c_GetStorerkey  = ''

  CREATE TABLE #TMP_FVASN01 (Storerkey       NVARCHAR(20) NULL,
                             RECKey          NVARCHAR(20) NULL,
                          --   RECLineNo       NVARCHAR(10) NULL,
                             Channel         NVARCHAR(20) NULL,
                             Facility        NVARCHAR(10) NULL,
                             SKU             NVARCHAR(20) NULL,
                            -- hostwhcode      NVARCHAR(20) NULL,
                             BFREVQTY     INT NULL DEFAULT(0))

  SELECT @c_GetStorerkey = RH.Storerkey
  FROM   RECEIPT       RH  WITH (NOLOCK)
  WHERE  RH.receiptkey = @c_ReceiptKey


   SELECT @c_GetErrMsg = description
   FROM   CODELKUP WITH (NOLOCK)
   WHERE    SHORT    = 'STOREDPROC'
   AND Storerkey = @c_GetStorerkey
   AND long = 'ispASNCHK01'


   INSERT INTO #TMP_FVASN01 (Storerkey,RECKey,Channel,Facility,SKU,BFREVQTY)
   SELECT DISTINCT RH.StorerKey,RH.ReceiptKey,RECD.Channel,RH.facility,RECD.sku,sum(RECD.BeforeReceivedQty)
   FROM   RECEIPT       RH  WITH (NOLOCK)
   JOIN   RECEIPTDETAIL RECD WITH (NOLOCK) ON (RECD.Receiptkey = RH.Receiptkey)
   --JOIN   LOC L WITH (NOLOCK) ON L.loc = IQCD.fromloc
   WHERE  RH.receiptkey = @c_receiptkey
   AND RECD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RECD.ReceiptLineNumber END
   AND RH.DocType = 'R' --AND RH.userdefine02='TU'
   AND RH.ASNReason = 'TRF'
   GROUP BY RH.StorerKey,RH.ReceiptKey,RECD.Channel,RH.facility,RECD.sku
   ORDER BY RH.StorerKey,RH.ReceiptKey,RECD.sku


   SET @CUR_ASN = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT facility
         ,Storerkey
         ,Sku
         ,Channel
         ,BFREVQTY
   FROM   #TMP_FVASN01
   WHERE  RECKey = @c_receiptkey
   ORDER BY sku

   OPEN @CUR_ASN

   FETCH NEXT FROM @CUR_ASN INTO @c_Facility
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Channel
                              ,  @n_BFREVQTY

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   --   BEGIN TRAN

      IF @b_debug = 1
      BEGIN
         SELECT @c_Receiptkey '@c_Receiptkey'
              , @c_Sku '@c_Sku'  , @n_BFREVQTY '@n_BFREVQTY'
      END

      SET   @n_CHQty = 0
      SET   @n_BLQTY = 0
      SET   @c_lineErr = 'N'


      SELECT @n_CHQty = ISNULL((CHINV.Qty-CHINV.QtyAllocated-CHINV.QtyOnHold),0)
      FROM Channelinv CHINV WITH (NOLOCK)
      WHERE CHINV.StorerKey = @c_Storerkey
      AND CHINV.Facility = @c_Facility
      AND CHINV.SKU = @c_Sku
      AND CHINV.Channel = 'B2C'

     SELECT @n_BLQTY = ISNULL(sum(lli.qty - lli.qtyallocated - lli.qtypicked),0)
     FROM Lotxlocxid lli WITH (NOLOCK)
     JOIN LOC L WITH (NOLOCK) ON L.loc = lli.loc
     WHERE lli.Storerkey = @c_storerkey
     AND lli.SKU = @c_sku
     AND L.Facility = @c_facility
     AND L.LocationFlag = 'B2C'

     SELECT @c_Maxline = COUNT(1)
     FROM   #TMP_FVASN01
     WHERE  RECKey = @c_receiptkey

      IF @b_debug = 1
      BEGIN
         SELECT  @c_Receiptkey '@c_Receiptkey'
              , @c_Sku '@c_Sku'  , @n_BFREVQTY '@n_BFREVQTY',@n_CHQty '@n_CHQty', @n_BLQTY '@n_BLQTY', @c_lineErr '@c_lineErr', @c_SetErrMsg '@c_SetErrMsg'
      END


          IF (@n_CHQty - @n_BLQTY) <  @n_BFREVQTY
          BEGIN
             SET @c_lineErr = 'Y'
          END


      IF @b_debug = 1
      BEGIN
         SELECT  @c_Receiptkey '@c_Receiptkey'
              , @c_Sku '@c_Sku'  , @n_BFREVQTY '@n_BFREVQTY',@n_CHQty '@n_CHQty', @n_BLQTY '@n_BLQTY', @c_lineErr '@c_lineErr', @c_SetErrMsg '@c_SetErrMsg'
      END

 IF @c_lineErr = 'Y'
 BEGIN
    IF @n_lineNo = 1
    BEGIN
       SET @c_SetErrMsg = @c_Sku
    END
    ELSE IF @n_lineNo <> @c_Maxline
    BEGIN
       SET @c_SetErrMsg = @c_SetErrMsg + ' ,' + @c_Sku + ','
    END
    ELSE IF @n_lineNo = @c_Maxline
    BEGIN
        SET @c_SetErrMsg = @c_SetErrMsg + @c_Sku
    END
END

SET @n_lineNo = @n_lineNo + 1

      IF @b_debug = 1
      BEGIN
         SELECT  @c_sku  '@c_sku'
               , @c_SetErrMsg '@c_SetErrMsg'
      END

FETCH NEXT FROM @CUR_ASN INTO    @c_Facility
                              ,  @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Channel
                              ,  @n_BFREVQTY
   END
   CLOSE @CUR_ASN
   DEALLOCATE @CUR_ASN

      IF @b_debug = 1
      BEGIN
         SELECT  @c_GetErrMsg '@c_GetErrMsg'
      END

   IF ISNULL(@c_SetErrMsg,'') <> ''
   BEGIN
     SET @n_Continue = 3
     SET @n_Err = 62103
     SET @c_ErrMsg = 'Error ' + CONVERT(CHAR(5), @n_Err) + space(2) + @c_GetErrMsg + ' found on SKU : ' + RTRIM(@c_SetErrMsg)
  END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
   END

END -- procedure


GO