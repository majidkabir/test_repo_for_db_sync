SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC30                                            */
/* Creation Date: 08-Aug-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-23292 - [CN]COSTCO_ASN_Finalization_Update_Lotattribute    */
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By: ispPreFinalizeReceiptWrapper                                 */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08-Aug-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE   PROC [dbo].[ispPRREC30]  
(     @c_Receiptkey        NVARCHAR(10)  
  ,   @c_ReceiptLineNumber NVARCHAR(5) = ''      
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTranCount     INT         
         , @c_ExternPOKey        NVARCHAR(20)
         , @c_Storerkey          NVARCHAR(15)
         , @c_SellersReference   NVARCHAR(18)
         , @c_SellerCompany      NVARCHAR(45)

   DECLARE @c_SKU                NVARCHAR(20)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @c_Lottable04         DATETIME
         , @c_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @c_Lottable13         DATETIME
         , @n_BeforeRecQty       INT
         , @c_BUSR3              NVARCHAR(30)
         , @c_SeqNo              NVARCHAR(7)
         , @c_FinalSeqNo         NVARCHAR(8)
         , @c_ColValue           NVARCHAR(10)
         , @c_TempSeqNo          NVARCHAR(10)
         , @n_Increment          INT = 0
         , @c_DelimitSeqNo       NVARCHAR(20)
         , @c_POKey              NVARCHAR(10)
         , @c_PODETLottable07    NVARCHAR(50)
         , @c_SiteCode           NVARCHAR(10)
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  

   CREATE TABLE #TMP_RD (
         Receiptkey        NVARCHAR(10)  
       , ReceiptLineNumber NVARCHAR(5)    
       , SKU               NVARCHAR(20)
       , ExternPOKey       NVARCHAR(20)
       , Lottable02        NVARCHAR(18) NULL
       , Lottable03        NVARCHAR(18) NULL
       , Lottable04        DATETIME     NULL
       , Lottable05        DATETIME     NULL
       , Lottable06        NVARCHAR(30) NULL
       , Lottable07        NVARCHAR(30) NULL
       , Lottable08        NVARCHAR(30) NULL
       , Lottable09        NVARCHAR(30) NULL
       , Lottable10        NVARCHAR(30) NULL
       , Lottable11        NVARCHAR(30) NULL
       , Lottable12        NVARCHAR(30) NULL
       , Lottable13        DATETIME     NULL
       , Storerkey         NVARCHAR(15) NULL
       , BeforeRecQty      INT NULL
   )

   CREATE NONCLUSTERED INDEX IDX_TMP_RD ON #TMP_RD (Receiptkey, ReceiptLineNumber)

   IF @n_Continue IN (1,2)
   BEGIN
      INSERT INTO #TMP_RD( Receiptkey, ReceiptLineNumber
                         , SKU, ExternPOKey, Lottable02
                         , Lottable03, Lottable04, Lottable05, Lottable07
                         , Lottable08, Lottable09, Lottable10, Lottable11
                         , Lottable12, Lottable13, Storerkey, BeforeRecQty)
      SELECT RD.ReceiptKey, RD.ReceiptLineNumber
           , RD.SKU, RD.ExternPoKey, RD.Lottable02
           , RD.Lottable03, RD.Lottable04, RD.Lottable05, RD.Lottable07
           , RD.Lottable08, RD.Lottable09, RD.Lottable10, RD.Lottable11
           , RD.Lottable12, RD.Lottable13, RD.StorerKey, RD.BeforeReceivedQty
      FROM RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND (RD.ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
      GROUP BY RD.ReceiptKey, RD.ReceiptLineNumber
             , RD.SKU, RD.ExternPoKey, RD.Lottable02
             , RD.Lottable03, RD.Lottable04, RD.Lottable05, RD.Lottable07
             , RD.Lottable08, RD.Lottable09, RD.Lottable10, RD.Lottable11
             , RD.Lottable12, RD.Lottable13, RD.StorerKey, RD.BeforeReceivedQty
   END

   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RD.ReceiptLineNumber, RD.ExternPoKey, RD.StorerKey
      FROM RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND (RD.ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
      ORDER BY RD.ReceiptLineNumber

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber, @c_ExternPOKey, @c_Storerkey

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         SELECT @c_SellersReference = PO.SellersReference
              , @c_SellerCompany    = PO.SellerCompany
              , @c_POKey            = PO.POKey
         FROM PO (NOLOCK)
         WHERE PO.ExternPOKey = @c_ExternPOKey
         AND PO.StorerKey = @c_Storerkey

         UPDATE #TMP_RD
         SET Lottable03 = @c_ExternPOKey
           , Lottable02 = @c_Receiptkey
         WHERE ReceiptKey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber

         SELECT @c_SiteCode = TRIM(ISNULL(CL.Code,''))
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'SiteCode'
         AND CL.Storerkey = @c_Storerkey

         /*
         DECLARE CUR_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TRIM(PODETAIL.Lottable07)
         FROM PODETAIL (NOLOCK)
         WHERE PODETAIL.POKey = @c_POKey

         OPEN CUR_INS

         FETCH NEXT FROM CUR_INS INTO @c_PODETLottable07

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF NOT EXISTS (SELECT 1
                           FROM STORER ST (NOLOCK)
                           WHERE ST.StorerKey = @c_PODETLottable07
                           AND ST.[Type] = '2'
                           AND ST.ConsigneeFor = @c_Storerkey)
            BEGIN
               INSERT INTO STORER (StorerKey, Company, [Type], ConsigneeFor)
               SELECT @c_PODETLottable07, @c_SellerCompany, '2', @c_Storerkey
            
               SET @n_err = @@ERROR  
            
               IF @n_err <> 0   
               BEGIN  
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                  SET @n_err = 65525 
                  SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)
                                + ': INSERT STORER Table Failed for ' + @c_PODETLottable07 + '. (ispPRREC30)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  GOTO QUIT_SP
               END
            END
            
            FETCH NEXT FROM CUR_INS INTO @c_PODETLottable07
         END
         CLOSE CUR_INS
         DEALLOCATE CUR_INS
         */
         FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber, @c_ExternPOKey, @c_Storerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      SET @c_ReceiptLineNumber = ''
   END

   IF @n_Continue IN(1,2)
   BEGIN          
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.SKU, RD.Lottable02
              , RD.Lottable03, RD.Lottable04, RD.Lottable05
              , RD.Lottable07, RD.Lottable08, RD.Lottable09
              , RD.Lottable11, RD.Lottable12, RD.Lottable13 
              , RD.StorerKey, SUM(RD.BeforeRecQty)
         FROM #TMP_RD RD (NOLOCK)
         WHERE RD.ReceiptKey = @c_Receiptkey
         AND (RD.ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
         GROUP BY RD.SKU, RD.Lottable02
                , RD.Lottable03, RD.Lottable04, RD.Lottable05
                , RD.Lottable07, RD.Lottable08, RD.Lottable09
                , RD.Lottable11, RD.Lottable12, RD.Lottable13 
                , RD.StorerKey
         ORDER BY RD.SKU
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_SKU, @c_Lottable02 
                                    , @c_Lottable03, @c_Lottable04, @c_Lottable05 
                                    , @c_Lottable07, @c_Lottable08, @c_Lottable09 
                                    , @c_Lottable11, @c_Lottable12, @c_Lottable13 
                                    , @c_Storerkey, @n_BeforeRecQty

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         SET @c_BUSR3 = ''
         SET @c_Lottable06 = ''
         SET @c_Lottable10 = ''

         IF @n_continue IN (1,2) 
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM NCOUNTER (NOLOCK)
                           WHERE KeyName = 'COSTCO6LOTSEQ')
            BEGIN
               INSERT INTO dbo.NCOUNTER(keyname, keycount, AlphaCount, EditDate)
               VALUES('COSTCO6LOTSEQ'   
                    , 1     
                    , '1'
                    , GETDATE()
               )
            
               SET @c_SeqNo = '1'
            END
            ELSE
            BEGIN
               SELECT @c_SeqNo = AlphaCount
               FROM dbo.NCOUNTER N (NOLOCK)
               WHERE N.keyname = 'COSTCO6LOTSEQ'
            
               IF @c_SeqNo = 'ZZZZZZZ' OR LEN(@c_SeqNo) > 7
               BEGIN
                  SET @c_SeqNo = 'ERR'
               END
            
               IF ISNULL(@c_SeqNo,'') <> '' AND @c_SeqNo <> 'ERR'
               BEGIN
                  IF ISNUMERIC(RIGHT(@c_SeqNo, 1)) = 1   --0-9
                  BEGIN
                     IF RIGHT(@c_SeqNo, 1) = '9'
                     BEGIN
                        SET @c_SeqNo = SUBSTRING(@c_SeqNo, 1, LEN(@c_SeqNo) - 1) + 'A'
                     END
                     ELSE
                     BEGIN
                        SET @c_SeqNo = SUBSTRING(@c_SeqNo, 1, LEN(@c_SeqNo) - 1) + CAST(CAST(RIGHT(@c_SeqNo, 1) AS INT) + 1 AS NVARCHAR)
                     END
                  END
                  ELSE IF (ASCII(RIGHT(UPPER(@c_SeqNo), 1)) >= 65 AND ASCII(RIGHT(UPPER(@c_SeqNo), 1)) < 90) --A to Y
                  BEGIN
                     SET @c_SeqNo = SUBSTRING(@c_SeqNo, 1, LEN(@c_SeqNo) - 1) + NCHAR(CAST(ASCII(RIGHT(UPPER(@c_SeqNo), 1)) AS INT) + 1)
                  END
                  ELSE IF ASCII(RIGHT(UPPER(@c_SeqNo), 1)) = 90   --Z
                  BEGIN
                     SET @c_TempSeqNo = @c_SeqNo
                     SET @c_DelimitSeqNo = ''

                     WHILE LEN(@c_TempSeqNo) > 0
                     BEGIN
                        SET @c_DelimitSeqNo = @c_DelimitSeqNo + LEFT(@c_TempSeqNo, 1) + '|'
                        SET @c_TempSeqNo = RIGHT(@c_TempSeqNo, LEN(@c_TempSeqNo) - 1)
                     END
                     
                     SET @c_TempSeqNo = ''
            
                     DECLARE CUR_LOOP_B CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT FDS.ColValue
                     FROM dbo.fnc_DelimSplit('|',@c_DelimitSeqNo) FDS
                     GROUP BY FDS.ColValue, FDS.SeqNo
                     ORDER BY FDS.SeqNo DESC
            
                     OPEN CUR_LOOP_B
            
                     FETCH NEXT FROM CUR_LOOP_B INTO @c_ColValue
            
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        IF @n_Increment > 0
                        BEGIN
                           IF ISNUMERIC(@c_ColValue) = 1   --0-9
                           BEGIN
                              IF @c_ColValue = '9'
                              BEGIN
                                 SET @c_ColValue = SUBSTRING(@c_ColValue, 1, LEN(@c_ColValue) - 1) + 'A'
                                 SET @n_Increment = 0
                              END
                              ELSE
                              BEGIN
                                 SET @c_ColValue = SUBSTRING(@c_ColValue, 1, LEN(@c_ColValue) - 1) + CAST(CAST(@c_ColValue AS INT) + 1 AS NVARCHAR)
                                 SET @n_Increment = 0
                              END
                           END
                           ELSE IF (ASCII(UPPER(@c_ColValue)) >= 65 AND ASCII(UPPER(@c_ColValue)) < 90) --A to Y
                           BEGIN
                              SET @c_ColValue = SUBSTRING(@c_ColValue, 1, LEN(@c_ColValue) - 1) + NCHAR(CAST(ASCII(UPPER(@c_ColValue)) AS INT) + 1)
                              SET @n_Increment = 0
                              SET @c_TempSeqNo = @c_ColValue + @c_TempSeqNo
                              GOTO NEXT_LOOP_B
                           END
                           ELSE IF ASCII(UPPER(@c_ColValue)) = 90   --Z
                           BEGIN
                              SET @c_ColValue = '0'
                              SET @n_Increment = 1
                           END
                        END
                        
                        IF @c_ColValue = 'Z'
                        BEGIN
                           SET @c_TempSeqNo = @c_TempSeqNo + '0'
                           SET @n_Increment = 1
                           SET @c_ColValue = '0'
                        END
                        ELSE
                        BEGIN
                           SET @c_TempSeqNo = @c_ColValue + @c_TempSeqNo
                           SET @c_TempSeqNo = RIGHT(@c_TempSeqNo, 7)
                        END
                        NEXT_LOOP_B:
                        FETCH NEXT FROM CUR_LOOP_B INTO @c_ColValue
                     END
                     CLOSE CUR_LOOP_B
                     DEALLOCATE CUR_LOOP_B
                     
                     SET @c_SeqNo = CASE WHEN @n_Increment > 0 THEN CAST(@n_Increment AS NVARCHAR) ELSE '' END + @c_TempSeqNo
                  END
                  ELSE
                  BEGIN
                     SET @c_SeqNo = 'ERR'
                  END
            
                  IF @c_SeqNo <> 'ERR'
                  BEGIN
                     UPDATE dbo.NCOUNTER
                     SET AlphaCount = UPPER(@c_SeqNo)
                     WHERE keyname = 'COSTCO6LOTSEQ'

                     SET @n_err = @@ERROR  
         
                     IF @n_err <> 0   
                     BEGIN  
                        SET @n_continue = 3  
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                        SET @n_err = 65530   
                        SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update NCOUNTER Table Failed. (ispPRREC30)' 
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                        GOTO QUIT_SP
                     END
                  END
               END
            END
            
            IF @c_SeqNo <> 'ERR'
            BEGIN
               SET @c_FinalSeqNo = @c_SiteCode + RIGHT(REPLICATE('0', 7) + @c_SeqNo, 7)
            END
            ELSE
            BEGIN
               SET @c_FinalSeqNo = @c_SeqNo   --ERR
               SET @n_continue = 3  
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
               SET @n_err = 65535  
               SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The Series Number has reached 3ZZZZZZZ. (ispPRREC30)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               GOTO QUIT_SP
            END
            
            SET @c_Lottable10 = @c_FinalSeqNo
            SET @c_Lottable06 = @n_BeforeRecQty

            UPDATE #TMP_RD
            SET Lottable10 = @c_Lottable10
              , Lottable06 = @c_Lottable06
            WHERE SKU      = @c_SKU
            AND Lottable02 = @c_Lottable02
            AND Lottable03 = @c_Lottable03
            AND Lottable04 = @c_Lottable04
            AND Lottable05 = @c_Lottable05
            AND Lottable07 = @c_Lottable07
            AND Lottable08 = @c_Lottable08
            AND Lottable09 = @c_Lottable09
            AND Lottable11 = @c_Lottable11
            AND Lottable12 = @c_Lottable12
            AND Lottable13 = @c_Lottable13
            AND Storerkey  = @c_Storerkey
         END

         NEXT_LOOP:
         FETCH NEXT FROM CUR_RECDET INTO @c_SKU, @c_Lottable02 
                                       , @c_Lottable03, @c_Lottable04, @c_Lottable05 
                                       , @c_Lottable07, @c_Lottable08, @c_Lottable09 
                                       , @c_Lottable11, @c_Lottable12, @c_Lottable13 
                                       , @c_Storerkey, @n_BeforeRecQty
      END            
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET                                    
   END
   
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RD.ReceiptLineNumber, RD.Lottable03, RD.Lottable06
                    , RD.Lottable07, RD.Lottable08, RD.Lottable10
                    , RD.Lottable02
      FROM #TMP_RD RD (NOLOCK)
      ORDER BY RD.ReceiptLineNumber

      OPEN CUR_UPD

      FETCH NEXT FROM CUR_UPD INTO @c_ReceiptLineNumber, @c_Lottable03, @c_Lottable06
                                 , @c_Lottable07, @c_Lottable08, @c_Lottable10
                                 , @c_Lottable02

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
         UPDATE dbo.RECEIPTDETAIL
         SET Lottable02 = @c_Lottable02
           , Lottable03 = @c_Lottable03
           , Lottable06 = ISNULL(@c_Lottable06,'')
           , Lottable07 = @c_Lottable07
           , Lottable08 = @c_Lottable08
           , Lottable10 = @c_Lottable10
           , TrafficCop = NULL
           , EditWho    = SUSER_SNAME()
           , EditDate   = GETDATE()
         WHERE ReceiptKey = @c_Receiptkey
         AND ReceiptLineNumber = @c_ReceiptLineNumber

         SET @n_err = @@ERROR  
         
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
            SET @n_err = 65540  
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC30)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_UPD INTO @c_ReceiptLineNumber, @c_Lottable03, @c_Lottable06
                                    , @c_Lottable07, @c_Lottable08, @c_Lottable10
                                    , @c_Lottable02
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
      
   IF CURSOR_STATUS('LOCAL', 'CUR_RECDET') IN (0 , 1)
   BEGIN
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_UPD') IN (0 , 1)
   BEGIN
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD   
   END

   --IF CURSOR_STATUS('LOCAL', 'CUR_INS') IN (0 , 1)
   --BEGIN
   --   CLOSE CUR_INS
   --   DEALLOCATE CUR_INS   
   --END
   
   IF OBJECT_ID('tempdb..#TMP_RD') IS NOT NULL
      DROP TABLE #TMP_RD

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCount
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC30'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
     BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
   END
END

GO