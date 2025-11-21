SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispASNFZ09                                                  */
/* Creation Date: 25-JUL-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#373802 - CN_Newlook_POSTFinalizeReceiptSP               */
/*        :                                                             */
/* Called By: ispFinalizeReceipt                                        */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 07-OCT-2016 Wan01    1.0   WMS-446 - New Look add shipment info      */
/************************************************************************/
CREATE PROC [dbo].[ispASNFZ09] 
            @c_ReceiptKey        NVARCHAR(10)
         ,  @c_ReceiptLineNumber NVARCHAR(10)
         ,  @b_Success           INT = 0  OUTPUT 
         ,  @n_err               INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 

         , @c_Facility              NVARCHAR(5)
         , @c_Storerkey             NVARCHAR(15)
         , @c_DocType               NVARCHAR(10)
         , @c_RecType               NVARCHAR(10)


         , @c_Sku                   NVARCHAR(20)
         , @c_Packkey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_UDF03                 NVARCHAR(30)
         , @c_UDF04                 NVARCHAR(30)

         , @c_AdjustmentType        NVARCHAR(10)
         , @c_AdjustmentType1       NVARCHAR(10)
         , @c_AdjustmentType2       NVARCHAR(10)
         , @c_AdjustmentKeys        NVARCHAR(10)
         , @c_AdjustmentKey         NVARCHAR(10)

         , @c_AdjustmentLineNumber  NVARCHAR(5)
         , @c_ReasonCode            NVARCHAR(10)
         , @c_ShortReasonCode       NVARCHAR(10)
         , @c_OverReasonCode        NVARCHAR(10)
         , @c_Loc                   NVARCHAR(10)
         , @c_Lottable02            NVARCHAR(18)
         , @dt_Lottable05           DATETIME
         , @n_QtyExpected           INT
         , @n_QtyReceived           INT
         , @n_QtyVariance           INT

         , @n_KeyNo                 INT
         , @n_KeyNo1                INT
         , @n_KeyNo2                INT
         , @n_KeyLineNo             INT
         , @n_Cnt                   INT
         , @n_Batch                 INT

         , @c_CarrierName           NVARCHAR(30)   --(Wan01)
         , @c_ADJ_UDF04             NVARCHAR(30)   --(Wan01)
         , @c_ADJ_UDF05             NVARCHAR(30)   --(Wan01)
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   CREATE TABLE #TMP_ADJ
         (  KeyNo          INT            NOT NULL
         ,  AdjustmentKey  NVARCHAR(10)   NULL
         ,  AdjustmentType NVARCHAR(10)   NULL
         ,  Storerkey      NVARCHAR(15)   NULL
         ,  Facility       NVARCHAR(5)    NULL
         ,  UserDefine01   NVARCHAR(30)   NULL
         )

   CREATE TABLE #TMP_ADJDET
         (  KeyNo                INT            NOT NULL
         ,  AdjustmentKey        NVARCHAR(10)   NULL
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
         ,  Lottable02           NVARCHAR(18)   NULL
         ,  Lottable05           DATETIME       NULL
         ,  UserDefine01         NVARCHAR(20)   NULL
         ,  UserDefine02         NVARCHAR(20)   NULL
         ,  UserDefine03         NVARCHAR(20)   NULL
         ,  UserDefine04         NVARCHAR(20)   NULL        --(Wan01)
         ,  UserDefine05         NVARCHAR(20)   NULL        --(Wan01)
         )

   SET @c_Facility = ''
   SET @c_Storerkey= ''
   SET @c_DocType  = ''
   SET @c_RecType  = ''
   SET @c_CarrierName = ''                                  --(Wan01)
   SELECT @c_Facility = RECEIPT.Facility
         ,@c_Storerkey= RECEIPT.Storerkey
         ,@c_DocType  = RECEIPT.DocType
         ,@c_RecType  = RECEIPT.RecType
         ,@c_CarrierName =  ISNULL(RTRIM(CarrierName),'')   --(Wan01)
   FROM   RECEIPT WITH (NOLOCK)
   WHERE  RECEIPT.ReceiptKey = @c_ReceiptKey
   AND    RECEIPT.DocType = 'A'
   AND    RECEIPT.RecType = 'Normal'

   IF @c_DocType <> 'A'
   BEGIN
      GOTO QUIT_SP
   END 
    
   IF @c_RecType <> 'Normal'
   BEGIN
      GOTO QUIT_SP
   END 

   SET @c_Loc = ''
   SELECT @c_Loc = FACILITY.UserDefine04
   FROM FACILITY WITH (NOLOCK)
   WHERE Facility = @c_Facility

   IF EXISTS ( SELECT 1
               FROM   RECEIPTDETAIL WITH (NOLOCK)  
               WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
               AND    RECEIPTDETAIL.QtyExpected <> RECEIPTDETAIL.QtyReceived
             )
   BEGIN  
      SET @c_AdjustmentType = ''
      SELECT TOP 1 @c_AdjustmentType1 = SUBSTRING(Code,3,28)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'NONADJITF'
      AND   Storerkey = @c_Storerkey

      SET @c_Lottable02 = '' 
      SET @c_AdjustmentType2 = ''
      SELECT TOP 1 @c_Lottable02 = Code 
         , @c_AdjustmentType2 = UDF03
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'NLDC'
      AND   Storerkey = @c_Storerkey
      AND   UDF01 = 'Y'

      SET @c_ReasonCode = ''
      SELECT TOP 1 @c_ShortReasonCode = Code
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'ADJREASON'
      AND   Storerkey = @c_Storerkey
      AND   Short = 'S'

      SET @c_ReasonCode = ''
      SELECT TOP 1 @c_OverReasonCode = Code
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'ADJREASON'
      AND   Storerkey = @c_Storerkey
      AND   Short = 'O'
   END
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN 

   SET @n_KeyNo = -1
   DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT KeyLineNo = ROW_NUMBER() OVER (PARTITION BY RECEIPTDETAIL.ReceiptKey
                                        , CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0 
                                          WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                          ELSE 9 END 
                                          ORDER BY 
                                          CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0 
                                               WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                               ELSE 9 END)
         ,RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.Packkey
         ,RECEIPTDETAIL.UOM
         ,RECEIPTDETAIL.QtyExpected
         ,RECEIPTDETAIL.QtyReceived
         ,RECEIPTDETAIL.UserDefine03
         ,RECEIPTDETAIL.UserDefine04
   FROM   RECEIPTDETAIL WITH (NOLOCK)  
   WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
   ORDER BY CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0 
                 WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                 ELSE 9 END

   OPEN CUR_RECDET
   
   FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                 ,  @c_Sku
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_QtyExpected
                                 ,  @n_QtyReceived
                                 ,  @c_UDF03
                                 ,  @c_UDF04 

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM PO WITH (NOLOCK)
                  WHERE Storerkey = @c_Storerkey
                  AND   UserDefine03 = @c_UDF03
                  AND   UserDefine04 = @c_UDF04
                  AND (Status < '9' OR ExternStatus < '9')
                 )
      BEGIN
         UPDATE PO WITH (ROWLOCK)
         SET Status = '9'
            ,ExternStatus = '9'
            ,EditWho  = SUSER_NAME()
            ,EditDate = GETDATE()
         WHERE Storerkey = @c_Storerkey
         AND   UserDefine03 = @c_UDF03
         AND   UserDefine04 = @c_UDF04
         AND (Status < '9' OR ExternStatus < '9')
      END

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60010  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PO Table. (ispASNFZ09)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      --(Wan01) - START
      SET @c_ADJ_UDF04 = ''
      SET @c_ADJ_UDF05 = ''
      IF @c_CarrierName = ''
      BEGIN
         SET @c_ADJ_UDF04 = SUBSTRING(@c_UDF03 + @c_UDF04,1,20)
         SET @c_ADJ_UDF05 = SUBSTRING(@c_UDF03 + @c_UDF04,21,20)
      END
      ELSE
      BEGIN
         SET @c_ADJ_UDF04 = SUBSTRING(@c_CarrierName,1,20)
         IF LEN(@c_CarrierName) > 20 
         BEGIN
            SET @c_ADJ_UDF05 = RIGHT(@c_CarrierName,LEN(@c_CarrierName) - 20)
         END 
      END
      --(Wan01) - END

      SET @n_QtyVariance = 0
      IF @n_QtyExpected > @n_QtyReceived
      BEGIN
         SET @n_QtyVariance = @n_QtyExpected - @n_QtyReceived
         SET @c_AdjustmentType= @c_AdjustmentType1
         SET @c_ReasonCode = @c_ShortReasonCode
      END
      ELSE 
      BEGIN
         SET @n_QtyVariance = @n_QtyReceived - @n_QtyExpected
         SET @c_AdjustmentType= @c_AdjustmentType2
         SET @c_ReasonCode = @c_OverReasonCode
      END

      SET @n_Cnt = 1
      IF @n_QtyVariance > 0 
      BEGIN
         WHILE @n_Cnt <= 2
         BEGIN 
            IF @n_KeyLineNo = 1
            BEGIN
               SET @n_KeyNo = @n_KeyNo + 1
               IF @n_Cnt = 1
               BEGIN

                  SET @n_KeyNo1 = @n_KeyNo
               END
               ELSE
               BEGIN
                  SET @n_KeyNo2 = @n_KeyNo 
                  SET @c_AdjustmentType = CASE WHEN @c_AdjustmentType = @c_AdjustmentType1 THEN @c_AdjustmentType2 
                                               WHEN @c_AdjustmentType = @c_AdjustmentType2 THEN @c_AdjustmentType1 
                                               END
               END

               INSERT INTO #TMP_ADJ
               (  KeyNo
               ,  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               )
               VALUES 
               (  @n_KeyNo
               ,  @c_AdjustmentType
               ,  @c_Storerkey
               ,  @c_Facility
               ,  @c_ReceiptKey
               )
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60020  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJ Table. (ispASNFZ09)' 
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                  GOTO QUIT_SP
               END


            END

            IF @n_Cnt = 1
            BEGIN
               SET @n_KeyNo = @n_KeyNo1
            END
            ELSE
            BEGIN
               SET @n_KeyNo = @n_KeyNo2
               SET @n_QtyVariance = @n_QtyVariance * - 1
            END 

            SET @c_AdjustmentLineNumber = RIGHT('00000' + CONVERT (NVARCHAR(5), @n_KeyLineNo),5)

            INSERT INTO #TMP_ADJDET
               (  KeyNo
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
               ,  Lottable02
               ,  Lottable05
               ,  UserDefine01
               ,  UserDefine02
               ,  UserDefine03
               ,  UserDefine04            --(Wan01)
               ,  UserDefine05            --(Wan01)
               )
            VALUES 
               (  @n_KeyNo
               ,  @c_AdjustmentLineNumber
               ,  @c_StorerKey
               ,  @c_Sku
               ,  @c_Packkey
               ,  @c_UOM
               ,  ''
               ,  @c_Loc
               ,  ''
               ,  @n_QtyVariance
               ,  @c_ReasonCode
               ,  @c_Lottable02
               ,  CONVERT(NVARCHAR(10), GETDATE(), 112)
               ,  SUBSTRING(@c_UDF03 + @c_UDF04,1,20)
               ,  SUBSTRING(@c_UDF03 + @c_UDF04,21,20)
               ,  SUBSTRING(@c_UDF03 + @c_UDF04,41,20)
               ,  @c_ADJ_UDF04            --(Wan01)
               ,  @c_ADJ_UDF05            --(Wan01)
               )
                 
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60030  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJDET Table. (ispASNFZ09)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END

            SET @n_Cnt = @n_Cnt + 1
         END
      END

      FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                    ,  @c_Sku
                                    ,  @c_Packkey
                                    ,  @c_UOM
                                    ,  @n_QtyExpected
                                    ,  @n_QtyReceived
                                    ,  @c_UDF03
                                    ,  @c_UDF04 
   END
   CLOSE CUR_RECDET
   DEALLOCATE CUR_RECDET               

   SET @n_batch = 0
   SELECT @n_batch = COUNT(1)
   FROM #TMP_ADJ

   IF @n_batch > 0
   BEGIN
      SET @c_AdjustmentKeys = ''
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
         SET @n_err = 60040                                                                                               
         SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispASNFZ09)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'                                  
         GOTO QUIT_SP        
      END

      UPDATE #TMP_ADJ 
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60050  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ##TMP_ADJ Table. (ispASNFZ09)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      UPDATE #TMP_ADJDET 
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060  
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update #TMP_ADJDET Table. (ispASNFZ09)' 
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
            )
         SELECT 
               Adjustmentkey
            ,  AdjustmentType
            ,  Storerkey
            ,  Facility
            ,  UserDefine01
         FROM #TMP_ADJ
         WHERE Adjustmentkey = @c_Adjustmentkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60070  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispASNFZ09)' 
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
            ,  Lottable02
            ,  Lottable05
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04            --(Wan01)
            ,  UserDefine05            --(Wan01)
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
            ,  Lottable02
            ,  Lottable05
            ,  UserDefine01
            ,  UserDefine02
            ,  UserDefine03
            ,  UserDefine04            --(Wan01)
            ,  UserDefine05            --(Wan01)
         FROM #TMP_ADJDET
         WHERE Adjustmentkey = @c_Adjustmentkey  
         ORDER BY AdjustmentLineNumber       
                 
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60080  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispASNFZ09)' 
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

   DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Adjustmentkey
   FROM   #TMP_ADJ  
   ORDER BY Adjustmentkey

   OPEN CUR_ADJ
   
   FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE isp_FinalizeADJ
               @c_ADJKey   = @c_AdjustmentKey
            ,  @b_Success  = @b_Success OUTPUT 
            ,  @n_err      = @n_err     OUTPUT 
            ,  @c_errmsg   = @c_errmsg  OUTPUT   

      IF @n_err <> 0  
      BEGIN 
         SET @n_continue= 3 
         SET @n_err  = 60090
         SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ09)'
         GOTO QUIT_SP 
      END
      
      SET @n_Cnt = 0

      SELECT @n_Cnt = 1
      FROM ADJUSTMENTDETAIL WITH (NOLOCK)
      WHERE AdjustmentKey = @c_AdjustmentKey
      AND FinalizedFlag <> 'Y'

      IF @n_Cnt = 0
      BEGIN          
         UPDATE ADJUSTMENT WITH (ROWLOCK)
         SET FinalizedFlag = 'Y'
         WHERE AdjustmentKey = @c_AdjustmentKey


         IF @n_err <> 0  
         BEGIN 
            SET @n_continue= 3 
            SET @n_err  = 60090
            SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ09)'
            GOTO QUIT_SP 
         END
      END

      FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
   END 
   CLOSE CUR_ADJ
   DEALLOCATE CUR_ADJ

QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_RECDET') in (0 , 1)  
   BEGIN
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > @n_StartTCnt AND @@TRANCOUNT = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ09'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
   BEGIN
      BEGIN TRAN
   END 
END -- procedure

GO