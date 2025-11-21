SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: lsp_FinalizeReceipt_Wrapper                            */
/* Creation Date:                                                          */
/* Copyright : LFLogistics                                                 */
/* Written by: Wan                                                         */
/*                                                                         */
/* Purpose: Finalize Receipt                                               */
/*                                                                         */
/* Called By: SCE                                                          */
/*          :                                                              */
/* PVCS Version: 2.7                                                       */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 2020-11-26  Wan01    1.1   Add Big Outer Begin Try..End Try to enable   */
/*                            Revert when Sub SP Raise error               */
/* 2020-12-15  Wan02    1.2   LFWM-2303 - UAT - TW  ASN Finalize issues    */
/* 2021-01-15  Wan03    1.2   Execute Login if @c_UserName<>SUSER_SNAME()  */
/* 2021-04-26  Wan04    1.3   LFWM-2706 - UAT - TW   Storerconfig          */
/*                            FinalizeASNPromptSaveID' does not work in    */
/*                            ASN and Trade                                */
/* 2021-06-23  Wan05    1.4   LFWM-2863 - Receipt not able to finalize     */
/* 2021-06-25  BeeTin   1.5   JSM-5512 - Generate TOID without prompt      */
/*                            dialog to confirm.                           */
/* 2022-01-20  Wan06    1.6   LFWM-2977 - [CN] Lacoste_Fianlize_ASN        */
/* 2022-01-20  Wan06    1.6   DevOps Combine Script                        */
/* 2022-03-16  Wan07    1.7   LFWM-3438 - UAT-CN SCE finalize receipt stuck*/
/*                            Fix InifinityLoop in getting POKey           */
/* 2022-03-28  SPChin   1.8   JSM-52407 Remove Error Code                  */
/* 2022-03-18  SPChin   1.9   JSM-56642 Bug Fixed                          */
/* 2022-05-25  Wan08    2.0   LFWM-3505-Storerconfig DisAllowDuplicateIdsOnWSRcpt */
/*                            Enhancement                                  */
/* 2022-07-19  Wan09    2.1   JSM-82472 - Excluded unreceived line         */
/* 2022-09-19  Wan10    2.2   LFWM-3760 - PH - SCE Returns Validation Allow*/
/*                            Duplicate ID                                 */
/* 2022-10-13  Wan11    2.3   LFWM-3780 - PH Unilever                      */
/*                            DisAllowDuplicateIdsOnWSRcpt StorerCFG CR    */
/* 2022-11-24  Leong01  2.4   Add ISNULL check.                            */
/* 2023-04-27  Wan12    2.5   LFWM-4181 - SCE ASN Finalize Alert Enhancement*/
/* 2023-08-16  Wan14    2.6   LFWM-4417 - SCE PROD SG Receipt - Disallow   */
/*                            Duplicate Movable Unit ID Error When Save when*/
/*                            exists Receipt Reversed Detail               */
/* 2024-09-24  Wan15    2.7   SPP-36048 - Empty Reason Code prompt         */
/***************************************************************************/

CREATE   PROCEDURE [WM].[lsp_FinalizeReceipt_Wrapper]
      @c_ReceiptKey              NVARCHAR(10)
    , @c_ReceiptLineNumber       NVARCHAR(5)    = ''
    , @b_Success                 INT            = 1  OUTPUT
    , @n_Err                     INT            = 0  OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  =''  OUTPUT
    , @n_WarningNo               INT            = 0  OUTPUT
    , @c_ProceedWithWarning      CHAR(1)        = 'N'
    , @c_UserName                NVARCHAR(128)  =''
    , @n_ErrGroupKey             INT            = 0  OUTPUT
    , @n_SkipGenID               INT            = 0  OUTPUT             --(Wan04)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT
         , @c_TableName                NVARCHAR(50)   = 'ReceiptDetail'
         , @c_SourceType               NVARCHAR(50)   = 'lsp_FinalizeReceipt_Wrapper'

   DECLARE
           @c_Facility                 NVARCHAR(5)    = ''
         , @c_Storerkey                NVARCHAR(10)   = ''
         , @c_ASNStatus                NVARCHAR(10)   = ''
         , @c_RecType                  NVARCHAR(10)   = ''
         , @c_DocType                  NVARCHAR(1)    = ''
         , @c_UserDefine01             NVARCHAR(30)   = ''
         , @c_UserDefine02             NVARCHAR(30)   = ''
         , @dt_DeliveryDate            DATETIME
         , @c_ASNReason                NVARCHAR(10)   = ''
         , @c_WHSERef                  NVARCHAR(18)   = ''
         , @c_ShipmentNo               NVARCHAR(18)   = ''
         , @c_CTNType                  NVARCHAR(10)   = ''
         , @c_PackType                 NVARCHAR(10)   = ''
         , @n_CTNQty                   INT            = 0
         , @n_CTNCnt                   INT            = 0
         , @c_CTNType1                 NVARCHAR(10)   = ''
         , @c_PackType1                NVARCHAR(10)   = ''
         , @n_CTNQty1                  INT            = 0
         , @n_CTNCnt1                  INT            = 0
         , @c_CTNType2                 NVARCHAR(30)   = ''
         , @c_PackType2                NVARCHAR(30)   = ''
         , @n_CTNQty2                  INT            = 0
         , @n_CTNCnt2                  INT            = 0
         , @c_CTNType3                 NVARCHAR(30)   = ''
         , @c_PackType3                NVARCHAR(30)   = ''
         , @n_CTNQty3                  INT            = 0
         , @n_CTNCnt3                  INT            = 0
         , @c_CTNType4                 NVARCHAR(30)   = ''
         , @c_PackType4                NVARCHAR(30)   = ''
         , @n_CTNQty4                  INT            = 0
         , @n_CTNCnt4                  INT            = 0
         , @c_CTNType5                 NVARCHAR(30)   = ''
         , @c_PackType5                NVARCHAR(30)   = ''
         , @n_CTNQty5                  INT            = 0
         , @n_CTNCnt5                  INT            = 0
         , @c_CTNType6                 NVARCHAR(30)   = ''
         , @c_PackType6                NVARCHAR(30)   = ''
         , @n_CTNQty6                  INT            = 0
         , @n_CTNCnt6                  INT            = 0
         , @c_CTNType7                 NVARCHAR(30)   = ''
         , @c_PackType7                NVARCHAR(30)   = ''
         , @n_CTNQty7                  INT            = 0
         , @n_CTNCnt7                  INT            = 0
         , @c_CTNType8                 NVARCHAR(30)   = ''
         , @c_PackType8                NVARCHAR(30)   = ''
         , @n_CTNQty8                  INT            = 0
         , @n_CTNCnt8                  INT            = 0
         , @c_CTNType9                 NVARCHAR(30)   = ''
         , @c_PackType9                NVARCHAR(30)   = ''
         , @n_CTNQty9                  INT            = 0
         , @n_CTNCnt9                  INT            = 0
         , @c_CTNType10                NVARCHAR(30)   = ''
         , @c_PackType10               NVARCHAR(30)   = ''
         , @n_CTNQty10                 INT            = 0
         , @n_CTNCnt10                 INT            = 0

         , @c_ReceiptLineNo            NVARCHAR(5)    = ''
         , @c_Sku                      NVARCHAR(20)   = ''
         , @c_Lot                      NVARCHAR(10)   = ''
         , @c_ToLoc                    NVARCHAR(10)   = ''
         , @c_ToID                     NVARCHAR(18)   = ''
         , @c_Lottable01               NVARCHAR(18)   = ''
         , @c_Lottable02               NVARCHAR(18)   = ''
         , @c_Lottable03               NVARCHAR(18)   = ''
         , @dt_Lottable04              DATETIME
         , @dt_Lottable05              DATETIME
         , @c_lottable06               NVARCHAR(30)   = ''
         , @c_lottable07               NVARCHAR(30)   = ''
         , @c_lottable08               NVARCHAR(30)   = ''
         , @c_lottable09               NVARCHAR(30)   = ''
         , @c_lottable10               NVARCHAR(30)   = ''
         , @c_lottable11               NVARCHAR(30)   = ''
         , @c_lottable12               NVARCHAR(30)   = ''
         , @dt_lottable13              DATETIME
         , @dt_lottable14              DATETIME
         , @dt_lottable15              DATETIME
         , @c_PutawayLoc               NVARCHAR(10)   = ''
         , @c_UserDefine08             NVARCHAR(30)   = ''

         , @n_QtyOrdered               INT            = 0
         , @n_QtyExpected              INT            = 0
         , @n_QtyReceived              INT            = 0
         , @n_BeforeReceivedQty        INT            = 0
         , @n_FreeGoodQtyReceived      INT            = 0
         , @n_SumBeforeReceivedQty     INT            = 0
         , @n_SumFreeGoodQtyReceived   INT            = 0

         --, @c_ExternReceiptKey         NVARCHAR(20)   = ''   --JSM-56642
         , @c_ExternReceiptKey         NVARCHAR(50)   = ''     --JSM-56642
         , @c_ExternLineNo             NVARCHAR(20)   = ''
         , @c_POKey                    NVARCHAR(10)   = ''
         , @c_Packkey                  NVARCHAR(10)   = ''
         , @c_ASNDetRSN                NVARCHAR(10)   = ''

         , @c_SkuIVAS                  NVARCHAR(10)   = ''

         , @n_TOLPCT                   FLOAT          = 0.00
         , @n_ShelfLife                FLOAT          = 0.00
         , @n_Pallet                   INT            = 0

         , @n_Cnt                      INT            = 0

         , @b_ChkShelfLife             BIT            = 0
         , @b_ChkIVAS                  BIT            = 0
         , @b_FullCTNInfo              BIT            = 0

         , @b_CTNCompleteInfo          BIT            = 0
         , @b_InvHoldlot               BIT            = 0
         , @b_GenID                    BIT            = 0
         , @b_HoldID                   BIT            = 0
         , @b_HoldLot02                BIT            = 0
         , @b_HoldInv                  BIT            = 0

         , @c_HoldID                   NVARCHAR(10)   = ''
         , @c_HoldLot02                NVARCHAR(10)   = ''
         , @c_ReceiptHoldCode          NVARCHAR(10)   = ''

         , @c_ChkASNVarTol             NVARCHAR(30)   = ''
         , @c_ShipmentNoCfg            NVARCHAR(30)   = ''
         , @c_FnzChkPltline            NVARCHAR(30)   = ''
         , @c_CHKIncomingShelfLife     NVARCHAR(30)   = ''
         , @c_CHKIncomingIVAS          NVARCHAR(30)   = ''
         , @c_UDF01Req                 NVARCHAR(30)   = ''
         , @c_AsnHdRsn                 NVARCHAR(30)   = ''
         , @c_AllowOneASNPerPO         NVARCHAR(30)   = ''
         , @c_RcptWHRef                NVARCHAR(30)   = ''
         , @c_UTLITF                   NVARCHAR(30)   = ''
         , @c_CTNTypeTab               NVARCHAR(30)   = ''
         , @c_CrossWH                  NVARCHAR(30)   = ''
         , @c_UCCTracking              NVARCHAR(30)   = ''
         , @c_NikeRegITF               NVARCHAR(30)   = ''
         , @c_ByPassTol                NVARCHAR(30)   = ''
         , @c_UCCTrackValue            NVARCHAR(10)   = ''        --(Wan05)
         , @c_DisAllowDuplicateIdsOnWSRcpt NVARCHAR(10)  = ''     --(Wan08)
         , @c_DisAllowDupIDsOnWSRcpt_Option5 NVARCHAR(1000) = ''  --(Wan10)
         , @c_UniqueIDSkipDocType      NVARCHAR(30) = ''          --(Wan10)
         , @c_AllowDupWithinPLTCnt     NVARCHAR(30) = 'N'         --(Wan11) 

         , @b_ValidID                  INT          = 0           --(Wan11) 
         , @c_MUID                     NVARCHAR(30)   = ''
         , @c_GenID                    NVARCHAR(30)   = ''
         , @c_RF_Enable                NVARCHAR(30)   = ''
         , @c_XDFNZAutoAllocPickSO     NVARCHAR(30)   = ''
         , @c_InvHoldCheckCFG          NVARCHAR(30)   = ''
         , @c_HoldLot02ByUDF08         NVARCHAR(30)   = ''
         , @c_HoldByLottable02         NVARCHAR(30)   = ''
         , @c_AllowASNLot2Rehold       NVARCHAR(30)   = ''
         , @c_FinalizeASNPromptSaveID  NVARCHAR(30)   = ''     --Wan04
            
         ,  @c_Refkey1                 NVARCHAR(20)   = ''     --(Wan06)               
         ,  @c_Refkey2                 NVARCHAR(20)   = ''     --(Wan06)               
         ,  @c_Refkey3                 NVARCHAR(20)   = ''     --(Wan06)               
         ,  @c_WriteType               NVARCHAR(50)   = ''     --(Wan06)               
         ,  @n_LogWarningNo            INT            = 0      --(Wan06)
         ,  @n_LogErrNo                INT            = ''     --(Wan06)               
         ,  @c_LogErrMsg               NVARCHAR(255)  = ''     --(Wan06)
         
         , @CUR_RD                     CURSOR
         , @CUR_ERRLIST                CURSOR                  --(Wan06)
         
   --(Wan06) - START
   DECLARE  @t_WMSErrorList   TABLE                                  
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(50)   NOT NULL DEFAULT('') --(Wan14)
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )
   --(Wan06) - END
   
   SET  @n_ErrGroupKey = 0
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName     --(Wan03)
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                  --(Wan03)

   SET @n_continue   = 1
   SET @c_TableName  = 'ReceiptDetail'
   SET @c_SourceType = 'lsp_FinalizeReceipt_Wrapper'
   SET @n_ErrGroupKey= 0

   --(Wan01) - START
   BEGIN TRY
      -- Validation before finalize
      DECLARE @tRECEIPTDETAIL TABLE
            (
               ReceiptKey        NVARCHAR(10)
            ,  ReceiptLineNumber NVARCHAR(5)
            PRIMARY KEY CLUSTERED (ReceiptKey, ReceiptLineNumber)
            )

      SET @c_ReceiptLineNumber = ISNULL(@c_ReceiptLineNumber,'')
      IF @c_ReceiptLineNumber = ''
      BEGIN
         INSERT INTO @tRECEIPTDETAIL (ReceiptKey, ReceiptLineNumber)
         SELECT RD.ReceiptKey, RD.ReceiptLineNumber
         FROM RECEIPTDETAIL RD WITH (NOLOCK)
         WHERE RD.ReceiptKey = @c_ReceiptKey
      END
      ELSE
      BEGIN
         INSERT INTO @tRECEIPTDETAIL (ReceiptKey, ReceiptLineNumber)
         VALUES (@c_ReceiptKey, @c_ReceiptLineNumber)
      END

      SELECT @c_ASNStatus = r.ASNStatus
            ,@c_StorerKey = r.StorerKey
            ,@c_Facility  = r.Facility
            ,@c_RecType   = r.RECType
            ,@c_DocType   = r.DocType
            ,@c_UserDefine01 = ISNULL(RTRIM(r.UserDefine01),'')
            ,@c_UserDefine02 = ISNULL(RTRIM(r.UserDefine01),'')
            ,@dt_DeliveryDate= r.effectivedate
            ,@c_ASNReason    = ISNULL(RTRIM(R.ASNReason),'')
            ,@c_WHSERef      = ISNULL(RTRIM(R.WarehouseReference),'')
            ,@c_ShipmentNo   = ISNULL(RTRIM(R.Signatory),'')
            ,@c_CTNType1     = ISNULL(RTRIM(R.CTNType1),'')
            ,@c_PackType1    = ISNULL(RTRIM(R.PackType1),'')
            ,@n_CTNQty1      = ISNULL(R.CTNQty1,0)
            ,@n_CTNCnt1      = ISNULL(R.CTNCnt1,0)
            ,@c_CTNType2     = ISNULL(RTRIM(R.CTNType2),'')
            ,@c_PackType2    = ISNULL(RTRIM(R.PackType2),'')
            ,@n_CTNQty2      = ISNULL(R.CTNQty2,0)
            ,@n_CTNCnt2      = ISNULL(R.CTNCnt2,0)
            ,@c_CTNType3     = ISNULL(RTRIM(R.CTNType3),'')
            ,@c_PackType3    = ISNULL(RTRIM(R.PackType3),'')
            ,@n_CTNQty3      = ISNULL(R.CTNQty3,0)
            ,@n_CTNCnt3      = ISNULL(R.CTNCnt3,0)
            ,@c_CTNType4     = ISNULL(RTRIM(R.CTNType4),'')
            ,@c_PackType4    = ISNULL(RTRIM(R.PackType4),'')
            ,@n_CTNQty4      = ISNULL(R.CTNQty4,0)
            ,@n_CTNCnt4      = ISNULL(R.CTNCnt4,0)
            ,@c_CTNType5     = ISNULL(RTRIM(R.CTNType5),'')
            ,@c_PackType5    = ISNULL(RTRIM(R.PackType5),'')
            ,@n_CTNQty5      = ISNULL(R.CTNQty5,0)
            ,@n_CTNCnt5      = ISNULL(R.CTNCnt5,0)
            ,@c_CTNType6     = ISNULL(RTRIM(R.CTNType6),'')
            ,@c_PackType6    = ISNULL(RTRIM(R.PackType6),'')
            ,@n_CTNQty6      = ISNULL(R.CTNQty6,0)
            ,@n_CTNCnt6      = ISNULL(R.CTNCnt6,0)
            ,@c_CTNType7     = ISNULL(RTRIM(R.CTNType7),'')
            ,@c_PackType7    = ISNULL(RTRIM(R.PackType7),'')
            ,@n_CTNQty7      = ISNULL(R.CTNQty7,0)
            ,@n_CTNCnt7      = ISNULL(R.CTNCnt7,0)
            ,@c_CTNType8     = ISNULL(RTRIM(R.CTNType8),'')
            ,@c_PackType8    = ISNULL(RTRIM(R.PackType8),'')
            ,@n_CTNQty8      = ISNULL(R.CTNQty8,0)
            ,@n_CTNCnt8      = ISNULL(R.CTNCnt8,0)
            ,@c_CTNType9     = ISNULL(RTRIM(R.CTNType9),'')
            ,@c_PackType9    = ISNULL(RTRIM(R.PackType9),'')
            ,@n_CTNQty9      = ISNULL(R.CTNQty9,0)
            ,@n_CTNCnt9      = ISNULL(R.CTNCnt9,0)
            ,@c_CTNType10    = ISNULL(RTRIM(R.CTNType10),'')
            ,@c_PackType10   = ISNULL(RTRIM(R.PackType10),'')
            ,@n_CTNQty10     = ISNULL(R.CTNQty10,0)
            ,@n_CTNCnt10     = ISNULL(R.CTNCnt10,0)
      FROM RECEIPT AS r WITH(NOLOCK)
      WHERE r.ReceiptKey = @c_ReceiptKey
      
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         IF @c_Facility = ''
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 550009
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt #:' + @c_ReceiptKey + '. Facility is required'
                           + '! (lsp_FinalizeReceipt_Wrapper)'
                           + ' |' + @c_ReceiptKey
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --      @c_TableName   = @c_TableName,
            --      @c_SourceType  = @c_SourceType,
            --      @c_Refkey1     = @c_ReceiptKey,
            --      @c_Refkey2     = @c_ReceiptLineNumber,
            --      @c_Refkey3     = '',
            --      @c_WriteType   = 'ERROR',
            --      @n_err2        = @n_err,
            --      @c_errmsg2     = @c_errmsg,
            --      @b_Success     = @b_Success OUTPUT,
            --      @n_err         = @n_err OUTPUT,
            --      @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END

         SET @CUR_RD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.ReceiptLineNumber
         FROM RECEIPT RH WITH (NOLOCK)
         JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RH.ReceiptKey = RD.Receiptkey
         JOIN LOC L WITH (NOLOCK) ON RD.ToLoc = L.Loc
         WHERE RD.Receiptkey = @c_ReceiptKey
         AND   RH.Facility <> L.Facility
         AND   RD.FinalizeFlag <> 'Y'
         ORDER BY RD.ReceiptLineNumber

         OPEN @CUR_RD
         FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 550048
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt To Location Not Belong to Receipt Facility: ' + @c_Facility + ' found'
                           + '! (lsp_FinalizeReceipt_Wrapper)'
                           + ' |' + @c_Facility

            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg)   

            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT,
            --      @c_TableName = @c_TableName,
            --      @c_SourceType  = @c_SourceType,
            --      @c_Refkey1     = @c_ReceiptKey,
            --      @c_Refkey2     = @c_ReceiptLineNo,
            --      @c_Refkey3     = '',
            --      @c_WriteType   = 'ERROR',
            --      @n_err2        = @n_err,
            --      @c_errmsg2     = @c_errmsg,
            --      @b_Success     = @b_Success ,
            --      @n_err         = @n_err ,
            --      @c_errmsg      = @c_errmsg
            --(Wan06) - END
            
            FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNo
         END
         CLOSE @CUR_RD
         DEALLOCATE @CUR_RD

         ---------------------------------------------
         -- Get Storerconfig (START)
         ---------------------------------------------
         IF @c_doctype = 'A'
         BEGIN
            BEGIN TRY
            EXEC nspGetRight
                     @c_Facility = @c_Facility
                  ,  @c_Storerkey= @c_Storerkey
                  ,  @c_Sku      = ''
                  ,  @c_Configkey= 'ShipmentNoConfig'
                  ,  @b_Success  = @b_Success            OUTPUT
                  ,  @c_Authority= @c_ShipmentNoCfg      OUTPUT
                  ,  @n_Err      = @n_Err                OUTPUT
                  ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_err = 550002
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Error Executing nspGetRight - ShipmentNoConfig. (lsp_FinalizeReceipt_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)   
                             
               --EXEC [WM].[lsp_WriteError_List]
               --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               --      @c_TableName   = @c_TableName,
               --      @c_SourceType  = @c_SourceType,
               --      @c_Refkey1     = @c_ReceiptKey,
               --      @c_Refkey2     = @c_ReceiptLineNumber,
               --      @c_Refkey3     = '',
               --      @c_WriteType   = 'ERROR',
               --      @n_err2        = @n_err,
               --      @c_errmsg2     = @c_errmsg,
               --      @b_Success     = @b_Success OUTPUT,
               --      @n_err         = @n_err OUTPUT,
               --      @c_errmsg      = @c_errmsg OUTPUT
               --(Wan06) - END
            END CATCH

            IF @b_success = 0 OR @n_Err <> 0
            BEGIN
               SET @n_continue = 3
            END
         END

         BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'FinalizeASN_ChkPLTLine'                               --(Wan12)
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_FnzChkPltline   OUTPUT
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550003
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - FinalizeASN_ChkPLTLine. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
                           
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)   
                           
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --      @c_TableName   = @c_TableName,
            --      @c_SourceType  = @c_SourceType,
            --      @c_Refkey1     = @c_ReceiptKey,
            --      @c_Refkey2     = @c_ReceiptLineNumber,
            --      @c_Refkey3     = '',
            --      @c_WriteType   = 'ERROR',
            --      @n_err2        = @n_err,
            --      @c_errmsg2     = @c_errmsg,
            --      @b_Success     = @b_Success OUTPUT,
            --      @n_err         = @n_err OUTPUT,
            --      @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
         END

         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'CHKIncomingShelfLife'
               ,  @b_Success  = @b_Success               OUTPUT
               ,  @c_Authority= @c_CHKIncomingShelfLife  OUTPUT
               ,  @n_Err      = @n_Err                   OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg                OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550004
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - CHKIncomingShelfLife. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'

            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --      @c_TableName   = @c_TableName,
            --      @c_SourceType  = @c_SourceType,
            --      @c_Refkey1     = @c_ReceiptKey,
            --      @c_Refkey2     = @c_ReceiptLineNumber,
            --      @c_Refkey3     = '',
            --      @c_WriteType   = 'ERROR',
            --      @n_err2        = @n_err,
            --      @c_errmsg2     = @c_errmsg,
            --      @b_Success     = @b_Success OUTPUT,
            --      @n_err         = @n_err OUTPUT,
            --      @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
         END

         IF @c_CHKIncomingShelfLife <> ''
         BEGIN
            SET @b_ChkShelfLife = 0
            SELECT TOP 1 @b_ChkShelfLife = 1
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_CHKIncomingShelfLife
            AND   ((CL.Storerkey= @c_Storerkey
            AND     CL.Code = @c_RecType)
            OR     (CL.Storerkey= ''
            AND     CL.Code = @c_RecType))
            ORDER BY CL.Storerkey DESC
         END

         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'CHKIncomingIVAS'
               ,  @b_Success  = @b_Success         OUTPUT
               ,  @c_Authority= @c_CHKIncomingIVAS OUTPUT
               ,  @n_Err      = @n_Err             OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550005
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - CHKIncomingIVAS. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'

            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)   
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --      @c_TableName   = @c_TableName,
            --      @c_SourceType  = @c_SourceType,
            --      @c_Refkey1     = @c_ReceiptKey,
            --      @c_Refkey2     = @c_ReceiptLineNumber,
            --      @c_Refkey3     = '',
            --      @c_WriteType   = 'ERROR',
            --      @n_err2        = @n_err,
            --      @c_errmsg2     = @c_errmsg,
            --      @b_Success     = @b_Success OUTPUT,
            --      @n_err         = @n_err OUTPUT,
            --      @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
         END

         IF @c_CHKIncomingIVAS <> ''
         BEGIN
            SET @b_ChkIVAS = 0
            SELECT TOP 1 @b_ChkIVAS = 1
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = @c_CHKIncomingIVAS
            AND   ((CL.Storerkey= @c_Storerkey
            AND     CL.Code = @c_RecType)
            OR     (CL.Storerkey= ''
            AND     CL.Code = @c_RecType))
            ORDER BY CL.Storerkey DESC
         END

         IF @n_continue = 3
         BEGIN
            GOTO EXIT_SP
         END

         ---------------------------------------------
         -- Get Storerconfig (END)
         -- Proceed Question If @n_continue<>3 (START)
         ---------------------------------------------

         IF @c_ShipmentNoCfg = '1'  AND @c_ShipmentNo = ''
         BEGIN
            SET @c_ErrMsg  = 'Shipment Number Empty. Do you still want to proceed finalize?' --JSM-52407
                        
            --(Wan06) - START
            SET @n_WarningNo = 1
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)
            --(Wan06) - END   
         END

         SET @c_ReceiptLineNo = ''
         --SET @c_ASNReason = ''                                                    --(Wan15)
         WHILE 1 = 1
         BEGIN
            SET @c_Toloc     = ''
            SET @c_ToID      = ''
			
            SET @c_POKey     = ''
            SET @c_ExternReceiptKey = ''
            SELECT TOP 1                                                            --(Wan07)
                   @c_ReceiptLineNo      = RD.ReceiptLineNumber
                  ,@c_Storerkey          = RD.Storerkey
                  ,@c_Sku                = RTRIM(RD.Sku)
                  ,@n_QtyExpected        = ISNULL(RD.QtyExpected,0)
                  ,@n_BeforeReceivedQty  = ISNULL(RD.BeforeReceivedQty,0)
                  ,@n_FreeGoodQtyReceived= ISNULL(RD.FreeGoodQtyReceived,0)
                  ,@c_Toloc              = ISNULL(RTRIM(RD.ToLoc),'')
                  ,@c_ToID               = ISNULL(RTRIM(RD.ToID),'')
                  ,@c_ExternReceiptKey   = ISNULL(RTRIM(RD.ExternReceiptKey),'')
                  ,@c_ExternLineNo       = ISNULL(RTRIM(RD.ExternLineNo),'')
                  ,@c_POKey              = ISNULL(RTRIM(RD.POkey),'')
                  --,@c_ASNReason          = ISNULL(RTRIM(RD.UserDefine03),'')      --(Wan15)
                  ,@dt_Lottable04        = ISNULL(RTRIM(RD.Lottable04),'')
                  ,@dt_Lottable05        = ISNULL(RTRIM(RD.Lottable05),'')
            FROM @tRECEIPTDETAIL t
            JOIN RECEIPTDETAIL RD ON  t.ReceiptKey = RD.ReceiptKey
                                  AND t.ReceiptLineNumber = RD.ReceiptLineNumber
            WHERE RD.ReceiptLineNumber >  @c_ReceiptLineNo
            AND    RD.FinalizeFlag <> 'Y'
            ORDER BY RD.ReceiptLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            SET @n_SumBeforeReceivedQty = @n_SumBeforeReceivedQty + @n_BeforeReceivedQty
            SET @n_SumFreeGoodQtyReceived  = @n_SumFreeGoodQtyReceived + @n_FreeGoodQtyReceived

            SET @n_TOLPCT = 0.00
            SET @n_ShelfLife = 0.00
            SET @c_SkuIVAS  = ''
            SELECT @n_TOLPCT    = CASE WHEN ISNUMERIC(S.SUSR4) = 1 THEN CONVERT(DECIMAL(8,2),S.SUSR4) ELSE -1.00 END --(Wan02)
                  ,@n_ShelfLife = CASE WHEN ISNUMERIC(S.SUSR1) = 1 THEN CONVERT(FLOAT,S.SUSR1) ELSE -1.00 END        --(Wan02)
                  ,@c_SkuIVAS = ISNULL(RTRIM(IVAS),'')
                  ,@c_Packkey = S.PACKKey
            FROM SKU S WITH (NOLOCK)
            WHERE S.Storerkey = @c_Storerkey
            AND S.Sku = @c_Sku

            IF @c_FnzChkPltline = '1' --AND @c_ToID = ''                            --(Wan12)
            BEGIN
               SELECT @n_Pallet = P.Pallet
               FROM PACK P WITH (NOLOCK)
               WHERE P.Packkey = @c_Packkey

               IF @n_Pallet > 0 AND @n_BeforeReceivedQty > @n_Pallet
               BEGIN
                  SET @c_ErrMsg  = 'Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo + ' Not Yet Explode to Pallet'
                                 + '. Continue to Proceed finalize?'
                  --(Wan06) - START
                  SET @n_WarningNo = 1
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)
                  
                  --EXEC [WM].[lsp_WriteError_List]
                  --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  --   ,  @c_TableName   = @c_TableName
                  --   ,  @c_SourceType  = @c_SourceType
                  --   ,  @c_Refkey1     = @c_Receiptkey
                  --   ,  @c_Refkey2     = @c_ReceiptLineNo
                  --   ,  @c_Refkey3   = ''
                  --   ,  @c_WriteType   = 'QUESTION'
                  --   ,  @n_err2        = @n_err
                  --   ,  @c_errmsg2     = @c_errmsg
                  --   ,  @b_Success     = @b_Success   OUTPUT
                  --   ,  @n_err         = @n_err       OUTPUT
                  --   ,  @c_errmsg      = @c_errmsg    OUTPUT
                  --(Wan06) - END   
               END
            END
            
            IF @b_ChkShelfLife = 1 AND @n_ShelfLife >= 0 AND DATEDIFF(day, @dt_Lottable04, @dt_Lottable05) < @n_ShelfLife
            BEGIN
               SET @c_ErrMsg  = 'Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo + ', Sku: ' + @c_Sku
                              + ' does not pass Sku Incoming Shelf Life Validation. Sku Shelf Life: ' + CONVERT(NVARCHAR(10), @n_ShelfLife)
                              + '. Continue to Proceed finalize?'

               --(Wan06) - START
               SET @n_WarningNo = 1
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)

               --EXEC [WM].[lsp_WriteError_List]
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_Receiptkey
               --   ,  @c_Refkey2     = @c_ReceiptLineNo
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'QUESTION'
               --   ,  @n_err2        = @n_err
               --   ,  @c_errmsg2     = @c_errmsg
               --   ,  @b_Success     = @b_Success   OUTPUT
               --   ,  @n_err         = @n_err       OUTPUT
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               --(Wan06) - END
            END

            IF @b_ChkIVAS = 1 AND @c_SkuIVAS <> ''
            BEGIN
               SET @c_ErrMsg  = 'Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo + ', Sku: ' + @c_Sku
                              + ' does not pass Sku Incoming VAS Validation. Sku IVAS: ' + @c_SkuIVAS
                              + '. Continue to Proceed finalize?'

               --(Wan06) - START
               SET @n_WarningNo = 1
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)

               --EXEC [WM].[lsp_WriteError_List]
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_Receiptkey
               --   ,  @c_Refkey2     = @c_ReceiptLineNo
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'QUESTION'
               --   ,  @n_err2        = @n_err
               --   ,  @c_errmsg2     = @c_errmsg
               --   ,  @b_Success     = @b_Success   OUTPUT
               --   ,  @n_err         = @n_err       OUTPUT
               --   ,  @c_errmsg     = @c_errmsg    OUTPUT
               --(Wan06) - END
            END
         END

         IF @n_SumBeforeReceivedQty = 0
         BEGIN
            SET @c_ErrMsg = 'Zero Total Quantity to Receive.  Continue to Proceed finalize Receipt #: ' + @c_Receiptkey + '?'

            --(Wan06) - START
            SET @n_WarningNo = 1
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_Receiptkey
            --   ,  @c_Refkey2     = @c_ReceiptLineNumber
            --   ,  @c_Refkey3     = ''
            --   ,  @c_WriteType   = 'QUESTION'
            --   ,  @n_err2        = @n_err
            --   ,  @c_errmsg2     = @c_errmsg
            --   ,  @b_Success     = @b_Success   OUTPUT
            --   ,  @n_err         = @n_err       OUTPUT
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT
            --(Wan06) - END
         END

         IF @n_SumBeforeReceivedQty = 0 AND @n_SumFreeGoodQtyReceived = 0
         BEGIN
            SET @c_ErrMsg = 'Neither Zero Quantity nor Zero Free Good Qty to Receive. Continue to Proceed finalize Receipt #: ' + @c_Receiptkey + '?'
            --(Wan06) - START
            SET @n_WarningNo = 1
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)
            --EXEC [WM].[lsp_WriteError_List]
            --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            --   ,  @c_TableName   = @c_TableName
            --   ,  @c_SourceType  = @c_SourceType
            --   ,  @c_Refkey1     = @c_Receiptkey
            --   ,  @c_Refkey2     = @c_ReceiptLineNumber
            --   ,  @c_Refkey3     = ''
            --   ,  @c_WriteType   = 'QUESTION'
            --   ,  @n_err2        = @n_err
            --   ,  @c_errmsg2     = @c_errmsg
            --   ,  @b_Success     = @b_Success   OUTPUT
            --   ,  @n_err         = @n_err       OUTPUT
            --   ,  @c_errmsg      = @c_errmsg    OUTPUT
            --(Wan06) - END
         END

         --(Wan06) - START
         --SET @n_WarningNo = 1
         --SET @c_ErrMsg = 'Finalize Receiptkey: ' + @c_Receiptkey + '?'

         --EXEC [WM].[lsp_WriteError_List]
         --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
         --   ,  @c_TableName   = @c_TableName
         --   ,  @c_SourceType  = @c_SourceType
         --   ,  @c_Refkey1     = @c_Receiptkey
         --   ,  @c_Refkey2     = ''
         --   ,  @c_Refkey3     = ''
         --   ,  @c_WriteType   = 'QUESTION'
         --   ,  @n_err2        = @n_err
         --   ,  @c_errmsg2     = @c_errmsg
         --   ,  @b_Success     = @b_Success   OUTPUT
         --   ,  @n_err         = @n_err       OUTPUT
         --   ,  @c_errmsg      = @c_errmsg    OUTPUT
         --(Wan06) - END
         IF @n_WarningNo = 1
         BEGIN
            GOTO EXIT_SP
         END
         ---------------------------------------------
         -- Proceed Question If @n_continue<>3 (END)
         ---------------------------------------------
      END
      --(Wan04) - START
      IF @n_WarningNo < 2
      BEGIN
         SELECT @c_MUID = ISNULL(RTRIM(nsqlvalue),'')
         FROM NSQLCONFIG WITH (NOLOCK)
         WHERE ConfigKey = 'MUID_Enable'

         SELECT @c_FinalizeASNPromptSaveID  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeASNPromptSaveID')
         SELECT @c_GenID  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'GenID')
         SELECT @c_RF_Enable  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'RF_Enable')

         SET @n_SkipGenID = 1

         --IF @c_FinalizeASNPromptSaveID = '1' AND ((@c_MUID = '1' AND @c_GenID = '1') OR @c_RF_Enable <> '1')   -- JSM-5512
         IF (@c_MUID = '1' AND @c_GenID = '1') OR @c_RF_Enable <> '1'                                            -- JSM-5512
         BEGIN
            SET @n_SkipGenID = 0

            IF @c_FinalizeASNPromptSaveID = '1'                                           --JSM-5512
            BEGIN
               SET @n_WarningNo = 2

               SET @c_ErrMsg = 'Skip Generate Pallet ID for Receipt #: ' + @c_Receiptkey + '?'
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'QUESTION', @n_WarningNo, 0, @c_errmsg)
               --EXEC [WM].[lsp_WriteError_List]
               --      @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               --   ,  @c_TableName   = @c_TableName
               --   ,  @c_SourceType  = @c_SourceType
               --   ,  @c_Refkey1     = @c_Receiptkey
               --   ,  @c_Refkey2     = ''
               --   ,  @c_Refkey3     = ''
               --   ,  @c_WriteType   = 'QUESTION'
               --   ,  @n_err2        = @n_err
               --   ,  @c_errmsg2     = @c_errmsg
               --   ,  @b_Success     = @b_Success   OUTPUT
               --   ,  @n_err         = @n_err       OUTPUT
               --   ,  @c_errmsg      = @c_errmsg    OUTPUT
               --(Wan06) - END
               GOTO EXIT_SP
            END                                                  --JSM-5512
         END
      END
      --(Wan04) - END
      -------------------------------------------------
      -- PreFinalze Receipt Validation (START)
      -------------------------------------------------
      --IF @c_ASNStatus = '9'
      --BEGIN
      --   SET @n_continue= 3
      --   SET @n_err     = 550006
      --   SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
      --                  + ': Receipt #:' + @c_ReceiptKey + ' Has Been Closed'
      --                  + '. Not Allow To Finalize. (lsp_FinalizeReceipt_Wrapper)'

      --   EXEC [WM].[lsp_WriteError_List]
      --         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT,
      --         @c_TableName   = @c_TableName,
      --         @c_SourceType  = @c_SourceType,
      --         @c_Refkey1     = @c_ReceiptKey,
      --    @c_Refkey2     = @c_ReceiptLineNumber,
      --         @c_Refkey3     = '',
      --         @c_WriteType   = 'ERROR',
      --         @n_err2        = @n_err,
      --         @c_errmsg2     = @c_errmsg,
      --         @b_Success     = @b_Success OUTPUT,
      --         @n_err         = @n_err OUTPUT,
      --         @c_errmsg      = @c_errmsg OUTPUT
      --END
      --ELSE IF @c_ASNStatus = 'CANC'
      IF @c_ASNStatus = 'CANC'
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 550007
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Receipt #:' + @c_ReceiptKey + ' Has been Cancelled'
                        + '. Not Allow To To Finalize. (lsp_FinalizeReceipt_Wrapper)'

         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)
         --EXEC [WM].[lsp_WriteError_List]
         --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --      @c_TableName   = @c_TableName,
         --      @c_SourceType  = @c_SourceType,
         --      @c_Refkey1     = @c_ReceiptKey,
         --      @c_Refkey2     = @c_ReceiptLineNumber,
         --      @c_Refkey3     = '',
         --      @c_WriteType   = 'ERROR',
         --      @n_err2        = @n_err,
         --      @c_errmsg2     = @c_errmsg,
         --      @b_Success     = @b_Success OUTPUT,
         --      @n_err         = @n_err OUTPUT,
         --      @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END
      ELSE IF @c_ASNStatus is NULL
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 550008
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Receipt #:' + @c_ReceiptKey + '. Receiptkey Or ReceiptLineNo Not Exists'
                        + '! (lsp_FinalizeReceipt_Wrapper)'

         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)
         --EXEC [WM].[lsp_WriteError_List]
         --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --      @c_TableName   = @c_TableName,
         --      @c_SourceType  = @c_SourceType,
         --      @c_Refkey1     = @c_ReceiptKey,
         --      @c_Refkey2     = @c_ReceiptLineNumber,
         --      @c_Refkey3     = '',
         --      @c_WriteType   = 'ERROR',
         --      @n_err2        = @n_err,
         --      @c_errmsg2     = @c_errmsg,
         --      @b_Success     = @b_Success OUTPUT,
         --      @n_err         = @n_err OUTPUT,
         --      @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'ChkASNVarianceTolerance'
            ,  @b_Success  = @b_Success      OUTPUT
            ,  @c_Authority= @c_ChkASNVarTol OUTPUT
            ,  @n_Err      = @n_Err          OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg       OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550001
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - ChkASNVarianceTolerance. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH
	   IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'ASN_UDF01_InvoiceNo_Required'
            ,  @b_Success  = @b_Success   OUTPUT
            ,  @c_Authority= @c_UDF01Req  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

      END TRY

      BEGIN CATCH
         SET @n_err = 550010
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspg_GetKey - ASN_UDF01_InvoiceNo_Required. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --(Wan06) - END
      END

      IF @c_UDF01Req = '1' AND @c_UserDefine01 = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550011
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Receipt #:' + @c_ReceiptKey + '. Invoice No is required'
                        + '. (Receipt UserDefine01)! (lsp_FinalizeReceipt_Wrapper)'
                        + ' |' + @c_ReceiptKey
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'ASNHdRsn'
            ,  @b_Success  = @b_Success   OUTPUT
            ,  @c_Authority= @c_AsnHdRsn  OUTPUT
            ,  @n_Err      = @n_Err       OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550012
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - ASNHdrRsn. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END

      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --(Wan06) - END
      END

      IF @c_AsnHdRsn = '1' AND @c_UserDefine02 = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 550013
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Receipt #:' + @c_ReceiptKey + '. Header Reason is required (Receipt UserDefine02)'
                        + '! (lsp_FinalizeReceipt_Wrapper)'
                        + ' |' + @c_ReceiptKey
                        
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'AllowOneASNPerPO'
            ,  @b_Success  = @b_Success            OUTPUT
            ,  @c_Authority= @c_AllowOneASNPerPO   OUTPUT
            ,  @n_Err      = @n_Err      OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550014
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - AllowOneASNPerPO. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --      @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --      @c_TableName   = @c_TableName,
         --      @c_SourceType  = @c_SourceType,
         --      @c_Refkey1     = @c_ReceiptKey,
         --      @c_Refkey2     = @c_ReceiptLineNumber,
         --      @c_Refkey3     = '',
         --      @c_WriteType   = 'ERROR',
         --      @n_err2        = @n_err,
         --      @c_errmsg2     = @c_errmsg,
         --      @b_Success     = @b_Success OUTPUT,
         --      @n_err         = @n_err OUTPUT,
         --      @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) -END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
         --(Wan06) -END
      END

      --JSM-56642 Start
      IF @c_AllowOneASNPerPO = 1
      BEGIN
         DECLARE @c_ReceiptKey2 NVARCHAR(10)
            
         SET @c_ReceiptKey2 = ''
            
         SELECT @c_ReceiptKey2 = ISNULL(TRIM(R2.Receiptkey),'') -- Leong01
         FROM RECEIPT R WITH (NOLOCK)              
         JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)              
         JOIN PO PO WITH (NOLOCK) ON (R.ExternReceiptKey = PO.ExternPOKey AND RD.POKey = PO.POKey)  
         LEFT OUTER JOIN RECEIPT R2 WITH (NOLOCK) ON (R2.ExternReceiptKey = PO.ExternPOKey AND
                                                                        R2.StorerKey = R.StorerKey AND
                                                                        R2.Receiptkey <> R.Receiptkey)                      
         WHERE R.ReceiptKey = @c_ReceiptKey  
         AND   R.StorerKey = @c_Storerkey
           
         IF @c_ReceiptKey2 <> ''
         BEGIN
            SET @n_continue= 3
            SET @n_err     = 550049
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + 'Only Allow One PO For One ASN'
                           + 'ExternPoKey existed in Receipt #:' + @c_ReceiptKey + ' (lsp_FinalizeReceipt_Wrapper) |' + @c_ReceiptKey
               
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_Storerkey, '', 'ERROR', 0, @n_err, @c_errmsg)
         END
      END
      --JSM-56642 End      

      IF @c_doctype = 'A'
      BEGIN
         BEGIN TRY
         EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'RcptWHRef'
               ,  @b_Success  = @b_Success            OUTPUT
               ,  @c_Authority= @c_RcptWHRef          OUTPUT
               ,  @n_Err      = @n_Err                OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550015
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - RcptWHRef. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
            --(Wan06) - START
            --EXEC [WM].[lsp_WriteError_List]
            --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --            @c_TableName   = @c_TableName,
            --            @c_SourceType  = @c_SourceType,
            --            @c_Refkey1     = @c_ReceiptKey,
            --            @c_Refkey2     = @c_ReceiptLineNumber,
            --            @c_Refkey3     = '',
            --            @c_WriteType   = 'ERROR',
            --            @n_err2        = @n_err,
            --            @c_errmsg2     = @c_errmsg,
            --            @b_Success     = @b_Success OUTPUT,
            --            @n_err         = @n_err OUTPUT,
            --            @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) -END
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
            --(Wan06) -END
         END

         IF  @c_WHSERef = ''
         BEGIN
            IF @c_RCPTWHREF = '1'
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 550016
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Receipt #:' + @c_ReceiptKey + '. Warehouse Reference is Required Before Finalise'
                              + '! (lsp_FinalizeReceipt_Wrapper)'
                              + ' |' + @c_ReceiptKey
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)               
               --EXEC [WM].[lsp_WriteError_List]
               --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               --            @c_TableName   = @c_TableName,
               --            @c_SourceType  = @c_SourceType,
               --            @c_Refkey1     = @c_ReceiptKey,
               --            @c_Refkey2     = @c_ReceiptLineNumber,
               --            @c_Refkey3     = '',
               --            @c_WriteType   = 'ERROR',
               --            @n_err2        = @n_err,
               --            @c_errmsg2     = @c_errmsg,
               --            @b_Success     = @b_Success OUTPUT,
               --            @n_err         = @n_err OUTPUT,
               --            @c_errmsg      = @c_errmsg OUTPUT
               --(Wan06) - END
            END

            BEGIN TRY
            EXEC nspGetRight
                     @c_Facility = @c_Facility
                  ,  @c_Storerkey= @c_Storerkey
                  ,  @c_Sku      = ''
                  ,  @c_Configkey= 'UTLITF'
                  ,  @b_Success  = @b_Success            OUTPUT
                  ,  @c_Authority= @c_UTLITF             OUTPUT
                  ,  @n_Err      = @n_Err                OUTPUT
                  ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
            END TRY

            BEGIN CATCH
               SET @n_err = 550017
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Error Executing nspGetRight - UTLITF. (lsp_FinalizeReceipt_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               --(Wan06) - START
               --EXEC [WM].[lsp_WriteError_List]
               --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               --            @c_TableName   = @c_TableName,
               --            @c_SourceType  = @c_SourceType,
               --            @c_Refkey1     = @c_ReceiptKey,
               --            @c_Refkey2     = @c_ReceiptLineNumber,
               --            @c_Refkey3     = '',
               --            @c_WriteType   = 'ERROR',
               --            @n_err2        = @n_err,
               --            @c_errmsg2     = @c_errmsg,
               --            @b_Success     = @b_Success OUTPUT,
               --            @n_err         = @n_err OUTPUT,
               --            @c_errmsg      = @c_errmsg OUTPUT
               --(Wan06) - END
            END CATCH

            IF @b_success = 0 OR @n_Err <> 0
            BEGIN
               SET @n_continue = 3
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
               --(Wan06) - END               
            END

            IF @c_UTLITF = '1'
            BEGIN
               IF @c_rectype IN ('UTL3PL','UTLIMP')
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 550018
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                 + ': Receipt #:' + @c_ReceiptKey + '. Agency Code Is Required Before Finalise'
                                 + '! (lsp_FinalizeReceipt_Wrapper)'
                                 + ' |' + @c_ReceiptKey
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
                  --EXEC [WM].[lsp_WriteError_List]
                  --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  --            @c_TableName   = @c_TableName,
                  --            @c_SourceType  = @c_SourceType,
                  --            @c_Refkey1     = @c_ReceiptKey,
                  --            @c_Refkey2     = @c_ReceiptLineNumber,
                  --            @c_Refkey3     = '',
                  --            @c_WriteType   = 'ERROR',
                  --            @n_err2        = @n_err,
                  --            @c_errmsg2     = @c_errmsg,
                  --            @b_Success     = @b_Success OUTPUT,
                  --            @n_err         = @n_err OUTPUT,
                  --            @c_errmsg      = @c_errmsg OUTPUT
                  --(Wan06) - END
               END

               IF @c_ASNReason <> '81'
               BEGIN
                  SET @b_InvHoldlot = 1
               END

            END
         END

         IF @b_InvHoldlot = 1 AND @c_ASNReason = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 550019
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt #:' + @c_ReceiptKey +'. Header Reason Code is required'
                           + '. (lsp_FinalizeReceipt_Wrapper)'
                           + ' |' + @c_ReceiptKey
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
            --EXEC [WM].[lsp_WriteError_List]
            --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --            @c_TableName   = @c_TableName,
            --            @c_SourceType  = @c_SourceType,
            --            @c_Refkey1     = @c_ReceiptKey,
            --            @c_Refkey2     = @c_ReceiptLineNumber,
            --            @c_Refkey3     = '',
            --            @c_WriteType   = 'ERROR',
            --            @n_err2        = @n_err,
            --            @c_errmsg2     = @c_errmsg,
            --            @b_Success     = @b_Success OUTPUT,
            --            @n_err         = @n_err OUTPUT,
            --            @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END
      END

      IF @c_doctype IN ('A', 'X')
      BEGIN
         IF @dt_DeliveryDate > GETDATE()
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 550020
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt #:' + @c_ReceiptKey +'. Invalid Delivery Date'
                           + '. Must not be greater than current date. (lsp_FinalizeReceipt_Wrapper)'
                           + ' |' + @c_ReceiptKey
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
            --EXEC [WM].[lsp_WriteError_List]
            --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --            @c_TableName   = @c_TableName,
            --            @c_SourceType  = @c_SourceType,
            --            @c_Refkey1     = @c_ReceiptKey,
            --            @c_Refkey2     = @c_ReceiptLineNumber,
            --            @c_Refkey3     = '',
            --            @c_WriteType   = 'ERROR',
            --            @n_err2        = @n_err,
            --            @c_errmsg2     = @c_errmsg,
            --            @b_Success     = @b_Success OUTPUT,
            --            @n_err         = @n_err OUTPUT,
            --            @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END
      END

      IF @c_doctype IN ('A', 'R')
      BEGIN
        BEGIN TRY
         EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'CTNTYPETAB'
               ,  @b_Success  = @b_Success            OUTPUT
               ,  @c_Authority= @c_CTNTypeTab         OUTPUT
               ,  @n_Err      = @n_Err                OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550021
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - CTNTypeTab. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
            --(Wan06) - START
            --EXEC [WM].[lsp_WriteError_List]
            --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
            --            @c_TableName   = @c_TableName,
            --            @c_SourceType  = @c_SourceType,
            --            @c_Refkey1     = @c_ReceiptKey,
            --            @c_Refkey2     = @c_ReceiptLineNumber,
            --            @c_Refkey3     = '',
            --            @c_WriteType   = 'ERROR',
            --            @n_err2        = @n_err,
            --            @c_errmsg2     = @c_errmsg,
            --            @b_Success     = @b_Success OUTPUT,
            --            @n_err         = @n_err OUTPUT,
            --            @c_errmsg      = @c_errmsg OUTPUT
            --(Wan06) - END
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
            --(Wan06) - END
         END

         IF @c_CTNTypeTab = '1'
         BEGIN
            SET @n_Cnt = 1
            WHILE @n_Cnt <= 10
            BEGIN
               SET @c_CTNType = CASE @n_Cnt  WHEN 1  THEN @c_CTNType1
                                             WHEN 2  THEN @c_CTNType2
                                             WHEN 3  THEN @c_CTNType3
                                             WHEN 4  THEN @c_CTNType4
                                             WHEN 5  THEN @c_CTNType5
                                             WHEN 6  THEN @c_CTNType6
                                             WHEN 7  THEN @c_CTNType7
                                             WHEN 8  THEN @c_CTNType8
                                             WHEN 9  THEN @c_CTNType9
                                             WHEN 10 THEN @c_CTNType10
                                             END
               SET @c_PackType = CASE @n_Cnt WHEN 1  THEN @c_PackType1
                                             WHEN 2  THEN @c_PackType2
                                             WHEN 3  THEN @c_PackType3
                                             WHEN 4  THEN @c_PackType4
                                             WHEN 5  THEN @c_PackType5
                                             WHEN 6  THEN @c_PackType6
                                             WHEN 7  THEN @c_PackType7
                                             WHEN 8  THEN @c_PackType8
                                             WHEN 9  THEN @c_PackType9
                                             WHEN 10 THEN @c_PackType10
                                             END

               SET @n_CTNQty = CASE @n_Cnt   WHEN 1  THEN @n_CTNQty1
                                             WHEN 2  THEN @n_CTNQty2
                                             WHEN 3  THEN @n_CTNQty3
                                             WHEN 4  THEN @n_CTNQty4
                                             WHEN 5  THEN @n_CTNQty5
                                             WHEN 6  THEN @n_CTNQty6
                                             WHEN 7  THEN @n_CTNQty7
                                             WHEN 8  THEN @n_CTNQty8
                                             WHEN 9  THEN @n_CTNQty9
                                             WHEN 10 THEN @n_CTNQty10
                                             END

               SET @n_CTNCnt = CASE @n_Cnt   WHEN 1  THEN @n_CTNCnt1
                                             WHEN 2  THEN @n_CTNCnt2
                                             WHEN 3  THEN @n_CTNCnt3
                                             WHEN 4  THEN @n_CTNCnt4
                                             WHEN 5  THEN @n_CTNCnt5
                                             WHEN 6  THEN @n_CTNCnt6
                                             WHEN 7  THEN @n_CTNCnt7
                                             WHEN 8  THEN @n_CTNCnt8
                                             WHEN 9  THEN @n_CTNCnt9
                                             WHEN 10 THEN @n_CTNCnt10
                                             END
               IF @c_CTNType <> '' AND @c_PackType <> '' AND  @n_CTNQty > 0 AND @n_CTNCnt > 0
               BEGIN
                  SET @b_FullCTNInfo = 1
               END
               ELSE
               BEGIN
                  IF @c_CTNType <> '' OR @c_PackType <> '' OR  @n_CTNQty > 0 OR @n_CTNCnt > 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_err = 550022
                     SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                    + ': Receipt #:' + @c_ReceiptKey +'. Carton Group, Carton/Mini Pack'
                                    + ',Unit/Cnt And Carton Qty Are Required When Any of These Columes Has Value'
                                    + '.(lsp_FinalizeReceipt_Wrapper)'
                                    + ' |' + @c_ReceiptKey
                     --(Wan06) - START
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                     VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
                     --EXEC [WM].[lsp_WriteError_List]
                     --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                     --            @c_TableName   = @c_TableName,
                     --            @c_SourceType  = @c_SourceType,
                     --            @c_Refkey1     = @c_ReceiptKey,
                     --            @c_Refkey2     = @c_ReceiptLineNumber,
                     --            @c_Refkey3     = '',
                     --            @c_WriteType   = 'ERROR',
                     --            @n_err2        = @n_err,
                     --            @c_errmsg2     = @c_errmsg,
                     --            @b_Success     = @b_Success OUTPUT,
                     --            @n_err         = @n_err OUTPUT,
                     --            @c_errmsg      = @c_errmsg OUTPUT
                     --(Wan06) - END
                  END
               END
               SET @n_Cnt = @n_Cnt + 1
            END

            IF @b_FullCTNInfo = 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 550023
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Receipt #:' + @c_ReceiptKey +'. At Least One Of The Carton Type'
                              + ',Carton/Mini Pack,Unit/Cnt And Carton Qty Are Required'
                              + '.(lsp_FinalizeReceipt_Wrapper)'
                              + ' |' + @c_ReceiptKey
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
               --EXEC [WM].[lsp_WriteError_List]
               --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               --            @c_TableName   = @c_TableName,
               --            @c_SourceType  = @c_SourceType,
               --            @c_Refkey1     = @c_ReceiptKey,
               --            @c_Refkey2     = @c_ReceiptLineNumber,
               --            @c_Refkey3     = '',
               --            @c_WriteType   = 'ERROR',
               --            @n_err2        = @n_err,
               --            @c_errmsg2     = @c_errmsg,
               --            @b_Success     = @b_Success OUTPUT,
               --            @n_err         = @n_err OUTPUT,
               --            @c_errmsg      = @c_errmsg OUTPUT
               --(Wan06) - END
            END
         END
      END

      SET @c_UserDefine01 = ''
      SELECT @c_UserDefine01 = ISNULL(RTRIM(F.UserDefine01),'')
      FROM FACILITY F WITH (NOLOCK)
      WHERE F.Facility = @c_Facility

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'CrossWH'
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_CrossWH         OUTPUT
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550024
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - CrossWH. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'AsnDetRsn'
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_ASNDetRSN       OUTPUT                              --(Wan15)
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550025
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - ASNDetRsn. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)  
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'UCCTracking'
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_UCCTracking     OUTPUT
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg  OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550026
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - UCCTracking. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg)                         
         --(Wan06) - END
      END

      IF @c_UCCTracking = '1'
      BEGIN
         SET @c_UCCTrackValue = ''
         SELECT TOP 1 @c_UCCTrackValue = ISNULL(CL.Short,'')   --(Wan05)
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = 'RecType'                         --(Wan05)
         AND   ((CL.Storerkey= @c_Storerkey
         AND     CL.Code = @c_RecType)
         OR     (CL.Storerkey= ''
         AND     CL.Code = @c_RecType))
         ORDER BY CL.Storerkey DESC
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'NikeRegITF'
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_NikeRegITF      OUTPUT
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550027
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
            + ': Error Executing nspGetRight - NikeRegITF. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
         --(Wan06) - END
      END

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'ByPassTolerance'
            ,  @b_Success  = @b_Success            OUTPUT
            ,  @c_Authority= @c_ByPassTol          OUTPUT
            ,  @n_Err      = @n_Err                OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550028
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - ByPassTolerance. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
         --(Wan06) - START
         --EXEC [WM].[lsp_WriteError_List]
         --            @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
         --            @c_TableName   = @c_TableName,
         --            @c_SourceType  = @c_SourceType,
         --            @c_Refkey1     = @c_ReceiptKey,
         --            @c_Refkey2     = @c_ReceiptLineNumber,
         --            @c_Refkey3     = '',
         --            @c_WriteType   = 'ERROR',
         --            @n_err2        = @n_err,
         --            @c_errmsg2     = @c_errmsg,
         --            @b_Success     = @b_Success OUTPUT,
         --            @n_err         = @n_err OUTPUT,
         --            @c_errmsg      = @c_errmsg OUTPUT
         --(Wan06) - END
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
         --(Wan06) - END
      END
      --(Wan10) - START
      SELECT @c_DisAllowDuplicateIdsOnWSRcpt = fgr.Authority
            ,@c_DisAllowDupIDsOnWSRcpt_Option5 = fgr.Option5
      FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'DisAllowDuplicateIdsOnWSRcpt') AS fgr      ---(Wan08)
      
      SELECT @c_UniqueIDSkipDocType = dbo.fnc_GetParamValueFromString('@c_UniqueIDSkipDocType', @c_DisAllowDupIDsOnWSRcpt_Option5, @c_UniqueIDSkipDocType)
      IF @c_DisAllowDuplicateIdsOnWSRcpt = '1' AND CHARINDEX(@c_DocType, @c_UniqueIDSkipDocType, 1) > 0
      BEGIN 
         SET @c_DisAllowDuplicateIdsOnWSRcpt = '0'
      END 
      -- (Wan10) - END
      --(Wan11) - START
      IF @c_DisAllowDuplicateIdsOnWSRcpt = '1'
      BEGIN
         SET @c_AllowDupWithinPLTCnt = 'N'
         SELECT @c_AllowDupWithinPLTCnt = dbo.fnc_GetParamValueFromString('@c_AllowDupWithinPLTCnt', @c_DisAllowDupIDsOnWSRcpt_Option5, @c_AllowDupWithinPLTCnt)
      END
      --(Wan11) - END
 
      SET @c_ReceiptLineNo = ''
      WHILE 1 = 1
      BEGIN
         SET @c_Toloc     = ''
         SET @c_ToID      = ''
         SET @c_ASNReason = ''
         SET @c_POKey     = ''
         SET @c_ExternReceiptKey = ''
         SELECT TOP 1                                                               --(Wan07)
                @c_ReceiptLineNo      = RD.ReceiptLineNumber
               ,@c_Storerkey          = RD.Storerkey
               ,@c_Sku                = RD.Sku
               ,@n_BeforeReceivedQty  = ISNULL(RD.BeforeReceivedQty,0)
               ,@n_QtyExpected        = ISNULL(RD.QtyExpected,0)
               ,@c_Toloc              = ISNULL(RTRIM(RD.ToLoc),'')
               ,@c_ExternLineNo       = ISNULL(RTRIM(RD.ExternLineNo),'')
               ,@c_ASNReason          = ISNULL(RTRIM(RD.UserDefine03),'')
               ,@c_ToID               = ISNULL(RD.ToId,'')                           --(Wan08)
         FROM @tRECEIPTDETAIL t
         JOIN RECEIPTDETAIL RD ON  t.ReceiptKey = RD.ReceiptKey
                               AND t.ReceiptLineNumber = RD.ReceiptLineNumber
         WHERE RD.ReceiptLineNumber > @c_ReceiptLineNo
         AND    RD.FinalizeFlag <> 'Y'
         AND (RD.BeforeReceivedQty > 0 OR RD.FreeGoodQtyReceived > 0)   -- Wan09
         ORDER BY RD.ReceiptLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         IF @c_toloc = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 550029
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo
                           + '. To Loc is required.'
                           + '.(lsp_FinalizeReceipt_Wrapper)'
                           + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo
                           
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END                          
         END

         IF @c_CrossWH <> '1'
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM LOC L WITH (NOLOCK)
                           WHERE L.Loc = @c_Toloc
                           AND L.Facility = @c_Facility
                           )
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 550030
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo
                              + '. To Loc does not belong to facility: ' + RTRIM(@c_Facility)
                              + '.(lsp_FinalizeReceipt_Wrapper)'
                              + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo + '|'  + RTRIM(@c_Facility)
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
               --(Wan06) - END    
            END
         END

         IF @c_ASNDetRSN = '1' AND @c_ASNReason = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 550031
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo
                           + '. Detail Reason is required. (ReceiptDetail UserDefine03) !'
                           + '.(lsp_FinalizeReceipt_Wrapper)'
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END   
         END

         IF @c_UCCTracking = '1' AND @c_UCCTrackValue = 'P'
         BEGIN
            IF @c_ExternLineNo = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 550032
               SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                              + ': Receipt #: ' + @c_Receiptkey + ' & Line: ' + @c_ReceiptLineNo + '. UCC No. is required.'
                              + '.(lsp_FinalizeReceipt_Wrapper)'
                              + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo
               --(Wan06) - START
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
               VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
               --(Wan06) - END                                 
            END
         END

         IF @c_ChkASNVarTol = '1' --AND @c_ToleranceAdmin = 'N'
         BEGIN
            SET @n_TOLPCT = 0.00
            SELECT @n_TOLPCT = CASE WHEN ISNUMERIC(S.SUSR4) = 1 THEN CONVERT(DECIMAL(8,2), S.SUSR4) ELSE -1.00 END   --(Wan02)
            FROM SKU S WITH (NOLOCK)
            WHERE S.Storerkey = @c_Storerkey
            AND S.Sku = @c_Sku

            IF @n_TOLPCT >= 0
            BEGIN
               IF @n_BeforeReceivedQty > @n_QtyExpected * (1 + (@n_TOLPCT * 0.01))
               BEGIN
                  SET @n_Continue = 3                 --(Wan06)
                  SET @n_err = 550033
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                 + ': Receipt #: ' + @c_Receiptkey + ', Line #: ' + @c_ReceiptLineNo
                                 + ', Sku: ' + @c_Sku +
                                 + ' Qty Received Exceeds ASN Qty Tolerance: '
                                 + CONVERT(NVARCHAR(10), @n_TOLPCT)
                                 + '%. (lsp_FinalizeReceipt_Wrapper)'
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
                  --(Wan06) - END   
               END
               ELSE IF @n_BeforeReceivedQty < @n_QtyExpected * (1 - (@n_TOLPCT * 0.01))
               BEGIN
                  SET @n_Continue = 3                 --(Wan06)
                  SET @n_err = 550034
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                 + ': Receipt #: ' + @c_Receiptkey + ', Line #: ' + @c_ReceiptLineNo
                                 + ', Sku: ' + @c_Sku +
                                 + ' Qty Received below ASN Qty Tolerance: '
                                 + CONVERT(NVARCHAR(10), @n_TOLPCT)
                                 + '%. (lsp_FinalizeReceipt_Wrapper)'
                                 + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo + '|'  + @c_Sku
                                 + '|'  + CONVERT(NVARCHAR(10), @n_TOLPCT)
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
                  --(Wan06) - END                                 
               END
            END
         END
                     
         IF @c_DisAllowDuplicateIdsOnWSRcpt = '1' AND @c_ToID <> ''              --(Wan08)
         BEGIN
            IF @c_AllowDupWithinPLTCnt = 'N'                                     --(Wan11) 
            BEGIN
               IF EXISTS ( SELECT TOP 1 1 FROM dbo.ID AS i WITH (NOLOCK) 
                           JOIN dbo.LOTxLOCxID AS ltlci WITH (NOLOCK) ON ltlci.Id = i.Id           --(Wan14)
                           WHERE i.ID = @c_ToID
                           AND ltlci.Qty + ltlci.PendingMoveIN > 0                                 --(Wan14)
                           AND ltlci.Storerkey = @c_Storerkey                                      --2023-10-04
                           UNION
                           SELECT TOP 1 1 FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK) 
                           WHERE r.Storerkey = @c_Storerkey
                           AND r.ToID = @c_ToID
                           AND r.BeforeReceivedQty > 0                                             --(Wan14)
                           AND r.FinalizeFlag = 'N'
                           GROUP BY r.ToID
                           HAVING COUNT(1) > 1
                           )
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 550050
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow duplicate Movable Unit Id: ' + @c_ToID
                                 + '. Receipt #: ' + @c_Receiptkey + ', Line #: ' + @c_ReceiptLineNo
                                 + '. (lsp_FinalizeReceipt_Wrapper)'
                                 + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo 

                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
               END
            END                                                                  --(Wan11) - START
            ELSE
            BEGIN
               SET @b_ValidID = 1
               SELECT TOP 1 @b_ValidID = 0
               FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
               WHERE r.ReceiptKey = @c_ReceiptKey
               AND r.ToID = @c_ToID
               AND r.BeforeReceivedQty > 0                                          --(Wan14)              
               AND r.FinalizeFlag = 'N'
               AND EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL AS r2 WITH (NOLOCK)
                           WHERE r2.ReceiptKey <> @c_ReceiptKey
                           AND   r2.ToId = r.ToId
                           AND   r2.Storerkey = r.StorerKey                         --2023-10-04                           
                           AND   r2.BeforeReceivedQty > 0                           --(Wan14)    
                           )
                           
               IF @b_ValidID = 1
               BEGIN
                  SELECT TOP 1 @b_ValidID = IIF(COUNT(DISTINCT r.Sku) > 1 OR SUM(r.BeforeReceivedQty) > MIN(p.Pallet), 0, 1)
                  FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
                  JOIN dbo.SKU AS s WITH (NOLOCK) ON s.StorerKey = r.StorerKey AND s.Sku = r.Sku
                  JOIN dbo.PACK AS p WITH (NOLOCK) ON s.PackKey = p.PackKey
                  WHERE r.ReceiptKey = @c_ReceiptKey
                  AND r.ToID = @c_ToID
                  AND r.BeforeReceivedQty > 0                                       --(Wan14)             
                  GROUP BY r.ToId
                  ORDER BY IIF(COUNT(DISTINCT r.Sku) > 1 OR SUM(r.BeforeReceivedQty) > MIN(p.Pallet), 0, 1)
               END 
               
               IF @b_ValidID = 1
               BEGIN
                  -- Last & Further check if the Received ID is archived with inventory 
                  SELECT TOP 1 @b_ValidID = 0
                  FROM dbo.RECEIPTDETAIL AS r WITH (NOLOCK)
                  WHERE r.ReceiptKey = @c_ReceiptKey
                  AND r.ToID = @c_ToID
                  AND r.BeforeReceivedQty > 0                                          --(Wan04)
                  AND EXISTS (SELECT 1 FROM dbo.LOTxLOCxID AS ltlci WITH (NOLOCK)
                              WHERE ltlci.ID = r.ToId
                              AND ltlci.Storerkey = r.Storerkey                        --2023-10-04
                              AND ltlci.Qty + ltlci.PendingMoveIN > 0
                              )    
                  GROUP BY r.ToId
                  HAVING MAX(r.FinalizeFlag) = 'N' 
                  
                  --SELECT @b_ValidID '@b_ValidID 3'                                   --(Wan14)  
               END
                          
               IF @b_ValidID = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 561001
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Disallow duplicate Movable Unit Id with qty more than Pallet Count: ' + @c_ToID
                                + '. Receipt #: ' + @c_Receiptkey + ', Line #: ' + @c_ReceiptLineNo
                                + '. (lsp_FinalizeReceipt_Wrapper)'
                                + ' |' + @c_ReceiptKey + '|'  + @c_ReceiptLineNo 

                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
               END
            END                                                                  --(Wan11) - END
         END                                                                     --(Wan08)
      END

      SET @c_ReceiptLineNo = ''
      WHILE 1 = 1
      BEGIN
         SET @c_POKey     = ''                                                      --(Wan07)
         SET @c_ExternReceiptKey = ''
         SET @c_ExternLineNo     = ''
         SET @n_SumBeforeReceivedQty = 0
         SET @n_SumFreeGoodQtyReceived = 0
         SELECT TOP 1                                                               --(Wan07)
                @c_ReceiptLineNo      = MAX(RD.ReceiptLineNumber)
               ,@c_POKey              = ISNULL(RTRIM(RD.POkey),'')
               ,@c_ExternReceiptKey   = ISNULL(RTRIM(RD.ExternReceiptKey),'')
               ,@c_ExternLineNo       = ISNULL(RTRIM(RD.ExternLineNo),'')
               ,@n_SumBeforeReceivedQty  = ISNULL(SUM(RD.BeforeReceivedQty),0)
               ,@n_SumFreeGoodQtyReceived= ISNULL(SUM(RD.FreeGoodQtyReceived),0)
         FROM @tRECEIPTDETAIL t
         JOIN RECEIPTDETAIL RD ON  t.ReceiptKey = RD.ReceiptKey
                               AND t.ReceiptLineNumber = RD.ReceiptLineNumber
         --WHERE RD.ExternReceiptKey > @c_ExternReceiptKey
         --AND   RD.ExternLineNo > @c_ExternLineNo
         WHERE RD.ReceiptLineNumber > @c_ReceiptLineNo                              --(Wan07)
         AND   RD.POkey <> ''                                                       --(Wan07)
         AND   RD.FinalizeFlag <> 'Y'
         AND   RD.Conditioncode = 'OK'
         AND  (RD.SubReasonCode IS NULL OR RD.SubReasonCode = '')
         GROUP BY ISNULL(RTRIM(RD.ExternReceiptKey),'')
               ,  ISNULL(RTRIM(RD.ExternLineNo),'')
               ,  ISNULL(RTRIM(RD.POkey),'')
         ORDER BY 1

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         IF @c_POKey <> ''
         BEGIN
            IF @c_NikeRegITF = '0' AND @c_ByPassTol = '0'
            BEGIN
               SET @n_TolPct = 0.00
               SET @n_QtyOrdered = 0
               SET @n_QtyReceived = 0
               SELECT @n_TolPct = CASE WHEN ISNUMERIC(S.SUSR4) = 1 THEN CONVERT(DECIMAL(8,2),S.SUSR4) ELSE -1.00 END --(Wan02)
                     ,@n_QtyOrdered = ISNULL(SUM(PD.QtyOrdered),0)
                     ,@n_QtyReceived= ISNULL(SUM(PD.QtyReceived),0)
               FROM PODETAIL PD WITH (NOLOCK)
               JOIN SKU      S  WITH (NOLOCK) ON (PD.Storerkey = S.Storerkey)
                                                AND(PD.Sku = S.Sku)
               WHERE PD.POKey = @c_POKey
               AND   PD.ExternPOKey = @c_ExternReceiptkey
               AND   PD.ExternLineNo= @c_ExternLineNo
               GROUP BY CASE WHEN ISNUMERIC(S.SUSR4) = 1 THEN CONVERT(DECIMAL(8,2),S.SUSR4) ELSE -1.00 END           --(Wan02)

               IF @n_TolPct >= 0
               BEGIN
                  IF @n_QtyReceived + @n_SumBeforeReceivedQty + @n_SumFreeGoodQtyReceived >
                     @n_QtyOrdered * (1 + (CONVERT(FLOAT, @n_TolPct) * 0.01))
                  BEGIN
                     SET @n_Continue = 3              --(Wan06)
                     SET @n_err = 550035
                     SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                    + ': Receipt #: ' + @c_Receiptkey
                                    + '. VALID Subreason Code is required For OverReceipt Of PO #: '
                                    + @c_POKey + ', ExternLine #: ' + @c_ExternLineNo
                                    + '%. (lsp_FinalizeReceipt_Wrapper)'
                                    + ' |' + @c_ReceiptKey + '|'  + @c_POKey + '|' + @c_ExternLineNo
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
                  --(Wan06) - END                                     
                  END
               END
            END
         END
      END

      IF @n_Continue = 3
      BEGIN
         GOTO EXIT_SP
      END
      -------------------------------------------------
      -- PreFinalze Receipt Validation (END)
      -------------------------------------------------

      --(Wan03)
      IF @n_SkipGenID = 0
      BEGIN
         -------------------------------------------------
         -- Generate ToID Before Finalize Receipt (START)
         -------------------------------------------------
         /* (Wan04) - START
         SET @c_MUID = ''
         SELECT @c_MUID = ISNULL(RTRIM(nsqlvalue),'')
         FROM NSQLCONFIG WITH (NOLOCK)
         WHERE ConfigKey = 'MUID_Enable'

         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'GenID'
               ,  @b_Success  = @b_Success   OUTPUT
               ,  @c_Authority= @c_GenID     OUTPUT
               ,  @n_Err      = @n_Err       OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT

         END TRY

         BEGIN CATCH
            SET @n_err = 550036
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspg_GetKey - GenID. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP
         END

         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'RF_Enable'
               ,  @b_Success  = @b_Success   OUTPUT
               ,  @c_Authority= @c_RF_Enable OUTPUT
               ,  @n_Err      = @n_Err       OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550037
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - RF_Enable. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            GOTO EXIT_SP
         END

         IF @c_MUID = '1' AND @c_GenID = '1'
         BEGIN
            SET @b_GenID = 1
         END
         --(Wan04) - END*/
         SET @c_ReceiptLineNo = ''
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1                                                --(Wan02)
                   @c_ReceiptLineNo     = RD.ReceiptLineNumber
                  ,@n_BeforeReceivedQty = RD.BeforeReceivedQty
                  ,@n_FreeGoodQtyReceived = ISNULL(RD.FreeGoodQtyReceived,0)
            FROM @tRECEIPTDETAIL t
            JOIN RECEIPTDETAIL RD ON  t.ReceiptKey = RD.ReceiptKey
                                  AND t.ReceiptLineNumber = RD.ReceiptLineNumber
            WHERE RD.ReceiptLineNumber >  @c_ReceiptLineNo
            AND  ( RD.ToID = '' OR RD.ToID IS NULL)
            AND  ( RD.Putawayloc = '' OR RD.Putawayloc IS NULL)
            AND    RD.FinalizeFlag <> 'Y'
            ORDER BY RD.ReceiptLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            --IF @c_RF_Enable <> '1' AND @n_BeforeReceivedQty + @n_FreeGoodQtyReceived > 0   --(Wan04)
            --BEGIN                                                                          --(Wan04)
               SET @b_GenID = 1
            --END                                                                            --(Wan04)

            IF @b_GenID = 1
            BEGIN
               BEGIN TRAN
               BEGIN TRY
                  EXEC dbo.nspg_GetKey
                        @KeyName     = 'ID'
                     ,  @fieldlength =  0
                     ,  @keystring   = @c_ToID        OUTPUT
                     ,  @b_Success   = @b_Success     OUTPUT
                     ,  @n_Err       = @n_Err         OUTPUT
                     ,  @c_Errmsg    = @c_Errmsg      OUTPUT

               END TRY

               BEGIN CATCH
                  SET @n_err = 550038
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                 + ': Error Executing nspg_GetKey - ID. (lsp_FinalizeReceipt_Wrapper)'
                                 + ' (' + @c_ErrMsg + ')'
                                 
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
                  --(Wan06) - END  
               END CATCH

               IF @b_success = 0 OR @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  GOTO EXIT_SP
               END

               IF @c_ToID <> ''
               BEGIN
                  UPDATE RECEIPTDETAIL
                     SET ToId = @c_ToID
                        ,EditWho = @c_UserName
                        ,EditDate= GETDATE()
                        ,Trafficcop = NULL
                  WHERE ReceiptKey = @c_ReceiptKey
                  AND   ReceiptLineNumber = @c_ReceiptLineNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 550039   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL fail. (lsp_FinalizeReceipt_Wrapper)'
                     --(Wan06) - START
                     INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                     VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNo, '', 'ERROR', 0, @n_err, @c_errmsg) 
                     --(Wan06) - END
                     GOTO EXIT_SP
                  END
               END
               COMMIT TRAN
            END
         END
         -------------------------------------------------
         -- Generate ToID Before Finalize Receipt (END)
         -------------------------------------------------
      END

      BEGIN TRAN
      IF @n_continue = 1
      BEGIN
         BEGIN TRY
            EXEC dbo.ispFinalizeReceipt
               @c_ReceiptKey  =  @c_ReceiptKey
              ,@b_Success     =  @b_Success
              ,@n_err         =  @n_err      OUTPUT
              ,@c_ErrMsg      =  @c_ErrMsg   OUTPUT
              ,@c_ReceiptLineNumber=@c_ReceiptLineNumber
         END TRY
         BEGIN CATCH
            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT < @n_StartTCNT
            BEGIN
               BEGIN TRAN
            END

            SET @n_err = 550040
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing ispFinalizeReceipt. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END
            
            SET @n_Continue = 3
            GOTO EXIT_SP
         END
      END

      -------------------------------------------------
      -- FlowThru Allocation (START)
      -------------------------------------------------

      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'XDFinalizeAutoAllocatePickSO'
            ,  @b_Success  = @b_Success               OUTPUT
            ,  @c_Authority= @c_XDFNZAutoAllocPickSO  OUTPUT
            ,  @n_Err      = @n_Err                   OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg                OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550047
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - XDFinalizeAutoAllocatePickSO. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
         --(Wan06) - END
         GOTO EXIT_SP
      END

      IF @c_XDFNZAutoAllocPickSO = '1'
      BEGIN
         BEGIN TRY
            EXEC  [WM].[lsp_FlowThruAllocate_Wrapper]
                  @c_ReceiptKey = @c_ReceiptKey
                , @b_Success    = @b_Success       OUTPUT
                , @n_Err        = @n_Err           OUTPUT
                , @c_ErrMsg     = @c_ErrMsg        OUTPUT
                , @c_UserName   = @c_UserName
                , @n_ErrGroupKey= @n_ErrGroupKey   OUTPUT
         END TRY
         BEGIN CATCH
            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT < @n_StartTCNT
            BEGIN
               BEGIN TRAN
            END

            SET @n_err = 550041
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing lsp_FinalizeReceipt_Wrapper. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END
            GOTO EXIT_SP
         END
      END
      -------------------------------------------------
      -- FlowThru Allocation (END)
      -------------------------------------------------

      -------------------------------------------------
      -- Inventory HOLD (START)
      -------------------------------------------------
      BEGIN TRY
         EXEC nspGetRight
               @c_Facility = @c_Facility
            ,  @c_Storerkey= @c_Storerkey
            ,  @c_Sku      = ''
            ,  @c_Configkey= 'InventoryHoldCheckConfig'
            ,  @b_Success  = @b_Success         OUTPUT
            ,  @c_Authority= @c_InvHoldCheckCFG OUTPUT
            ,  @n_Err      = @n_Err             OUTPUT
            ,  @c_ErrMsg   = @c_ErrMsg          OUTPUT
      END TRY

      BEGIN CATCH
         SET @n_err = 550042
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + ': Error Executing nspGetRight - InventoryHoldCheckConfig. (lsp_FinalizeReceipt_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_continue = 3
         --(Wan06) - START
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
         VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
         --(Wan06) - END
         GOTO EXIT_SP
      END

      IF @c_InvHoldCheckCFG = '1'
      BEGIN
         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'HoldLottable02ByUDF08'
               ,  @b_Success  = @b_Success            OUTPUT
               ,  @c_Authority= @c_HoldLot02ByUDF08   OUTPUT
               ,  @n_Err      = @n_Err                OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550043
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - HoldLottable02ByUDF08. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END
            GOTO EXIT_SP
         END

         BEGIN TRY
            EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'AllowASNLot2Rehold'
               ,  @b_Success  = @b_Success            OUTPUT
               ,  @c_Authority= @c_AllowASNLot2Rehold OUTPUT
               ,  @n_Err      = @n_Err                OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT
         END TRY

         BEGIN CATCH
            SET @n_err = 550044
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing nspGetRight - AllowASNLot2Rehold. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END
            GOTO EXIT_SP
         END

         WHILE 1 = 1
         BEGIN
            SELECT TOP 1                                                         --(Wan07)
                   @c_ReceiptLineNo     = RD.ReceiptLineNumber
                  ,@c_Storerkey         = RD.Storerkey
                  ,@c_Sku               = RD.Sku
                  ,@c_ToID              = ISNULL(RTRIM(RD.ToID),'')
                  ,@c_Lottable02        = ISNULL(RTRIM(RD.Lottable02),'')
                  ,@c_UserDefine08      = ISNULL(RTRIM(RD.UserDefine08),'')
            FROM @tRECEIPTDETAIL t
            JOIN RECEIPTDETAIL RD ON  t.ReceiptKey = RD.ReceiptKey
                                  AND t.ReceiptLineNumber = RD.ReceiptLineNumber
            WHERE RD.ReceiptLineNumber >  @c_ReceiptLineNo
            ORDER BY RD.ReceiptLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            SET @c_Lot         = NULL
            SET @c_ToLoc       = NULL
            SET @c_Lottable01  = NULL
            SET @c_Lottable03  = NULL
            SET @dt_Lottable04 = NULL
            SET @dt_Lottable05 = NULL
            SET @c_Lottable06  = NULL
            SET @c_Lottable07  = NULL
            SET @c_Lottable08  = NULL
            SET @c_Lottable09  = NULL
            SET @c_Lottable10  = NULL
            SET @c_Lottable11  = NULL
            SET @c_Lottable12  = NULL
            SET @dt_Lottable13 = NULL
            SET @dt_Lottable14 = NULL
            SET @dt_Lottable15 = NULL

            SET @b_HoldID    = 1
            SET @b_HoldLot02 = 1
            IF @c_HoldLot02ByUDF08 <> '' AND @c_UserDefine08 <> @c_UserDefine08
            BEGIN
               SET @b_HoldLot02 = 0
            END

            IF @c_Lottable02 <> '' AND @c_DocType = 'A' AND @b_HoldLot02 = 1
            BEGIN
               SET @b_HoldID    = 0
               SET @c_HoldLot02 = '0'
               SELECT @c_HoldLot02 = H.Hold
               FROM INVENTORYHOLD H WITH (NOLOCK)
               WHERE H.Storerkey = @c_Storerkey
               AND   H.Sku = @c_Sku
               AND   H.Lottable02 = @c_Lottable02

               IF @c_HoldLot02 = '0'
               BEGIN
                  SET @c_HoldByLottable02 = ''
                  SELECT @c_HoldByLottable02 = ISNULL(RTRIM(SC.Data),'')
                  FROM SKUCONFIG SC WITH (NOLOCK)
                  WHERE SC.Storerkey = @c_Storerkey
                  AND SC.Sku = @c_Sku
                  AND SC.ConfigType = 'HoldByLottable02'

                  IF @c_HoldByLottable02 = '1' AND @c_AllowASNLot2Rehold = '1'
                  BEGIN
                     SET @c_ToID = NULL
                     SET @c_ReceiptHoldCode = 'QC'
                     SET @b_HoldInv = 1
                  END
               END
            END

            IF @b_HoldID = 1 AND @c_ToID <> ''
            BEGIN
               SET @C_RF_Enable = '1'

               SET @c_HoldID = '0'
               SELECT @c_HoldID = H.Hold
               FROM INVENTORYHOLD H WITH (NOLOCK)
               WHERE H.ID = @c_ToID

               IF @c_HoldID = '0'
               BEGIN
                  SET @c_RF_Enable = '0'
                  SELECT @c_RF_Enable = ISNULL(NSQLValue,'')
                  FROM   NSQLCONFIG WITH (NOLOCK)
                  WHERE  ConfigKey = 'RF_Enable'
               END

               IF @c_RF_Enable = '0'
               BEGIN
                  SET  @c_ReceiptHoldCode = ''
                  SELECT @c_ReceiptHoldCode = ISNULL(RTRIM(S.ReceiptHoldCode),'')
                  FROM SKU S WITH (NOLOCK)
                  WHERE S.Storerkey = @c_Storerkey
                  AND S.Sku = @c_Sku

                  IF @c_ReceiptHoldCode <> ''
                  BEGIN
                     SET @c_Lottable02 = NULL
                     SET @b_HoldInv = 1
                  END
               END
            END

            IF @b_HoldInv = 1
            BEGIN
               BEGIN TRY
                  EXEC dbo.nspInventoryHoldResultSet
                        @c_Lot         = @c_Lot
                      , @c_Loc         = @c_ToLoc
                      , @c_ID          = @c_ToID
                      , @c_Lottable01  = @c_Lottable01
                      , @c_Lottable02  = @c_Lottable02
                      , @c_Lottable03  = @c_Lottable03
                      , @dt_Lottable04 = @dt_Lottable04
                      , @dt_Lottable05 = @dt_Lottable05
                      , @c_Lottable06  = @c_Lottable06
                      , @c_Lottable07  = @c_Lottable07
                      , @c_Lottable08  = @c_Lottable08
                      , @c_Lottable09  = @c_Lottable09
                      , @c_Lottable10  = @c_Lottable10
                      , @c_Lottable11  = @c_Lottable11
                      , @c_Lottable12  = @c_Lottable12
                      , @dt_Lottable13  = @dt_Lottable13
                      , @dt_Lottable14 = @dt_Lottable14
                      , @dt_Lottable15 = @dt_Lottable15
                      , @b_Success     = @b_Success       OUTPUT
                      , @n_Err         = @n_Err           OUTPUT
                      , @c_ErrMsg      = @c_ErrMsg        OUTPUT

               END TRY
               BEGIN CATCH
                  IF (XACT_STATE()) = -1
                  BEGIN
                     ROLLBACK TRAN
                  END

                  WHILE @@TRANCOUNT < @n_StartTCNT
                  BEGIN
                     BEGIN TRAN
                  END

                  SET @n_err = 550045
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                                 + ': Error Executing lsp_HoldReceiptLot_Wrapper. (lsp_FinalizeReceipt_Wrapper)'
                                 + ' (' + @c_ErrMsg + ')'
               END CATCH

               IF @b_success = 0 OR @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  --(Wan06) - START
                  INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
                  VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
                  --(Wan06) - END
                  GOTO EXIT_SP
               END
            END
         END
      END

      IF @b_InvHoldlot = 1
      BEGIN
         BEGIN TRY
            EXEC  [WM].[lsp_InventoryHoldASN_Wrapper]
                  @c_ReceiptKey = @c_ReceiptKey
                , @c_ReceiptLineNumber=@c_ReceiptLineNumber
                , @b_Success    = @b_Success       OUTPUT
                , @n_Err        = @n_Err           OUTPUT
                , @c_ErrMsg     = @c_ErrMsg        OUTPUT
                , @c_UserName   = @c_UserName

         END TRY
         BEGIN CATCH
            IF (XACT_STATE()) = -1
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT < @n_StartTCNT
            BEGIN
               BEGIN TRAN
            END

            SET @n_err = 550046
            SET @c_ErrMsg = ERROR_MESSAGE()
            SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                           + ': Error Executing lsp_InventoryHoldASN_Wrapper. (lsp_FinalizeReceipt_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            --(Wan06) - START
            INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
            VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, @n_err, @c_errmsg) 
            --(Wan06) - END
            GOTO EXIT_SP
         END
      END
      -------------------------------------------------
      -- Inventory Hold (END)
      -------------------------------------------------
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Finalize Receipt fail. (lsp_FinalizeReceipt_Wrapper) ( SQLSvr MESSAGE=' + ISNULL(ERROR_MESSAGE(),'') + ' ) '
      --(Wan06) - START
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_ReceiptKey, @c_ReceiptLineNumber, '', 'ERROR', 0, 0, @c_errmsg) 
      --(Wan06) - END
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END

   EXIT_SP:
   
   IF (XACT_STATE()) = -1              --(Wan06) - START  
   BEGIN
      SET @n_continue = 3
      ROLLBACK TRAN
   END                                 --(Wan06) - END
    
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt             --(Wan06)
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FinalizeReceipt_Wrapper'
      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt                              
      BEGIN
         COMMIT TRAN
      END
   END
   
   --(Wan06) - START
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName         
         ,  twl.SourceType        
         ,  twl.Refkey1           
         ,  twl.Refkey2           
         ,  twl.Refkey3           
         ,  twl.WriteType         
         ,  twl.LogWarningNo      
         ,  twl.ErrCode           
         ,  twl.Errmsg               
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   
   OPEN @CUR_ERRLIST
   
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                     , @c_SourceType        
                                     , @c_Refkey1           
                                     , @c_Refkey2           
                                     , @c_Refkey3           
                                     , @c_WriteType         
                                     , @n_LogWarningNo      
                                     , @n_LogErrNo           
                                     , @c_LogErrMsg           
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List] 
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_LogErrNo 
      ,  @c_errmsg2     = @c_LogErrMsg 
      ,  @b_Success     = @b_Success    
      ,  @n_err         = @n_err        
      ,  @c_errmsg      = @c_errmsg         
     
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                        , @c_SourceType        
                                        , @c_Refkey1           
                                        , @c_Refkey2           
                                        , @c_Refkey3           
                                        , @c_WriteType         
                                        , @n_LogWarningNo      
                                        , @n_LogErrNo           
                                        , @c_LogErrmsg     
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan06) - END
   
   REVERT
END -- End Procedure


GO