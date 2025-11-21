SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ASNExplDTL01                                        */
/* Creation Date: 20-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5240 - CN_Robot_Exceed_BulidLoad_Order_Trigger          */
/*                                                                      */                                             
/*        :                                                             */
/* Called By: isp_GenEOrder_Replenishment_Wrapper                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 8-May-2020  NJOW01   1.0   WMS-13298 add susr3 filtering             */
/************************************************************************/
CREATE PROC [dbo].[isp_ASNExplDTL01]
           @c_ReceiptKey         NVARCHAR(10) 
         , @c_ReceiptLineNumber  NVARCHAR(5) = ''
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_Cnt                INT
         , @n_NoOfExplodeLine    INT

         , @n_CaseIDRunNo        INT
         , @c_ExplodePalletKey   NVARCHAR(7)
         , @c_YearAbbrev         NCHAR(1)

         , @c_NewLineNumber      NVARCHAR(5)
         --, @c_ReceiptLineNumber  NVARCHAR(5)
         , @c_BUSR2              NVARCHAR(30)
         , @c_SUSR3              NVARCHAR(18)  --NJOW01
         , @c_PackUOM3           NVARCHAR(10)
         , @c_ToId               NVARCHAR(18)
         , @c_Lottable01         NVARCHAR(18)
         , @n_QtyExpected        INT
         , @n_InsertQtyExpected  INT
         , @n_RemainQtyExpected  INT
         , @n_InsertQtyReceived  INT
         , @n_RemainQtyReceived  INT
         , @n_PalletQty          INT
         , @n_CaseCnt            FLOAT
         , @n_Pallet             FLOAT
         , @dt_StartProcess      DATETIME
         , @n_QtyReceived        INT
         , @n_QtyToSplit         INT
         , @n_InsertQty          INT
         , @n_RemainQty          INT
         , @c_ByExpected         NVARCHAR(10)

         , @CUR_RD               CURSOR
         

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @dt_StartProcess = GETDATE()

   BEGIN TRAN
   SET @CUR_RD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RD.ReceiptLineNumber
         ,SKU.BUSR2
         ,RD.QtyExpected
         ,RD.BeforeReceivedqty
         ,PACK.CaseCnt  
         ,PACK.Pallet
         ,SKU.SUSR3  --NJOW01
         ,RD.Lottable01
   FROM   RECEIPTDETAIL RD WITH (NOLOCK)
   JOIN   SKU              WITH (NOLOCK) ON (RD.Storerkey = SKU.Storerkey)
                                         AND(RD.Sku = SKU.Sku) 
   JOIN   PACK             WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE  RD.ReceiptKey = @c_ReceiptKey
   AND    RD.FinalizeFlag <> 'Y'
   AND    (RD.QtyExpected > 0 OR RD.BeforeReceivedqty > 0) --NJOW01
   AND    RD.QtyReceived = 0   --NJOW01
   --AND    RD.BeforeReceivedqty = 0
   AND    RD.AddDate < @dt_StartProcess
   ORDER BY RD.ReceiptLineNumber 

   OPEN @CUR_RD
   
   FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNumber
                              , @c_BUSR2
                              , @n_QtyExpected
                              , @n_QtyReceived --NJOW01
                              , @n_CaseCnt  
                              , @n_Pallet
                              , @c_SUSR3  --NJOW01
                              , @c_Lottable01

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_NoOfExplodeLine = 1
      --SET @c_Lottable01 = ''
      
      IF @n_QtyReceived > 0
      BEGIN
         SET @n_QtytoSplit = @n_QtyReceived
         SET @c_ByExpected = 'N'
      END
      ELSE
      BEGIN
         SET @n_QtytoSplit = @n_QtyExpected
         SET @c_ByExpected = 'Y'
      END

      IF @n_QtytoSplit >= @n_Pallet AND @n_Pallet > 0
      BEGIN
         SET @n_NoOfExplodeLine = CEILING( @n_QtytoSplit / @n_Pallet )
         SET @n_InsertQty = @n_Pallet
      END 

      IF @c_BUSR2 = 'CRTID' AND @c_SUSR3 = 'POLYBAG'  --NJOW01
      BEGIN
         IF @n_QtytoSplit >= @n_CaseCnt AND @n_CaseCnt > 0
         BEGIN
            SET @n_NoOfExplodeLine = CEILING( @n_QtytoSplit / @n_CaseCnt )
            SET @n_InsertQty = @n_CaseCnt
         END 
      END

      IF @n_NoOfExplodeLine <= 0 
      BEGIN
         GOTO NEXT_RECORD
      END

      SET @n_Cnt = 1
      SET @n_CaseIDRunNo = 0
      SET @n_PalletQty = @n_Pallet

      SET @n_RemainQtyExpected = @n_QtyExpected
      SET @n_RemainQtyReceived = @n_QtyReceived
      SET @n_RemainQty = @n_QtytoSplit

      WHILE @n_Cnt <= @n_NoOfExplodeLine --AND @n_RemainQtyExpected > 0 
      BEGIN
         IF @n_PalletQty = @n_Pallet
         BEGIN
            EXEC nspg_GetKey
                  @KeyName = 'ID_DSG'
               ,  @fieldlength = 7
               ,  @keystring = @c_ExplodePalletKey OUTPUT
               ,  @b_Success = @b_Success          OUTPUT
               ,  @n_Err     = @n_Err              OUTPUT
               ,  @c_ErrMsg  = @c_ErrMsg           OUTPUT

            IF @b_Success <> 1 
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
               SET @n_Err = 66510
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Error Getting Pallet #.'
                              + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
               GOTO QUIT_SP
            END

            SET @c_YearAbbrev = CHAR( YEAR(GETDATE()) - 2012 + 65 ) 
            SET @c_ToID = 'D' + @c_YearAbbrev + @c_ExplodePalletKey + '000'
            SET @n_CaseIDRunNo = 0
            SET @n_PalletQty = 0
         END

         IF @c_BUSR2 = 'CRTID' AND @c_SUSR3 = 'POLYBAG'  --NJOW01
         BEGIN
            SET @c_Lottable01 = LEFT(@c_ToID,9) + 'C' + RIGHT('00000' + CONVERT(NVARCHAR(5), @n_CaseIDRunNo + 1),5)
         END

         SET @n_PalletQty = @n_PalletQty + @n_InsertQty
         
         IF @n_RemainQtyExpected >= @n_InsertQty
            SET @n_InsertQtyExpected = @n_InsertQty
         ELSE
            SET @n_InsertQtyExpected = @n_RemainQtyExpected    
         
         IF @n_RemainQtyReceived >= @n_InsertQty               
            SET @n_InsertQtyReceived = @n_InsertQty
         ELSE 
            SET @n_InsertQtyReceived = @n_RemainQtyReceived

         SET @n_RemainQtyExpected = @n_RemainQtyExpected - @n_InsertQtyExpected
         SET @n_RemainQtyReceived = @n_RemainQtyReceived - @n_InsertQtyReceived
                                               
         IF @n_RemainQty > @n_InsertQty
         BEGIN   
            SET @c_NewLineNumber = '00001'
            SELECT TOP 1 @c_NewLineNumber = RIGHT('00000' + CONVERT(NVARCHAR(5), CONVERT(INT,ReceiptLineNumber) + 1),5)
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_ReceiptKey
            ORDER BY ReceiptLineNumber DESC 

            INSERT INTO RECEIPTDETAIL
               (
                     ReceiptKey 
                  ,  ReceiptLineNumber
                  ,  ExternReceiptKey 
                  ,  ExternLineNo
                  ,  POKey
                  ,  POLineNumber
                  ,  ExternPOKey
                  ,  Storerkey     
                  ,  Sku  
                  ,  AltSku 
                  ,  Id
                  ,  [Status] 
                  ,  UOM           
                  ,  Packkey 
                  ,  Vesselkey
                  ,  Voyagekey
                  ,  XDockkey
                  ,  ContainerKey
                  ,  QtyExpected
                  ,  BeforeReceivedqty
                  ,  QtyReceived
                  ,  FreeGoodQtyExpected
                  ,  FreeGoodQtyReceived
                  ,  ToLoc
                  ,  ToID
                  ,  CaseCnt
                  ,  InnerPack
                  ,  Pallet
                  ,  [Cube]
                  ,  [GrossWgt]
                  ,  NetWgt
                  ,  OtherUnit1  
                  ,  OtherUnit2
                  ,  UnitPrice
                  ,  ExtendedPrice
                  ,  EffectiveDate
                  ,  ConditionCode
                  ,  SubReasonCode
                  ,  FinalizeFlag
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
                  ,  UserDefine01
                  ,  UserDefine02
                  ,  UserDefine03
                  ,  UserDefine04
                  ,  UserDefine05
                  ,  UserDefine06
                  ,  UserDefine07
                  ,  UserDefine08
                  ,  UserDefine09
                  ,  UserDefine10
                  ,  TariffKey
               )
            SELECT   ReceiptKey 
                  ,  @c_NewLineNumber
                  ,  ExternReceiptKey 
                  ,  ExternLineNo
                  ,  POKey
                  ,  POLineNumber
                  ,  ExternPOKey
                  ,  Storerkey     
                  ,  Sku 
                  ,  AltSku 
                  ,  Id
                  ,  [Status]        
                  ,  UOM
                  ,  Packkey 
                  ,  Vesselkey
                  ,  Voyagekey
                  ,  XDockkey
                  ,  ContainerKey
                  ,  @n_InsertQtyExpected
                  ,  @n_InsertQtyReceived
                  ,  0
                  ,  FreeGoodQtyExpected
                  ,  FreeGoodQtyReceived
                  ,  ToLoc
                  ,  @c_ToID
                  ,  CaseCnt
                  ,  InnerPack
                  ,  Pallet
                  ,  [Cube]
                  ,  [GrossWgt]
                  ,  NetWgt
                  ,  OtherUnit1  
                  ,  OtherUnit2
                  ,  UnitPrice
                  ,  ExtendedPrice
                  ,  EffectiveDate
                  ,  ConditionCode
                  ,  SubReasonCode
                  ,  'N'
                  ,  @c_Lottable01
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
                  ,  UserDefine01
                  ,  UserDefine02
                  ,  UserDefine03
                  ,  UserDefine04
                  ,  UserDefine05
                  ,  UserDefine06
                  ,  UserDefine07
                  ,  UserDefine08
                  ,  UserDefine09
                  ,  UserDefine10
                  ,  TariffKey
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_ReceiptKey
            AND   ReceiptLineNumber = @c_ReceiptLineNumber

            SET @n_Err = @@ERROR 
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
               SET @n_Err = 66520
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Insert RECEIPTDETAIL Fail. (isp_ASNExplDTL01)'
                              + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
               GOTO QUIT_SP
            END                        
         END

         SET @n_Cnt = @n_Cnt + 1
         SET @n_CaseIDRunNo = @n_CaseIDRunNo + 1

         --SET @n_RemainQtyExpected = @n_RemainQtyExpected - @n_InsertQtyExpected

         --IF @n_RemainQtyExpected = @n_InsertQtyExpected
         --BEGIN    
         --   SET @n_RemainQtyExpected = 0
         --END
         
         IF @c_ByExpected = 'Y'
            SET @n_RemainQty = @n_RemainQty - @n_InsertQtyExpected
         ELSE
            SET @n_RemainQty = @n_RemainQty - @n_InsertQtyReceived   
            
        
         /*IF @n_RemainQtyExpected - @n_InsertQtyExpected >= 0
         BEGIN 
            SET @n_RemainQtyExpected = @n_RemainQtyExpected - @n_InsertQtyExpected
         END
         ELSE
         BEGIN
            SET @n_InsertQtyExpected = @n_RemainQtyExpected
         END
         */
      END

      --update original line with remain qty
      UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      SET  QtyExpected = @n_InsertQtyExpected
         , BeforeReceivedqty = @n_InsertQtyReceived
         , ToId        = @c_ToId
         , Lottable01  = @c_Lottable01 
         , EditWho = SUSER_NAME()
         , EditDate= GETDATE() 
         , TrafficCop = NULL
      WHERE ReceiptKey = @c_ReceiptKey
      AND   ReceiptLineNumber = @c_ReceiptLineNumber

      SET @n_Err = @@ERROR 
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
         SET @n_Err = 66530
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update RECEIPTDETAIL Fail. (isp_ASNExplDTL01)'
                        + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
         GOTO QUIT_SP
      END

      NEXT_RECORD:
      FETCH NEXT FROM @CUR_RD INTO @c_ReceiptLineNumber
                                 , @c_BUSR2
                                 , @n_QtyExpected
                                 , @n_QtyReceived --NJOW01
                                 , @n_CaseCnt  
                                 , @n_Pallet
                                 , @c_SUSR3 --NJOW01
                                 , @c_Lottable01
   END
   CLOSE @CUR_RD
   DEALLOCATE @CUR_RD

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ASNExplDTL01'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO