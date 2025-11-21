SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ25                                            */
/* Creation Date: 10-Aug-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-20259 - [JP] PSJP_Popsocket_PostFinalizeReceiptSP - New    */
/*                                                                         */
/* Called By: ispPostFinalizeReceiptWrapper                                */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 10-Aug-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ25]  
(     @c_Receiptkey        NVARCHAR(10)   
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue           INT
         , @n_StartTranCount     INT
         , @c_GetRcptLineNo      NVARCHAR(5)
         , @c_SKU                NVARCHAR(20)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Userdefine08       NVARCHAR(30)
         , @n_Userdefine08       INT
         , @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_ToLot              NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)
         , @c_Remarks            NVARCHAR(50)
         , @c_AdjustmentType     NVARCHAR(10)
         , @c_AdjustmentKey      NVARCHAR(10)
         , @c_AdjLineNumber      NVARCHAR(5)
         , @n_QtyExpected        INT
         , @n_QtyVariance        INT
         , @n_LineNo             INT

         , @c_lot                NVARCHAR(10)
         , @c_Lot01              NVARCHAR(18)
         , @c_Lot02              NVARCHAR(18)
         , @c_Lot03              NVARCHAR(18)
         , @c_Lot06              NVARCHAR(30)
         , @d_Lot04              DATETIME
         , @d_Lot05              DATETIME
         , @c_Lot07              NVARCHAR(30)
         , @c_Lot08              NVARCHAR(30)
         , @c_Lot09              NVARCHAR(30)
         , @c_Lot10              NVARCHAR(30)
         , @c_Lot11              NVARCHAR(30)
         , @c_Lot12              NVARCHAR(30)
         , @d_Lot13              DATETIME
         , @d_Lot14              DATETIME
         , @d_Lot15              DATETIME
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_ADJHDRGen          NVARCHAR(1) = 'N'
         , @n_batch              INT
         , @n_Cnt                INT

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     

   SET @c_AdjustmentType = 'R14'
   SET @c_Lot01 = ''
   SET @c_Lot02 = ''
   SET @c_Lot03 = ''
   SET @d_Lot04 = NULL
   SET @d_Lot05 = NULL
   SET @c_Lot06 = ''
   SET @c_Lot07 = ''
   SET @c_Lot08 = ''
   SET @c_Lot09 = ''
   SET @c_Lot10 = ''
   SET @c_Lot11 = ''
   SET @c_Lot12 = ''
   SET @d_Lot13 = NULL
   SET @d_Lot14 = NULL
   SET @d_Lot15 = NULL
   SET @n_LineNo = 0
   SET @n_batch = 0
   SET @n_Cnt = 0

   CREATE TABLE #TMP_ADJ
         (  AdjustmentKey  NVARCHAR(10)   NULL
         ,  AdjustmentType NVARCHAR(10)   NULL
         ,  Storerkey      NVARCHAR(15)   NULL
         ,  Facility       NVARCHAR(5)    NULL
         ,  UserDefine01   NVARCHAR(30)   NULL
         ,  Remarks        NVARCHAR(50)   NULL
         )

   CREATE TABLE #TMP_ADJDET
         (  AdjustmentKey        NVARCHAR(10)   NULL
         ,  AdjustmentLineNumber NVARCHAR(5)    NULL
         ,  Storerkey            NVARCHAR(15)   NULL
         ,  Sku                  NVARCHAR(20)   NULL
         ,  Packkey              NVARCHAR(10)   NULL
         ,  UOM                  NVARCHAR(10)   NULL
         ,  Lot                  NVARCHAR(10)   NULL
         ,  Loc                  NVARCHAR(10)   NULL
         ,  ID                   NVARCHAR(18)   NULL
         ,  Qty                  INT            NULL
         ,  ReasonCode           NVARCHAR(10)   NULL
         ,  Lottable01           NVARCHAR(18)   NULL
         ,  Lottable02           NVARCHAR(18)   NULL
         ,  Lottable03           NVARCHAR(18)   NULL
         ,  Lottable04           DATETIME       NULL
         ,  Lottable05           DATETIME       NULL
         ,  Lottable06           NVARCHAR(30)   NULL
         ,  Lottable07           NVARCHAR(30)   NULL
         ,  Lottable08           NVARCHAR(30)   NULL
         ,  Lottable09           NVARCHAR(30)   NULL
         ,  Lottable10           NVARCHAR(30)   NULL
         ,  Lottable11           NVARCHAR(30)   NULL
         ,  Lottable12           NVARCHAR(30)   NULL
         ,  Lottable13           DATETIME       NULL
         ,  Lottable14           DATETIME       NULL 
         ,  Lottable15           DATETIME       NULL      
         )

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN

   --Main Process
   IF @n_Continue IN (1,2)
   BEGIN
      SET @c_GetRcptLineNo = @c_ReceiptLineNumber

      DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.SKU
           , CASE WHEN ISNULL(RD.UserDefine08,'') = '' THEN '0' ELSE RD.UserDefine08 END
           , RD.StorerKey, ITRN.Lot, RD.ToLoc, RD.ToID , SUM(RD.QtyExpected)
           , RD.ExternReceiptKey, R.Facility, RD.PackKey, RD.UOM
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      JOIN RECEIPT R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
      JOIN ITRN WITH (NOLOCK) ON ITRN.TranType = 'DP' 
                             AND ITRN.SourceKey = RD.ReceiptKey + RD.ReceiptLineNumber
                             AND ITRN.StorerKey = RD.StorerKey AND ITRN.Sku = RD.SKU
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' 
                                      THEN @c_ReceiptLineNumber 
                                      ELSE ReceiptLineNumber END
      AND R.DOCTYPE <> 'R'
      GROUP BY RD.ReceiptKey, RD.ReceiptLineNumber, RD.SKU, RD.UserDefine08
             , RD.StorerKey, ITRN.Lot, RD.ToLoc, RD.ToID
             , RD.ExternReceiptKey, R.Facility, RD.PackKey, RD.UOM

      OPEN CUR_RD 

      FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_SKU, @c_Userdefine08
                                , @c_Storerkey, @c_ToLot, @c_ToLoc, @c_ToID, @n_QtyExpected
                                , @c_Remarks, @c_Facility, @c_Packkey, @c_UOM

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNUMERIC(@c_Userdefine08) = 0
            GOTO NEXT_LOOP
         
         SET @n_Userdefine08 = @c_Userdefine08
         SET @n_QtyVariance = 0

         IF @n_Userdefine08 < @n_QtyExpected
         BEGIN
            SET @n_QtyVariance = @n_QtyExpected - @n_Userdefine08
            SET @n_QtyVariance = @n_QtyVariance * - 1
         END
         ELSE IF @n_Userdefine08 > @n_QtyExpected
         BEGIN
            SET @n_QtyVariance = @n_Userdefine08 - @n_QtyExpected
         END

         IF @n_QtyVariance <> 0
         BEGIN
            SET @n_LineNo = @n_LineNo + 1

            IF ISNULL(@c_ToLot,'' ) <> ''
            BEGIN
               SELECT TOP 1 @c_Lot01 = LOTT.lottable01
                          , @c_Lot02 = LOTT.lottable02
                          , @c_Lot03 = LOTT.lottable03
                          , @d_Lot04 = LOTT.lottable04
                          , @d_Lot05 = LOTT.lottable05
                          , @c_Lot06 = LOTT.lottable06
                          , @c_Lot07 = LOTT.lottable07
                          , @c_Lot08 = LOTT.lottable08
                          , @c_Lot09 = LOTT.lottable09
                          , @c_Lot10 = LOTT.lottable10
                          , @c_Lot11 = LOTT.lottable11
                          , @c_Lot12 = LOTT.lottable12
                          , @d_Lot13 = LOTT.lottable13
                          , @d_Lot14 = LOTT.lottable14
                          , @d_Lot15 = LOTT.lottable15
               FROM LOTATTRIBUTE LOTT WITH (NOLOCK)
               WHERE LOTT.lot = @c_ToLot
            END
            ELSE
            BEGIN
               SELECT TOP 1  @c_Lot01 = RECEIPTDETAIL.lottable01
                           , @c_Lot02 = RECEIPTDETAIL.lottable02
                           , @c_Lot03 = RECEIPTDETAIL.lottable03
                           , @d_Lot04 = RECEIPTDETAIL.lottable04
                           , @d_Lot05 = RECEIPTDETAIL.lottable05
                           , @c_Lot06 = RECEIPTDETAIL.lottable06
                           , @c_Lot07 = RECEIPTDETAIL.lottable07
                           , @c_Lot08 = RECEIPTDETAIL.lottable08
                           , @c_Lot09 = RECEIPTDETAIL.lottable09
                           , @c_Lot10 = RECEIPTDETAIL.lottable10
                           , @c_Lot11 = RECEIPTDETAIL.lottable11
                           , @c_Lot12 = RECEIPTDETAIL.lottable12
                           , @d_Lot13 = RECEIPTDETAIL.lottable13
                           , @d_Lot14 = RECEIPTDETAIL.lottable14
                           , @d_Lot15 = RECEIPTDETAIL.lottable15
               FROM RECEIPTDETAIL WITH (NOLOCK)
               WHERE RECEIPTDETAIL.Receiptkey = @c_ReceiptKey
               AND RECEIPTDETAIL.SKU = @c_SKU
            END

            IF @c_ADJHDRGen = 'N'
            BEGIN
               INSERT INTO #TMP_ADJ
               (  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               ,  Remarks
               )
               VALUES 
               (  @c_AdjustmentType
               ,  @c_Storerkey
               ,  @c_Facility
               ,  @c_ReceiptKey
               ,  @c_Remarks
               )
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63200  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJ Table. (ispASNFZ25)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                  GOTO QUIT_SP
               END

               SET @c_ADJHDRGen = 'Y'
            END

            SET @c_AdjLineNumber = RIGHT('00000' + CONVERT (NVARCHAR(5), @n_LineNo),5)

            INSERT INTO #TMP_ADJDET
               (  AdjustmentLineNumber
               ,  StorerKey
               ,  Sku
               ,  Packkey
               ,  UOM
               ,  Lot
               ,  Loc
               ,  Id
               ,  Qty
               ,  ReasonCode
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               )
            VALUES 
               (  @c_AdjLineNumber
               ,  @c_StorerKey
               ,  @c_Sku
               ,  @c_Packkey
               ,  @c_UOM
               ,  @c_ToLot
               ,  @c_ToLoc
               ,  @c_ToID
               ,  @n_QtyVariance
               ,  @c_AdjustmentType
               ,  @c_Lot01
               ,  @c_Lot02
               ,  @c_Lot03
               ,  @d_Lot04
               ,  @d_Lot05
               ,  @c_Lot06
               ,  @c_Lot07
               ,  @c_Lot08
               ,  @c_Lot09
               ,  @c_Lot10
               ,  @c_Lot11
               ,  @c_Lot12
               ,  @d_Lot13
               ,  @d_Lot14
               ,  @d_Lot15
               )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63205  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJDET Table. (ispASNFZ25)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END
         END
         
         NEXT_LOOP:
         FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_ReceiptLineNumber, @c_SKU, @c_Userdefine08
                                   , @c_Storerkey, @c_ToLot, @c_ToLoc, @c_ToID, @n_QtyExpected
                                   , @c_Remarks, @c_Facility, @c_Packkey, @c_UOM
      END
      CLOSE CUR_RD
      DEALLOCATE CUR_RD

      SET @n_batch = 0
      SELECT @n_batch = COUNT(1)
      FROM #TMP_ADJ

      IF @n_batch > 0
      BEGIN
         SET @c_AdjustmentKey = ''

         EXECUTE nspg_GetKey 
                 @KeyName     = 'ADJUSTMENT'
               , @fieldlength = 10
               , @keystring   = @c_AdjustmentKey   OUTPUT
               , @b_success   = @b_success         OUTPUT
               , @n_err       = @n_err             OUTPUT
               , @c_errmsg    = @c_errmsg          OUTPUT
               , @b_resultset = 0
               , @n_batch     = @n_Batch

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3                                                                                              
            SET @n_err = 63210                                                                                               
            SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispASNFZ25)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
            GOTO QUIT_SP        
         END

         UPDATE #TMP_ADJ 
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey)),10)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63215  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ##TMP_ADJ Table. (ispASNFZ25)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END

         UPDATE #TMP_ADJDET 
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey)),10)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63220  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update #TMP_ADJDET Table. (ispASNFZ25)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT_SP
         END

         DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Adjustmentkey
         FROM   #TMP_ADJ  
         ORDER BY Adjustmentkey

         OPEN CUR_ADJ
   
         FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            INSERT INTO ADJUSTMENT
               (  AdjustmentKey
               ,  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               ,  Remarks
               ,  CustomerRefNo
               )
            SELECT 
                  Adjustmentkey
               ,  AdjustmentType
               ,  Storerkey
               ,  Facility
               ,  UserDefine01
               ,  Remarks
               ,  UserDefine01   --Receiptkey
            FROM #TMP_ADJ
            WHERE Adjustmentkey = @c_Adjustmentkey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63225  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispASNFZ25)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END

            INSERT INTO ADJUSTMENTDETAIL
               (  Adjustmentkey
               ,  AdjustmentLineNumber
               ,  StorerKey
               ,  Sku
               ,  Packkey
               ,  UOM
               ,  Lot
               ,  Loc
               ,  Id
               ,  Qty
               ,  ReasonCode
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               )
            SELECT  
                  AdjustmentKey
               ,  AdjustmentLineNumber
               ,  StorerKey
               ,  Sku
               ,  Packkey
               ,  UOM
               ,  Lot
               ,  Loc
               ,  Id
               ,  Qty
               ,  ReasonCode
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
               ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
            FROM #TMP_ADJDET
            WHERE Adjustmentkey = @c_Adjustmentkey  
            ORDER BY AdjustmentLineNumber       
                 
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63230  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispASNFZ25)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END

         FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
         END 
         CLOSE CUR_ADJ
         DEALLOCATE CUR_ADJ
      END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END   

      --DECLARE CUR_ADJFZ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT Adjustmentkey
      --FROM   #TMP_ADJ  
      --ORDER BY Adjustmentkey
      
      --OPEN CUR_ADJFZ
      
      --FETCH NEXT FROM CUR_ADJFZ INTO @c_Adjustmentkey
      --WHILE @@FETCH_STATUS <> -1
      --BEGIN
      --   EXECUTE isp_FinalizeADJ
      --            @c_ADJKey   = @c_AdjustmentKey
      --         ,  @b_Success  = @b_Success OUTPUT 
      --         ,  @n_err      = @n_err     OUTPUT 
      --         ,  @c_errmsg   = @c_errmsg  OUTPUT   
      
      --   IF @n_err <> 0  
      --   BEGIN 
      --      SET @n_continue= 3 
      --      SET @n_err  = 63235
      --      SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ25)'
      --      GOTO QUIT_SP 
      --   END
         
      --   SET @n_Cnt = 0
      
      --   SELECT @n_Cnt = 1
      --   FROM ADJUSTMENTDETAIL WITH (NOLOCK)
      --   WHERE AdjustmentKey = @c_AdjustmentKey
      --   AND FinalizedFlag <> 'Y'
      
      --   IF @n_Cnt = 0
      --   BEGIN          
      --      UPDATE ADJUSTMENT WITH (ROWLOCK)
      --      SET FinalizedFlag = 'Y'
      --        , TrafficCop = NULL  
      --      WHERE AdjustmentKey = @c_AdjustmentKey
      
      --      IF @n_err <> 0  
      --      BEGIN 
      --         SET @n_continue= 3 
      --         SET @n_err  = 63240
      --         SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ25)'
      --         GOTO QUIT_SP 
      --      END
      --   END
      
      --   FETCH NEXT FROM CUR_ADJFZ INTO @c_Adjustmentkey
      --END 
      --CLOSE CUR_ADJFZ
      --DEALLOCATE CUR_ADJFZ
      
      
      ;WITH CTE AS (SELECT DISTINCT Receiptkey, ReceiptLineNumber
                    FROM RECEIPTDETAIL (NOLOCK)
                    WHERE ReceiptKey = @c_Receiptkey
                    AND ReceiptLineNumber = CASE WHEN ISNULL(@c_GetRcptLineNo,'') <> '' 
                                                    THEN @c_GetRcptLineNo 
                                                    ELSE ReceiptLineNumber END)
      UPDATE RECEIPTDETAIL 
      SET RECEIPTDETAIL.UserDefine05 = CASE WHEN @n_batch > 0 THEN '1' ELSE '0' END
      FROM CTE
      WHERE RECEIPTDETAIL.ReceiptKey = CTE.ReceiptKey
      AND RECEIPTDETAIL.ReceiptLineNumber = CTE.ReceiptLineNumber
      
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63245
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ReceiptDetail Failed! (ispASNFZ25)' + ' ( '
                         +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END 
   END 
   
QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_RD') IN (0 , 1)
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_ADJ') IN (0 , 1)
   BEGIN
      CLOSE CUR_ADJ
      DEALLOCATE CUR_ADJ   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_ADJFZ') IN (0 , 1)
   BEGIN
      CLOSE CUR_ADJFZ
      DEALLOCATE CUR_ADJFZ   
   END

   IF OBJECT_ID('tempdb..#TMP_ADJ') IS NOT NULL
      DROP TABLE #TMP_ADJ

   IF OBJECT_ID('tempdb..#TMP_ADJDET') IS NOT NULL
      DROP TABLE #TMP_ADJDET

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ25'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      --RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN
   END 

   WHILE @@TRANCOUNT < @n_StartTranCount
   BEGIN
      BEGIN TRAN
   END
END

GO