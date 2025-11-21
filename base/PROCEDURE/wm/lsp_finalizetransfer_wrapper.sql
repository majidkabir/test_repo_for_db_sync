SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: lsp_FinalizeTransfer_Wrapper                       */
/* Creation Date: 06-Apr-2018                                           */
/* Copyright: LFLogistics                                               */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Finalize Transfer                                           */
/*                                                                      */
/* Called By: Transfer                                                  */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-11-25  Wan01    1.1   Add Big Outer Begin Try..End Try to enable*/
/*                            Revert when Sub SP Raise error            */
/* 2021-01-15  Wan02    1.2   Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2022-06-24  SYCHUA   1.3   JSM-76615 - Filter out status = 9 (SY01)  */
/************************************************************************/

CREATE PROCEDURE [WM].[lsp_FinalizeTransfer_Wrapper]
      @c_TransferKey NVARCHAR(10)
    , @b_Success INT=1 OUTPUT
    , @n_Err INT=0 OUTPUT
    , @c_ErrMsg NVARCHAR(4000)='' OUTPUT
    , @n_WarningNo INT = 0       OUTPUT
    , @c_ProceedWithWarning CHAR(1) = 'N'
    , @c_UserName NVARCHAR(128)=''
    , @n_ErrGroupKey INT = 0 OUTPUT
    , @c_CompletedMessage NVARCHAR(4000) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                INT,
           @n_starttcnt               INT,
           @c_TableName               NVARCHAR(50),
           @c_SourceType              NVARCHAR(30),
           @c_Storerkey               NVARCHAR(15),
           @c_ToStorerkey             NVARCHAR(15),
           @c_Facility                NVARCHAR(5),
           @c_ToFacility              NVARCHAR(5),
           @c_ChkTransferQtyTally     NVARCHAR(10),
           @c_ChkMARSTrfLot01         NVARCHAR(10),
           @c_AllowUCCTransfer        NVARCHAR(10),
           @c_AllowTransferZeroQty    NVARCHAR(10),
           @c_CrossFacilityTransferFr NVARCHAR(10),
           @c_CrossFacilityTransferTo NVARCHAR(10),
           @c_TransferLineNumber      NVARCHAR(5),
           @n_QtyAvailable            INT,
           @n_FromQty                 INT,
           @n_ToQty                   INT,
           @c_AddWho                  NVARCHAR(18),
           @c_LotStatus               NVARCHAR(10),
           @c_LocStatus               NVARCHAR(10),
           @c_IDStatus                NVARCHAR(10),
           @c_ToLottable01            NVARCHAR(18),
           @c_LatestLottable01        NVARCHAR(18),
           @c_status                  NVARCHAR(10)

   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1

   SET @n_ErrGroupKey = 0
   SET @c_TableName = 'TRANSFERDETAIL'
   SET @c_SourceType = 'lsp_FinalizeTransfer_Wrapper'
   SET @c_CompletedMessage = ''

   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName       --(Wan02) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                   --(Wan02) - END

   --(Wan01) - START
   BEGIN TRY
      SELECT @c_Storerkey = FromStorerkey,
             @c_Facility = Facility,
             @c_ToStorerkey = ToStorerkey,
             @c_ToFacility = ToFacility,
             @c_AddWho = AddWho,
             @c_Status = Status
      FROM TRANSFER(NOLOCK)
      WHERE Transferkey = @c_Transferkey

      IF @c_Status = '9'
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551751
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+ ': Transfer has been finalized. (lsp_FinalizeTransfer_Wrapper)'

         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_Transferkey,
               @c_Refkey2     = '',
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT

         GOTO EXIT_SP
      END

      SELECT @c_ChkTransferQtyTally = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ChkTransferQtyTally')
      SELECT @c_ChkMARSTrfLot01 = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'ChkMARSTrfLot01')
      SELECT @c_AllowUCCTransfer = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowUCCTransfer')
      SELECT @c_AllowTransferZeroQty = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AllowTransferZeroQty')

      IF @c_Facility <> @c_Tofacility
      BEGIN
         SELECT @c_CrossFacilityTransferFr = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CrossFacilityTransfer')
         SELECT @c_CrossFacilityTransferTo = dbo.fnc_GetRight(@c_ToFacility, @c_ToStorerkey, '', 'CrossFacilityTransfer')

         IF ISNULL(@c_CrossFacilityTransferFr,'0') IN ('0','') OR ISNULL(@c_CrossFacilityTransferTo,'0') IN ('0','')
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551752
            IF ISNULL(@c_CrossFacilityTransferFr,'0') IN ('0','')
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+ ': Storerkey:' + RTRIM(@c_Storerkey) + ' Does Not Allow for Cross Facility Transfer. (lsp_FinalizeTransfer_Wrapper)'
            ELSE
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+ ': Storerkey:' + RTRIM(@c_ToStorerkey) + ' Does Not Allow for Cross Facility Transfer. (lsp_FinalizeTransfer_Wrapper)'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_Transferkey,
                  @c_Refkey2     = '',
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT
         END
      END

      IF EXISTS (SELECT 1
                 FROM TRANSFER T (NOLOCK)
                 JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
                 JOIN LOC (NOLOCK) ON TD.FromLoc = LOC.Loc
                 WHERE T.Transferkey = @c_Transferkey
                 AND T.Facility <> LOC.Facility)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551753
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+':From Location Doesn''t Exists in Facility ' + RTRIM(@c_Facility) + ' (lsp_FinalizeTransfer_Wrapper)'

         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_Transferkey,
               @c_Refkey2     = '',
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT
      END

      IF EXISTS (SELECT 1
                 FROM TRANSFER T (NOLOCK)
                 JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey
                 JOIN LOC (NOLOCK) ON TD.ToLoc = LOC.Loc
                 WHERE T.Transferkey = @c_Transferkey
                 AND T.ToFacility <> LOC.Facility)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551754
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+':To Location Doesn''t Exists in Facility ' + RTRIM(@c_ToFacility) + ' (lsp_FinalizeTransfer_Wrapper)'

         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_Transferkey,
               @c_Refkey2     = '',
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT
      END

      SET @c_TransferLineNumber = ''
      SET @n_QtyAvailable = 0
      SET @n_FromQty = 0

      SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber,
                   @n_FromQty = TD.FromQty,
                   @n_QtyAvailable = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked
      FROM TRANSFERDETAIL TD(NOLOCK)
      JOIN LOTXLOCXID LLI (NOLOCK) ON TD.FromLot = LLI.Lot AND TD.FromLoc = LLI.Loc AND TD.FromId = LLI.Id
      WHERE TD.Transferkey = @c_Transferkey
      AND 1 = CASE WHEN @c_AllowTransferZeroQty = '1' AND (TD.FromQty = 0 OR TD.ToQTy = 0) THEN 0 ELSE 1 END
      AND TD.FromQty > (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
      AND TD.STATUS < '9'     --SY01
      ORDER BY TD.TransferLineNumber

      IF ISNULL(@c_TransferLineNumber,'') <> ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551755
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+':Line: ' + RTRIM(@c_TransferLineNumber) +  ' Have Not Enought Quantity to Transfer, Quantity to Transfer: '
               + RTRIM(CAST(@n_FromQty AS NVARCHAR)) + ' and Quantity Available: ' + RTRIM(CAST(@n_QtyAvailable AS NVARCHAR)) + ' (lsp_FinalizeTransfer_Wrapper)'

         EXEC [WM].[lsp_WriteError_List]
               @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_Transferkey,
               @c_Refkey2     = '',
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT
      END

      IF @c_AllowTransferZeroQty = '1'
      BEGIN
           SET @c_TransferLineNumber = ''
           SET @n_FromQty = 0
           SET @n_ToQty = 0

         SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber,
                      @n_FromQty = TD.FromQty,
                      @n_ToQty = TD.ToQTy
         FROM TRANSFERDETAIL TD(NOLOCK)
         WHERE TD.Transferkey = @c_Transferkey
         AND (TD.FromQty = 0 OR TD.ToQTy = 0)
         AND (TD.FromQty > 0 OR TD.ToQTy > 0)
         ORDER BY TD.TransferLineNumber

         IF ISNULL(@c_TransferLineNumber,'') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551756
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+':Line: ' + RTRIM(@c_TransferLineNumber) +  '  Transfer From qty: '
                  + RTRIM(CAST(@n_FromQty AS NVARCHAR)) + '  not tally with To qty: ' + RTRIM(CAST(@n_ToQty AS NVARCHAR)) + '. Both from and to quantity must be zero. (lsp_FinalizeTransfer_Wrapper)'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_Transferkey,
                  @c_Refkey2     = '',
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT
         END
      END

      IF @c_ChkTransferQtyTally = '1' AND @c_AddWho <> 'IML'
      BEGIN
           SET @c_TransferLineNumber = ''
        SET @n_FromQty = 0
           SET @n_ToQty = 0

         SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber,
                      @n_FromQty = TD.FromQty,
                      @n_ToQty = TD.ToQTy
         FROM TRANSFERDETAIL TD (NOLOCK)
         WHERE TD.Transferkey = @c_Transferkey
         AND TD.FromQty <> TD.ToQty
         AND TD.FromUom = TD.ToUOM
         ORDER BY TD.TransferLineNumber

         IF ISNULL(@c_TransferLineNumber,'') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551757
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+':Line: ' + RTRIM(@c_TransferLineNumber) +  '  Transfer same UOM From qty: '
                  + RTRIM(CAST(@n_FromQty AS NVARCHAR)) + '  not tally with To qty: ' + RTRIM(CAST(@n_ToQty AS NVARCHAR)) + '. (lsp_FinalizeTransfer_Wrapper)'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_Transferkey,
                  @c_Refkey2     = '',
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT
         END
      END

      IF @c_AllowUCCTransfer = '1'
      BEGIN
         SET @c_TransferLineNumber = ''

         SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber
         FROM TRANSFERDETAIL TD (NOLOCK)
         JOIN LOC (NOLOCK) ON TD.FromLoc = LOC.Loc
         WHERE TD.Transferkey = @c_Transferkey
         AND ISNULL(LOC.LoseUCC,'0') <> '1'
         AND ISNULL(TD.userdefine01,'') = ''
         ORDER BY TD.TransferLineNumber

         IF ISNULL(@c_TransferLineNumber,'') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551758
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': None UCC Transfer From Is Not Allowed at Line: ' + RTRIM(@c_TransferLineNumber) + ' (lsp_FinalizeTransfer_Wrapper)'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_Transferkey,
                  @c_Refkey2     = '',
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT
         END

         SET @c_TransferLineNumber = ''

         SELECT TOP 1 @c_TransferLineNumber = TD.TransferLineNumber
         FROM TRANSFERDETAIL TD (NOLOCK)
         JOIN LOC (NOLOCK) ON TD.ToLoc = LOC.Loc
         WHERE TD.Transferkey = @c_Transferkey
         AND ISNULL(LOC.LoseUCC,'0') <> '1'
         AND ISNULL(TD.userdefine02,'') = ''
         ORDER BY TD.TransferLineNumber

         IF ISNULL(@c_TransferLineNumber,'') <> ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 551759
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': None UCC Transfer To Is Not Allowed at Line: ' + RTRIM(@c_TransferLineNumber) + ' (lsp_FinalizeTransfer_Wrapper)'

            EXEC [WM].[lsp_WriteError_List]
                  @i_iErrGroupKey = @n_ErrGroupKey OUTPUT,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_Transferkey,
                  @c_Refkey2     = '',
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT
         END
      END

      IF @n_continue IN(1,2) AND @c_AllowTransferZeroQty = '1' AND (@c_ProceedWithWarning <> 'Y' OR @n_WarningNo < 1)
      BEGIN
         DECLARE cur_TRANSFERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TD.TransferLineNumber
            FROM TRANSFERDETAIL TD (NOLOCK)
            WHERE TD.Transferkey = @c_Transferkey
            AND TD.FromQty = 0
            AND TD.ToQty = 0
            ORDER BY TD.TransferLineNumber

         OPEN cur_TRANSFERDET

         FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber

         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF ISNULL(@c_ErrMsg,'') = ''
               SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + ' ' + @c_TransferLineNumber
            ELSE
               SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + ', ' + @c_TransferLineNumber

            FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber
         END
         CLOSE cur_TRANSFERDET
         DEALLOCATE cur_TRANSFERDET

         IF ISNULL(@c_ErrMsg,'') <> ''
         BEGIN
             SET @n_WarningNo = 1
             SET @n_Continue = 3
            SET @c_ErrMsg =  "Continue to transfer Zero Qty for Line :" + @c_ErrMsg + ' ?'
         END
       END

      IF @n_continue IN(1,2) AND @c_ChkMARSTrfLot01 = '1' AND @c_AddWho <> 'IML' AND (@c_ProceedWithWarning <> 'Y' OR @n_WarningNo < 2)
      BEGIN
         DECLARE cur_TRANSFERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TD.TransferLineNumber, TD.ToLottable01,
                  (SELECT TOP 1 LA.Lottable01
                  FROM LOTATTRIBUTE LA (NOLOCK)
                  WHERE LA.Storerkey = TD.ToStorerkey
                  AND LA.Sku = TD.ToSku
                  AND LA.Lottable02 = TD.ToLottable02
                  ORDER BY CASE WHEN LA.Flag='Y' THEN 0 ELSE 1 END, LA.Lot DESC) AS LatestLottable01
         FROM TRANSFERDETAIL TD (NOLOCK)
         WHERE TD.Transferkey = @c_Transferkey
         ORDER BY TD.TransferLineNumber

         OPEN cur_TRANSFERDET

         FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber, @c_ToLottable01, @c_LatestLottable01

         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @c_LatestLottable01 = ISNULL(@c_LatestLottable01,'')

            IF @c_ToLottable01 <> @c_LatestLottable01
            BEGIN
               SET @c_ErrMsg = RTRIM(ISNULL(@c_ErrMsg,'')) + CHAR(13) + ' Line#' + @c_TransferLineNumber + ' ToLottable01: ' + RTRIM(@c_ToLottable01) + ' Inv Lottable01: ' + RTRIM(@c_LatestLottable01)
            END

            FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber
         END
         CLOSE cur_TRANSFERDET
         DEALLOCATE cur_TRANSFERDET

         IF ISNULL(@c_ErrMsg,'') <> ''
         BEGIN
            SET @n_WarningNo = 2
            SET @n_Continue = 3
            SET @c_ErrMsg = "The following lines contain tolottable01 not same as lotattribute lottable01. Confirm change ? " + @c_ErrMsg
         END
      END

      IF @n_continue IN(1,2)
      BEGIN
         IF @@TRANCOUNT = 1
            BEGIN TRAN

         BEGIN TRY
             EXEC ispFinalizeTransfer
                 @c_Transferkey = @c_Transferkey,
                 @b_Success = @b_Success OUTPUT,
                 @n_err = @n_Err OUTPUT,
                 @c_errmsg = @c_ErrMsg OUTPUT
         END TRY
         BEGIN CATCH
            IF @n_err = 0
            BEGIN
                  SET @n_continue = 3
                  SELECT @n_err = ERROR_NUMBER(),
                         @c_ErrMsg = ERROR_MESSAGE()
            END
         END CATCH
      END

      IF @n_continue IN(1,2) AND @b_success = 1
      BEGIN
         DECLARE cur_TRANSFERDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TD.TransferLineNumber, LOT.Status, LOC.Status, ID.Status
            FROM TRANSFERDETAIL TD (NOLOCK)
            JOIN LOT (NOLOCK) ON TD.FromLot = LOT.Lot
            JOIN LOC (NOLOCK) ON TD.FromLoc = LOC.Loc
            JOIN ID (NOLOCK) ON TD.FromID = ID.Id
            WHERE TD.Transferkey = @c_Transferkey
            AND (LOT.Status <> 'OK' OR LOC.Status <> 'OK' OR ID.Status <> 'OK')

         OPEN cur_TRANSFERDET

         FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber, @c_LotStatus, @c_LocStatus, @c_IDStatus

         WHILE @@FETCH_STATUS = 0
         BEGIN
             IF @c_LotStatus <> 'OK'
             BEGIN
                SET @c_CompletedMessage = RTRIM(@c_CompletedMessage) + '   ' + CHAR(13) + 'Line#' + RTRIM(@c_TransferLineNumber) + ' - From LOT is ON HOLD.'  --'<br/>'
             END

             IF @c_LocStatus <> 'OK'
             BEGIN
                SET @c_CompletedMessage = RTRIM(@c_CompletedMessage) + '   ' + CHAR(13) + 'Line#' + RTRIM(@c_TransferLineNumber) + ' - From LOC is ON HOLD.'
             END

             IF @c_IDStatus <> 'OK'
             BEGIN
                SET @c_CompletedMessage = RTRIM(@c_CompletedMessage) + '   ' + CHAR(13) + 'Line#' + RTRIM(@c_TransferLineNumber) + ' - From ID is ON HOLD.'
             END

            FETCH NEXT FROM cur_TRANSFERDET INTO @c_TransferLineNumber, @c_LotStatus, @c_LocStatus, @c_IDStatus
         END
         CLOSE cur_TRANSFERDET
         DEALLOCATE cur_TRANSFERDET

         IF ISNULL(@c_CompletedMessage,'') <> ''
            SET @c_CompletedMessage =  "Transfer Completed With The Following Alert to Take Note:" + @c_CompletedMessage
      END
   END TRY

   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'Finalize Transfer fail. (lsp_FinalizeTransfer_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH
   --(Wan01) - END

   EXIT_SP:

   IF @n_continue = 3
   BEGIN
      SET @b_Success = 0
      IF @n_starttcnt = 0 AND @@TRANCOUNT > 0
         ROLLBACK
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FinalizeTransfer_Wrapper'        --(Wan01)
   END

   REVERT
END -- End Procedure

GO