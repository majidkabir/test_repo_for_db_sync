SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: WMS                                                 */
/* Copyright      : LFLogistics                                         */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Duplicate Receipt Line                                      */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Updates:                                                             */
/* Purpose: Duplicate Receipt Line Number                               */
/*                                                                      */
/* Date        Author   Rev   Purposes                                  */
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 03-May-2021 Wan02    1.2   LFWM-2756 - UAT - TW  QtyExpected not     */
/*                            deducted when using Duplicate Line function*/
/*                            in Receipt  Trade Return module            */
/* 28-Sep-2021 LZG      1.3   JSM-22537 - Fixed Receipt.OpenQty (ZG01)  */
/* 30-Nov-2021 Wan03    1.4   LFWM-2946 - UAT - TW  Expected quantity of*/
/*                            original line will change to 0 after using*/
/*                            Duplicate Line' in ASNReceipt module      */
/* 30-Nov-2021 Wan03    1.4   DevOps Combine Script                     */
/************************************************************************/
CREATE PROCEDURE [WM].[lsp_DuplicateReceiptLine]
    @c_ReceiptKey             NVARCHAR(10)
   ,@c_OriginalLineNumber     NVARCHAR(5)
   ,@c_NewLineNumber          NVARCHAR(5) OUTPUT
   --,@c_IncludeFinalizedItem   CHAR(1) = 'N'            --(Wan02)  --Not Need for ue_explode
   ,@b_Success                INT=1 OUTPUT
   ,@n_Err                    INT=0 OUTPUT
   ,@c_ErrMsg                 NVARCHAR(250)='' OUTPUT
   ,@c_UserName               NVARCHAR(128)=''
   ,@n_WarningNo              INT          = 0  OUTPUT
   ,@c_ProceedWithWarning     CHAR(1)      = 'N'         --(Wan02)  -- Pass In 'Y' if continue to call SP when increased warning # return
   ,@n_ErrGroupKey            INT          = 0  OUTPUT   --(Wan02)  -- Capture Warnings/Questions/Errors/Meassage into WMS_ERROR_LIST Table
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_QtyExpected           INT = 0
         , @n_QtyExpected_All       INT = 0
         , @n_BeforeReceivedQty     INT = 0
         , @n_QtyReceived           INT = 0
         , @n_QtyBalance            INT = 0

         , @c_LastReceiveLineNo     NVARCHAR(10) = ''
         , @c_TableName             NVARCHAR(10) = 'RECEIPT'
         , @c_SourceType            NVARCHAR(10) = 'lsp_DuplicateReceiptLine'

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0

   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
      GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                   --(Wan01) - END

   BEGIN TRY -- SWT01 - Begin Outer Begin Try
      SELECT @n_QtyExpected = RD.QtyExpected
            ,@n_QtyExpected_All = RD.QtyExpected + RD.FreeGoodQtyExpected
            ,@n_BeforeReceivedQty = RD.BeforeReceivedQty
            ,@n_QtyReceived = RD.QtyReceived
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      WHERE ReceiptKey = @c_ReceiptKey
      AND   RD.ReceiptLineNumber = @c_OriginalLineNumber

      IF @n_WarningNo < 1 AND @c_ProceedWithWarning = 'N'
      BEGIN
         IF @n_QtyExpected_All <= @n_QtyReceived
         BEGIN
            SET @b_success = 0
            SET @n_Err = 550701
            SET @c_ErrMsg = 'Quantity Expected Less then ZERO!'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Receiptkey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'Error'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success
               ,  @n_err         = @n_err
               ,  @c_errmsg      = @c_errmsg
            GOTO EXIT_SP
         END

         IF @n_QtyExpected <= 0
         BEGIN
            SET @n_WarningNo = 1
            SET @c_ErrMsg = 'Quantity Expected Less then ZERO, Still want to proceed?'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_ReceiptKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'Question'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success
               ,  @n_err         = @n_err
               ,  @c_errmsg      = @c_errmsg
            GOTO EXIT_SP
         END
      END
      /* (Wan02) - START
      DECLARE @c_StorerKey             NVARCHAR(15) = ''
              ,@c_Sku                   NVARCHAR(20) = ''
              ,@c_UOM                   NVARCHAR(10) = ''
              ,@c_PackKey               NVARCHAR(10) = ''
              ,@n_BeforeReceivedQty     INT          = 0
              ,@n_QtyExpected           INT          = 0
              ,@c_Facility              NVARCHAR(15) = ''
              ,@c_CustomisedSplitLine   NVARCHAR(30) = ''
              ,@n_PalletCnt             INT = 0
              ,@b_ZeroExpected          BIT = 0
              ,@b_ByExpected            BIT = 0
              ,@n_QtyToBeSplitted       INT = 0
              ,@n_RemainQty             INT = 0
              ,@c_LastReceiveLineNo     NVARCHAR(5) = ''
              ,@c_NextReceiveLineNo     NVARCHAR(5) = ''
              ,@n_RemainingQtyExpected  INT = 0
              ,@n_RemainQtyReceived     INT = 0
              ,@n_InsertBeforeReceivedQty INT = 0
              ,@n_InsertQtyExpected       INT = 0
              ,@c_ReceiptLineNumber       NVARCHAR(5)=''
      (Wan02) - END */

      SET @c_LastReceiveLineNo = ''
      SELECT @c_LastReceiveLineNo = MAX(RD.ReceiptLineNumber)
      FROM RECEIPTDETAIL AS RD WITH(NOLOCK)
      WHERE RD.ReceiptKey = @c_ReceiptKey

      IF @c_LastReceiveLineNo <> ''
      BEGIN
         --(Wan03) - START
         -- ZG01 (Start)
         --SELECT @n_QtyBalance = QtyExpected - BeforeReceivedQty FROM RECEIPTDETAIL AS r WITH(NOLOCK)
         --WHERE r.ReceiptKey = @c_ReceiptKey
         --AND   r.ReceiptLineNumber = @c_OriginalLineNumber
         -- ZG01 (End)
         --(Wan03) - END
         
         --(Wan02) - START
         SET @n_QtyBalance = 0                   --(Wan03) - START
         IF @n_BeforeReceivedQty > 0        
         BEGIN 
            SET @n_QtyBalance = @n_QtyExpected - @n_BeforeReceivedQty         --(Wan03)
            UPDATE RECEIPTDETAIL
               SET QtyExpected = @n_BeforeReceivedQty                         --(Wan03)--CASE WHEN BeforeReceivedQty > 0 THEN BeforeReceivedQty ELSE 0 END 
                  --,TrafficCop =  NULL                                       --(ZG01)
                  , EditWho  = SUSER_SNAME()
                  , EditDate = GETDATE()
            WHERE ReceiptKey = @c_ReceiptKey
            AND   ReceiptLineNumber = @c_OriginalLineNumber
         END                                    --(Wan03) - END
         --(Wan02) - END
         
         SET @c_NewLineNumber = RIGHT('0000' +
                                       CONVERT(VARCHAR(5), CAST(@c_LastReceiveLineNo AS INT) + 1),
                                       5)


         INSERT INTO RECEIPTDETAIL
         (
         ReceiptKey,          ReceiptLineNumber,      ExternReceiptKey,
         ExternLineNo,        StorerKey,              POKey,
         Sku,                 AltSku,                 Id,
         [Status],            DateReceived,           QtyExpected,
         QtyAdjusted,         QtyReceived,            UOM,
         PackKey,             VesselKey,              VoyageKey,
         XdockKey,            ContainerKey,           ToLoc,
         ToLot,               ToId,                   ConditionCode,
         Lottable01,          Lottable02,             Lottable03,
         Lottable04,          Lottable05,             CaseCnt,
         InnerPack,           Pallet,                 [Cube],
         GrossWgt,            NetWgt,                 OtherUnit1,
         OtherUnit2,          UnitPrice,              ExtendedPrice,
         TariffKey,           FreeGoodQtyExpected,    FreeGoodQtyReceived,
         SubReasonCode,       FinalizeFlag,           DuplicateFrom,
         BeforeReceivedQty,   PutawayLoc,             ExportStatus,
         SplitPalletFlag,     POLineNumber,           LoadKey,
         ExternPoKey,         UserDefine01,           UserDefine02,
         UserDefine03,        UserDefine04,           UserDefine05,
         UserDefine06,        UserDefine07,           UserDefine08,
         UserDefine09,        UserDefine10,           Lottable06,
         Lottable07,          Lottable08,             Lottable09,
         Lottable10,          Lottable11,             Lottable12,
         Lottable13,          Lottable14,             Lottable15,
         AddWho,              EditWho
         )
         SELECT
         @c_ReceiptKey,       @c_NewLineNumber,      ExternReceiptKey,
         ExternLineNo,        StorerKey,              POKey,
         Sku,                 AltSku,                 Id,
         [Status]='0',        DateReceived,           --[QtyExpected]=CASE WHEN BeforeReceivedQty > 0 THEN QtyExpected - BeforeReceivedQty ELSE 0 END,    --(Wan02)
         [QtyExpected]  =  @n_QtyBalance,             --(Wan03) CASE WHEN @n_QtyBalance > 0 THEN @n_QtyBalance ELSE 0 END,   -- ZG01                             
         QtyAdjusted=0,       QtyReceived=0,          UOM,
         PackKey,             VesselKey,              VoyageKey,
         XdockKey,            ContainerKey,           ToLoc,
         ToLot='',            ToId='',                ConditionCode='OK',
         Lottable01,          Lottable02,             Lottable03,
         Lottable04,          Lottable05,             CaseCnt,
         InnerPack,           Pallet,                 [Cube],
         GrossWgt,            NetWgt,                 OtherUnit1,
         OtherUnit2,          UnitPrice,              ExtendedPrice,
         TariffKey,           FreeGoodQtyExpected,    FreeGoodQtyReceived,
         SubReasonCode='',    FinalizeFlag='N',       DuplicateFrom='',
         BeforeReceivedQty=0, PutawayLoc='',          ExportStatus,
         SplitPalletFlag,     POLineNumber,           LoadKey='',
         ExternPoKey,         UserDefine01,           UserDefine02,
         UserDefine03,        UserDefine04,           UserDefine05,
         UserDefine06,        UserDefine07,           UserDefine08,
         UserDefine09,        UserDefine10,           Lottable06,
         Lottable07,          Lottable08,             Lottable09,
         Lottable10,          Lottable11,             Lottable12,
         Lottable13,          Lottable14,             Lottable15,
         @c_UserName,         @c_UserName
         FROM RECEIPTDETAIL AS r WITH(NOLOCK)
         WHERE r.ReceiptKey = @c_ReceiptKey
         AND   r.ReceiptLineNumber = @c_OriginalLineNumber
         
      END -- IF @c_LastReceiveLineNo <> ''

      IF @@ROWCOUNT > 0
      BEGIN
         SET @b_Success = 1
         SET @c_ErrMsg = 'New Duplicated ReceiptLine added'
      END
      ELSE
      BEGIN
         SET @b_Success = 0
         SET @c_ErrMsg = 'Failed to Duplicates the ReceiptLine: ' + @c_OriginalLineNumber
      END
   END TRY

   BEGIN CATCH
      SET @b_Success = 0                  --(Wan01)
      SET @c_ErrMsg = ERROR_MESSAGE()     --(Wan01)
      GOTO EXIT_SP
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch

   EXIT_SP:
   REVERT
END

GO