SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RFID_Receiving_Confirm                          */
/* Creation Date: 2020-09-21                                             */
/* Copyright: Maersk                                                     */
/* Written by: Wan                                                       */
/*                                                                       */
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*          ASN Header                                                   */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* Version: 1.2                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 09-OCT-2020 Wan      1.0   Created                                    */
/* 2021-03-19  Wan01    1.1   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                 */
/* 2023-09-23  Wan02    1.2   WMS-23643 - [CN]NIKE_B2C_Creturn_NFC_      */
/*                            Ehancement_Function CR                     */
/*************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RFID_Receiving_Confirm]
   @n_SessionID         BIGINT         = 0
,  @c_ReceiptKey        NVARCHAR(10)   = ''
,  @c_CarrierReference  NVARCHAR(18)   = ''
,  @n_TotalQtyReceived  INT            = 0   OUTPUT
,  @b_Success           INT            = 1   OUTPUT
,  @n_Err               INT            = 0   OUTPUT
,  @c_Errmsg            NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @n_Cnt                INT          = 0
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_CarrierRef         NVARCHAR(18) = ''
         , @c_ASNStatus          NVARCHAR(10) = '0'

         , @n_RowID              BIGINT       = 0
         , @n_Qty                INT          = 0
         , @c_ToLoc              NVARCHAR(10) = ''
         , @c_ToId               NVARCHAR(18) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Lottable01         NVARCHAR(18) = ''
         , @c_Lottable02         NVARCHAR(18) = ''
         , @c_Lottable03         NVARCHAR(18) = ''
         , @dt_Lottable04        DATETIME     = NULL
         , @dt_Lottable05        DATETIME     = NULL                                --(Wan02)
         , @c_Lottable06         NVARCHAR(30) = ''
         , @c_Lottable07         NVARCHAR(30) = ''
         , @c_Lottable08         NVARCHAR(30) = ''
         , @c_Lottable09         NVARCHAR(30) = ''
         , @c_Lottable10         NVARCHAR(30) = ''
         , @c_Lottable11         NVARCHAR(30) = ''
         , @c_Lottable12         NVARCHAR(30) = ''
         , @dt_Lottable13        DATETIME     = NULL
         , @dt_Lottable14        DATETIME     = NULL
         , @dt_Lottable15        DATETIME     = NULL

         , @c_TrackingNo         NVARCHAR(30) = ''
         
         , @n_RowID_Max          BIGINT       = 0                                   --(Wan02)
         , @c_RFIDNo1            NVARCHAR(100) = ''                                 --(Wan02)

         , @CUR_DOCINFO          CURSOR                                             --(Wan02)
         , @CUR_CFMREC           CURSOR
         
         
   IF OBJECT_ID('tempdb..##TMP_CFMPOST','u') IS NOT NULL                            --(Wan02) - START
   BEGIN
      DROP TABLE #TMP_CFMPOST;
   END      
   
   CREATE TABLE #TMP_CFMPOST  
         ( RowID              INT            NOT NULL IDENTITY(1,1)  PRIMARY KEY
         , RowRef             BIGINT         NOT NULL DEFAULT(0)     
         , Storerkey          NVARCHAR(15)   DEFAULT('')
         , Sku                NVARCHAR(20)   DEFAULT('')
         , ToLoc              NVARCHAR(10)   DEFAULT('')
         , ToId               NVARCHAR(18)   DEFAULT('')
         , Lottable01         NVARCHAR(18)   DEFAULT('')
         , Lottable02         NVARCHAR(18)   DEFAULT('')
         , Lottable03         NVARCHAR(18)   DEFAULT('')
         , Lottable04         DATETIME 
         , Lottable05         DATETIME                    
         , Lottable06         NVARCHAR(30)   DEFAULT('')
         , Lottable07         NVARCHAR(30)   DEFAULT('')
         , Lottable08         NVARCHAR(30)   DEFAULT('')
         , Lottable09         NVARCHAR(30)   DEFAULT('')
         , Lottable10         NVARCHAR(30)   DEFAULT('')
         , Lottable11         NVARCHAR(30)   DEFAULT('')
         , Lottable12         NVARCHAR(30)   
         , Lottable13         DATETIME       
         , Lottable14         DATETIME       
         , Lottable15         DATETIME       DEFAULT('')  
         , Qty                INT            DEFAULT(0)
         , Userdefine02       NVARCHAR(30)   NOT NULL
         , Userdefine04       NVARCHAR(30)   NOT NULL      
         )                                                                          --(Wan02) - END
         
   SELECT @n_Cnt = 1
         ,@c_Facility = RH.Facility
         ,@c_Storerkey= RH.Storerkey
         ,@c_CarrierRef = RH.CarrierReference
         ,@c_ASNStatus  = RH.ASNStatus
   FROM RECEIPT RH WITH (NOLOCK)
   WHERE RH.ReceiptKey = @c_ReceiptKey

   IF @n_Cnt = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 86010
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': ASN Not Found. (isp_RFID_Receiving_Confirm)'
      GOTO QUIT_SP
   END

   IF @c_ASNStatus = '9'
   BEGIN
      SET @n_continue = 3
      SET @n_err = 86020
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': ASN Has Been Finalized. (isp_RFID_Receiving_Confirm)'
      GOTO QUIT_SP
   END

   IF @c_CarrierReference <> @c_CarrierRef
   BEGIN
      UPDATE RECEIPT
         SET CarrierReference = @c_CarrierReference
         , Trafficcop = NULL
         , EditWho    = SUSER_NAME()
         , EditDate   = GETDATE()
      WHERE ReceiptKey = @c_ReceiptKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 86030
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPT Failed. (isp_RFID_Receiving_Confirm)'
         GOTO QUIT_SP
      END
   END

   SET @CUR_DOCINFO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   RD.RowID
      ,     RD.ToLoc
      ,     RD.ToId
      ,     RD.Sku
      ,     RD.Lottable01
      ,     RD.Lottable02
      ,     RD.Lottable03
      ,     RD.Lottable04
      ,     RD.Lottable05     
      ,     RD.Lottable06
      ,     RD.Lottable07
      ,     RD.Lottable08
      ,     RD.Lottable09
      ,     RD.Lottable10
      ,     RD.Lottable11
      ,     RD.Lottable12
      ,     RD.Lottable13
      ,     RD.Lottable14
      ,     RD.Lottable15
      ,     RD.UserDefine02
      ,     RD.UserDefine04
      ,     RD.RFIDNo1                                                              --(Wan02)
   FROM RECEIPTDETAIL_WIP RD WITH (NOLOCK)
   WHERE RD.SessionID  = @n_SessionID
   AND   RD.ReceiptKey = @c_ReceiptKey
   AND   RD.LockDocKey  IN ('','N')
   ORDER BY RD.RowID                                                                --(Wan02)

   OPEN @CUR_DOCINFO

   FETCH NEXT FROM @CUR_DOCINFO INTO
                                 @n_RowID
                              ,  @c_ToLoc
                              ,  @c_ToId
                              ,  @c_Sku
                              ,  @c_Lottable01
                              ,  @c_Lottable02
                              ,  @c_Lottable03
                              ,  @dt_Lottable04
                              ,  @dt_Lottable05
                              ,  @c_Lottable06
                              ,  @c_Lottable07
                              ,  @c_Lottable08
                              ,  @c_Lottable09
                              ,  @c_Lottable10
                              ,  @c_Lottable11
                              ,  @c_Lottable12
                              ,  @dt_Lottable13
                              ,  @dt_Lottable14
                              ,  @dt_Lottable15
                              ,  @c_CarrierReference
                              ,  @c_TrackingNo
                              ,  @c_RFIDNo1                                         --(Wan02)

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @n_RowID_Max  = MAX(WIP.RowID)
           , @n_Qty        = SUM(WIP.Qty)
      FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)  
      WHERE WIP.SessionID  = @n_SessionID  
      AND   WIP.Storerkey  = @c_StorerKey  
      AND   WIP.Sku        = @c_Sku  
      AND   WIP.ToLoc      = @c_ToLoc  
      AND   WIP.ToID       = @c_ToID  
      AND   WIP.Lottable01 = @c_Lottable01  
      AND   WIP.Lottable02 = @c_Lottable02  
      AND   WIP.Lottable03 = @c_Lottable03  
      AND   WIP.Lottable04 = @dt_Lottable04  
      AND   WIP.Lottable05 = @dt_Lottable05  
      AND   WIP.Lottable06 = @c_Lottable06  
      AND   WIP.Lottable07 = @c_Lottable07  
      AND   WIP.Lottable08 = @c_Lottable08  
      AND   WIP.Lottable09 = @c_Lottable09  
      AND   WIP.Lottable10 = @c_Lottable10  
      AND   WIP.Lottable11 = @c_Lottable11  
      AND   WIP.Lottable12 = @c_Lottable12  
      AND   WIP.Lottable13 = @dt_Lottable13  
      AND   WIP.Lottable14 = @dt_Lottable14  
      AND   WIP.Lottable15 = @dt_Lottable15  

      IF NOT EXISTS (SELECT 1 FROM #TMP_CFMPOST AS tc WHERE tc.RowRef = @n_RowID_Max)
      BEGIN
         INSERT INTO #TMP_CFMPOST
             (
                 RowRef
             ,   Storerkey
             ,   Sku
             ,   ToLoc
             ,   ToId
             ,   Lottable01
             ,   Lottable02
             ,   Lottable03
             ,   Lottable04
             ,   Lottable05
             ,   Lottable06
             ,   Lottable07
             ,   Lottable08
             ,   Lottable09
             ,   Lottable10
             ,   Lottable11
             ,   Lottable12
             ,   Lottable13
             ,   Lottable14
             ,   Lottable15
             ,   Qty
             ,   Userdefine02
             ,   Userdefine04
             )
         VALUES
             (
                 @n_RowID_Max         
             ,   @c_Storerkey 
             ,   @c_Sku 
             ,   @c_ToLoc
             ,   @c_ToId 
             ,   @c_Lottable01 
             ,   @c_Lottable02 
             ,   @c_Lottable03 
             ,   @dt_Lottable04
             ,   @dt_Lottable05 
             ,   @c_Lottable06 
             ,   @c_Lottable07 
             ,   @c_Lottable08 
             ,   @c_Lottable09 
             ,   @c_Lottable10 
             ,   @c_Lottable11 
             ,   @c_Lottable12 
             ,   @dt_Lottable13 
             ,   @dt_Lottable14 
             ,   @dt_Lottable15 
             ,   @n_Qty 
             ,   @c_CarrierReference
             ,   @c_TrackingNo       
             )
      END
      
      IF EXISTS ( SELECT 1                                                         
                  FROM SKUINFO AS si WITH (NOLOCK) 
                  WHERE si.Storerkey = @c_Storerkey          
                  AND si.Sku = @c_Sku
                  AND si.ExtendedField03 = 'NFC'
                )
      BEGIN 
         INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq)
         VALUES ('NFCRecord', @c_Storerkey, @c_RFIDNo1, @c_Sku, @c_ReceiptKey, 0)
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 86038
            SET @c_Errmsg = ERROR_MESSAGE()
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Error Insert NFCRecord to DocInfo. (isp_RFID_Receiving_Confirm)'
                          + '(' + @c_Errmsg + ')'
            GOTO QUIT_SP
         END
      END                                                                           
     
      EXEC dbo.isp_Delete_ReceiptDetail_WIP
            @n_RowID   = @n_RowID
         ,  @b_Success = @b_Success OUTPUT
         ,  @n_Err     = @n_Err     OUTPUT
         ,  @c_Errmsg  = @c_Errmsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 86050
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Error Executing isp_Delete_ReceiptDetail_WIP. (isp_RFID_Receiving_Confirm)'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_DOCINFO INTO
                                    @n_RowID
                                 ,  @c_ToLoc
                                 ,  @c_ToId
                                 ,  @c_Sku
                                 ,  @c_Lottable01
                                 ,  @c_Lottable02
                                 ,  @c_Lottable03
                                 ,  @dt_Lottable04
                                 ,  @dt_Lottable05
                                 ,  @c_Lottable06
                                 ,  @c_Lottable07
                                 ,  @c_Lottable08
                                 ,  @c_Lottable09
                                 ,  @c_Lottable10
                                 ,  @c_Lottable11
                                 ,  @c_Lottable12
                                 ,  @dt_Lottable13
                                 ,  @dt_Lottable14
                                 ,  @dt_Lottable15
                                 ,  @c_CarrierReference
                                 ,  @c_TrackingNo
                                 ,  @c_RFIDNo1                                      
   END
   CLOSE @CUR_DOCINFO
   DEALLOCATE @CUR_DOCINFO

   SET @CUR_CFMREC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   tc.RowID
      ,     tc.ToLoc
      ,     tc.ToId
      ,     tc.Sku
      ,     tc.Lottable01
      ,     tc.Lottable02
      ,     tc.Lottable03
      ,     tc.Lottable04
      ,     tc.Lottable06
      ,     tc.Lottable07
      ,     tc.Lottable08
      ,     tc.Lottable09
      ,     tc.Lottable10
      ,     tc.Lottable11
      ,     tc.Lottable12
      ,     tc.Lottable13
      ,     tc.Lottable14
      ,     tc.Lottable15
      ,     tc.Qty
      ,     tc.UserDefine02
      ,     tc.UserDefine04
   FROM #TMP_CFMPOST AS tc WITH (NOLOCK)
   ORDER BY tc.RowID                                                                --(Wan02) - END

   OPEN @CUR_CFMREC

   FETCH NEXT FROM @CUR_CFMREC INTO
                                 @n_RowID
                              ,  @c_ToLoc
                              ,  @c_ToId
                              ,  @c_Sku
                              ,  @c_Lottable01
                              ,  @c_Lottable02
                              ,  @c_Lottable03
                              ,  @dt_Lottable04
                              ,  @c_Lottable06
                              ,  @c_Lottable07
                              ,  @c_Lottable08
                              ,  @c_Lottable09
                              ,  @c_Lottable10
                              ,  @c_Lottable11
                              ,  @c_Lottable12
                              ,  @dt_Lottable13
                              ,  @dt_Lottable14
                              ,  @dt_Lottable15
                              ,  @n_Qty
                              ,  @c_CarrierReference
                              ,  @c_TrackingNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      --Confirm RFID Receiving
      EXEC dbo.isp_RFID_Receiving_ConfirmPost
           @c_StorerKey      = @c_StorerKey
         , @c_Facility       = @c_Facility
         , @c_ReceiptKey     = @c_ReceiptKey
         , @c_POKey          = ''
         , @c_ToLOC          = @c_ToLoc
         , @c_ToID           = @c_ToID
         , @c_SKU            = @c_SKU
         , @c_UOM            = ''
         , @n_QTY            = @n_QTY
         , @c_Lottable01     = @c_Lottable01
         , @c_Lottable02     = @c_Lottable02
         , @c_Lottable03     = @c_Lottable03
         , @dt_Lottable04    = @dt_Lottable04
         , @dt_Lottable05    = NULL
         , @c_Lottable06     = @c_Lottable06
         , @c_Lottable07     = @c_Lottable07
         , @c_Lottable08     = @c_Lottable08
         , @c_Lottable09     = @c_Lottable09
         , @c_Lottable10     = @c_Lottable10
         , @c_Lottable11     = @c_Lottable11
         , @c_Lottable12     = @c_Lottable12
         , @dt_Lottable13    = @dt_Lottable13
         , @dt_Lottable14    = @dt_Lottable14
         , @dt_Lottable15    = @dt_Lottable15
         , @c_UserDefine02   = @c_CarrierReference
         , @c_UserDefine04   = @c_TrackingNo
         , @c_ConditionCode  = 'OK'
         , @c_SubreasonCode  = ''
         , @b_Success        = @b_Success OUTPUT
         , @n_Err            = @n_Err     OUTPUT
         , @c_Errmsg         = @c_Errmsg  OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 86040
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Error Executing isp_RFID_Receiving_ConfirmPost. (isp_RFID_Receiving_Confirm)'
                       + '(' + @c_Errmsg + ')'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_CFMREC INTO
                                    @n_RowID
                                 ,  @c_ToLoc
                                 ,  @c_ToId
                                 ,  @c_Sku
                                 ,  @c_Lottable01
                                 ,  @c_Lottable02
                                 ,  @c_Lottable03
                                 ,  @dt_Lottable04
                                 ,  @c_Lottable06
                                 ,  @c_Lottable07
                                 ,  @c_Lottable08
                                 ,  @c_Lottable09
                                 ,  @c_Lottable10
                                 ,  @c_Lottable11
                                 ,  @c_Lottable12
                                 ,  @dt_Lottable13
                                 ,  @dt_Lottable14
                                 ,  @dt_Lottable15
                                 ,  @n_Qty
                                 ,  @c_CarrierReference
                                 ,  @c_TrackingNo
   END
   CLOSE @CUR_CFMREC
   DEALLOCATE @CUR_CFMREC

   SELECT @n_TotalQtyReceived = SUM(RD.BeforeReceivedQty)
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey
   GROUP BY RD.Receiptkey
   
   QUIT_SP:
   IF OBJECT_ID('tempdb..##TMP_CFMPOST','u') IS NOT NULL                            --(Wan02) - START
   BEGIN
      DROP TABLE #TMP_CFMPOST;
   END                                                                              --(Wan02) - END
    
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_Receiving_Confirm'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO