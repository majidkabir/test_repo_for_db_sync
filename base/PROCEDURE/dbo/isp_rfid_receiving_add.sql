SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_RFID_Receiving_Add                              */  
/* Creation Date: 2020-12-02                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 02-DEC-2020 Wan      1.0   Created                                    */ 
/* 19-SEP-2023 Wan01    1.1   WMS-23643 - [CN]NIKE_B2C_Creturn_NFC_     */
/*                            Ehancement_Function CR                    */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_RFID_Receiving_Add] 
   @n_SessionID         BIGINT         = 0 OUTPUT
,  @c_StorerKey         NVARCHAR(15)  
,  @c_Facility          NVARCHAR(5)  
,  @c_ReceiptKey        NVARCHAR(10)
,  @c_POKey             NVARCHAR(10)   = ''
,  @c_ToLOC             NVARCHAR(10)
,  @c_ToID              NVARCHAR(18)
,  @c_SKU               NVARCHAR(20)   = ''
,  @c_RFIDNo1           NVARCHAR(100)  = ''
,  @c_RFIDNo2           NVARCHAR(100)  = ''
,  @c_TIDNo1            NVARCHAR(100)  = ''
,  @c_TIDNo2            NVARCHAR(100)  = ''
,  @n_QTY               INT            = 1
,  @c_CarrierReference  NVARCHAR(18)   = ''
,  @c_TrackingNo        NVARCHAR(30)   = ''
,  @c_Lottable01        NVARCHAR(18)   = ''
,  @c_Lottable02        NVARCHAR(18)   = ''
,  @c_Lottable03        NVARCHAR(18)   = ''
,  @dt_Lottable04       DATETIME       = NULL
,  @dt_Lottable05       DATETIME       = NULL
,  @c_Lottable06        NVARCHAR(30)   = ''
,  @c_Lottable07        NVARCHAR(30)   = ''
,  @c_Lottable08        NVARCHAR(30)   = ''
,  @c_Lottable09        NVARCHAR(30)   = ''
,  @c_Lottable10        NVARCHAR(30)   = ''
,  @c_Lottable11        NVARCHAR(30)   = ''
,  @c_Lottable12        NVARCHAR(30)   = ''
,  @dt_Lottable13       DATETIME       = NULL
,  @dt_Lottable14       DATETIME       = NULL
,  @dt_Lottable15       DATETIME       = NULL
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

         , @n_RowID              INT            = 0
         , @n_Cnt                INT            = 1
         , @n_SkuCnt             INT            = 0
         , @b_LottableRequired   INT            = 0
         , @c_Cnt                NVARCHAR(2)    = ''

         , @c_ListName           NVARCHAR(10)   = ''
         , @c_SPName             NVARCHAR(100)  = ''
         , @c_LottableValue      NVARCHAR(30)   = ''
         , @c_Sourcetype         NVARCHAR(10)   = ''

         , @c_LottableLabel      NVARCHAR(20)   = ''
         , @c_Lottable01Label    NVARCHAR(20)   = ''
         , @c_Lottable02Label    NVARCHAR(20)   = ''
         , @c_Lottable03Label    NVARCHAR(20)   = ''
         , @c_Lottable04Label    NVARCHAR(20)   = ''
         , @c_Lottable05Label    NVARCHAR(20)   = ''
         , @c_Lottable06Label    NVARCHAR(20)   = ''
         , @c_Lottable07Label    NVARCHAR(20)   = ''
         , @c_Lottable08Label    NVARCHAR(20)   = ''
         , @c_Lottable09Label    NVARCHAR(20)   = ''
         , @c_Lottable10Label    NVARCHAR(20)   = ''
         , @c_Lottable11Label    NVARCHAR(20)   = ''
         , @c_Lottable12Label    NVARCHAR(20)   = ''
         , @c_Lottable13Label    NVARCHAR(20)   = ''
         , @c_Lottable14Label    NVARCHAR(20)   = ''
         , @c_Lottable15Label    NVARCHAR(20)   = ''

         , @c_Lottable           NVARCHAR(10)   = ''
         , @c_Doctype            NVARCHAR(10)   = ''
         , @c_ExLotLBChk_Doctype NVARCHAR(250)  = ''

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_Err = 0 

   SELECT @c_Doctype = RH.DocType                                     
   FROM RECEIPT RH WITH (NOLOCK) 
   WHERE RH.ReceiptKey = @c_ReceiptKey 

   SET @c_Sourcetype = CASE @c_Doctype WHEN 'A' THEN 'RECEIPT' 
                                       WHEN 'R' THEN 'TRADERETURN' 
                                       ELSE 'XDOCK'
                                       END

   SELECT
         @c_Lottable01Label   = ISNULL(RTRIM(Lottable01Label),'')  
      ,  @c_Lottable02Label   = ISNULL(RTRIM(Lottable02Label),'')
      ,  @c_Lottable03Label   = ISNULL(RTRIM(Lottable03Label),'')
      ,  @c_Lottable04Label   = ISNULL(RTRIM(Lottable04Label),'')
      ,  @c_Lottable05Label   = ISNULL(RTRIM(Lottable05Label),'')
      ,  @c_Lottable06Label   = ISNULL(RTRIM(Lottable06Label),'')
      ,  @c_Lottable07Label   = ISNULL(RTRIM(Lottable07Label),'')
      ,  @c_Lottable08Label   = ISNULL(RTRIM(Lottable08Label),'')
      ,  @c_Lottable09Label   = ISNULL(RTRIM(Lottable09Label),'')
      ,  @c_Lottable10Label   = ISNULL(RTRIM(Lottable10Label),'')
      ,  @c_Lottable11Label   = ISNULL(RTRIM(Lottable11Label),'')
      ,  @c_Lottable12Label   = ISNULL(RTRIM(Lottable12Label),'')
      ,  @c_Lottable13Label   = ISNULL(RTRIM(Lottable13Label),'')
      ,  @c_Lottable14Label   = ISNULL(RTRIM(Lottable14Label),'')
      ,  @c_Lottable15Label   = ISNULL(RTRIM(Lottable15Label),'')
   FROM SKU S (NOLOCK) 
   WHERE S.StorerKey = @c_StorerKey
   AND S.SKU = @c_SKU

   SET @n_Cnt = 1
   WHILE @n_Cnt <= 15
   BEGIN
      SET @c_Lottablelabel= CASE @n_Cnt   WHEN 1  THEN @c_Lottable01Label
                                          WHEN 2  THEN @c_Lottable02Label
                                          WHEN 3  THEN @c_Lottable03Label
                                          WHEN 4  THEN @c_Lottable04Label
                                          WHEN 5  THEN @c_Lottable05Label
                                          WHEN 6  THEN @c_Lottable06Label
                                          WHEN 7  THEN @c_Lottable07Label
                                          WHEN 8  THEN @c_Lottable08Label
                                          WHEN 9  THEN @c_Lottable09Label
                                          WHEN 10 THEN @c_Lottable10Label
                                          WHEN 11 THEN @c_Lottable11Label
                                          WHEN 12 THEN @c_Lottable12Label
                                          WHEN 13 THEN @c_Lottable13Label
                                          WHEN 14 THEN @c_Lottable14Label
                                          WHEN 15 THEN @c_Lottable15Label
                                          END
      SET @c_LottableValue= CASE @n_Cnt   WHEN 1  THEN @c_Lottable01
                                          WHEN 2  THEN @c_Lottable02
                                          WHEN 3  THEN @c_Lottable03
                                          WHEN 4  THEN CONVERT(NVARCHAR(10), @dt_Lottable04, 112)
                                          WHEN 5  THEN CONVERT(NVARCHAR(10), @dt_Lottable05, 112)
                                          WHEN 6  THEN @c_Lottable06
                                          WHEN 7  THEN @c_Lottable07
                                          WHEN 8  THEN @c_Lottable08
                                          WHEN 9  THEN @c_Lottable09
                                          WHEN 10 THEN @c_Lottable10
                                          WHEN 11 THEN @c_Lottable11
                                          WHEN 12 THEN @c_Lottable12
                                          WHEN 13 THEN CONVERT(NVARCHAR(10), @dt_Lottable13, 112)
                                          WHEN 14 THEN CONVERT(NVARCHAR(10), @dt_Lottable14, 112)
                                          WHEN 15 THEN CONVERT(NVARCHAR(10), @dt_Lottable15, 112)
                                          END

      IF @n_Cnt IN (4,5,13,14,15) AND ISNULL(@c_LottableValue,'19000101') = '19000101' 
      BEGIN
         SET @c_LottableValue= ''
      END
       
      SET @c_ListName = CASE @n_Cnt       WHEN 1  THEN 'Lottable01'
                                          WHEN 2  THEN 'Lottable02'
                                          WHEN 3  THEN 'Lottable03'
                                          WHEN 4  THEN 'Lottable04'
                                          WHEN 5  THEN 'Lottable05'
                                          WHEN 6  THEN 'Lottable06'
                                          WHEN 7  THEN 'Lottable07'
                                          WHEN 8  THEN 'Lottable08'
                                          WHEN 9  THEN 'Lottable09'
                                          WHEN 10 THEN 'Lottable10'
                                          WHEN 11 THEN 'Lottable11'
                                          WHEN 12 THEN 'Lottable12'
                                          WHEN 13 THEN 'Lottable13'
                                          WHEN 14 THEN 'Lottable14'
                                          WHEN 15 THEN 'Lottable15'
                                          END

      --IF ISNULL(@c_LottableValue,'') <> ''
      --BEGIN
         SET @c_SPName = ''
         SELECT TOP 1 @c_SPName = ISNULL(CL.Long,'')
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = @c_ListName
         AND CL.Code =  @c_Lottablelabel
         AND CL.Storerkey IN ('', @c_StorerKey) 
         AND CL.Short IN ('PRE', 'BOTH')
         ORDER BY CASE WHEN CL.Storerkey = @c_StorerKey THEN 1 
                       WHEN CL.Storerkey = '' THEN 5
                       END 

         IF @c_SPName <> ''
         BEGIN 
            EXEC ispLottableRule_Wrapper 
                 @c_SPName                = @c_SPName
               , @c_Listname              = @c_ListName
               , @c_Storerkey             = @c_Storerkey
               , @c_Sku                   = @c_Sku
               , @c_LottableLabel         = @c_Lottablelabel
               , @c_Lottable01Value       = @c_Lottable01 
               , @c_Lottable02Value       = @c_Lottable02 
               , @c_Lottable03Value       = @c_Lottable03 
               , @dt_Lottable04Value      = @dt_Lottable04
               , @dt_Lottable05Value      = @dt_Lottable05
               , @c_Lottable06Value       = @c_Lottable06 
               , @c_Lottable07Value       = @c_Lottable07 
               , @c_Lottable08Value       = @c_Lottable08 
               , @c_Lottable09Value       = @c_Lottable09 
               , @c_Lottable10Value       = @c_Lottable10 
               , @c_Lottable11Value       = @c_Lottable11 
               , @c_Lottable12Value       = @c_Lottable12
               , @dt_Lottable13Value      = @dt_Lottable13
               , @dt_Lottable14Value      = @dt_Lottable14
               , @dt_Lottable15Value      = @dt_Lottable15
               , @c_Lottable01            = @c_Lottable01         OUTPUT
               , @c_Lottable02            = @c_Lottable02         OUTPUT
               , @c_Lottable03            = @c_Lottable03         OUTPUT
               , @dt_Lottable04           = @dt_Lottable04        OUTPUT
               , @dt_Lottable05           = @dt_Lottable05        OUTPUT
               , @c_Lottable06            = @c_Lottable06         OUTPUT
               , @c_Lottable07            = @c_Lottable07         OUTPUT
               , @c_Lottable08            = @c_Lottable08         OUTPUT
               , @c_Lottable09            = @c_Lottable09         OUTPUT
               , @c_Lottable10            = @c_Lottable10         OUTPUT
               , @c_Lottable11            = @c_Lottable11         OUTPUT
               , @c_Lottable12            = @c_Lottable12         OUTPUT
               , @dt_Lottable13           = @dt_Lottable13        OUTPUT
               , @dt_Lottable14           = @dt_Lottable14        OUTPUT
               , @dt_Lottable15           = @dt_Lottable15        OUTPUT
               , @b_Success               = @b_Success            OUTPUT
               , @n_Err                   = @n_Err                OUTPUT
               , @c_Errmsg                = @c_Errmsg             OUTPUT
               , @c_Sourcekey             = @c_ReceiptKey
               , @c_Sourcetype            = @c_Sourcetype
               , @c_PrePost               = 'PRE'

            IF @b_Success = 0
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT_SP
            END
         END
      --END
      SET @n_Cnt = @n_Cnt + 1
   END

   SET @dt_Lottable04 = ISNULL(@dt_Lottable04,'1900-01-01')
   SET @dt_Lottable05 = ISNULL(@dt_Lottable05,'1900-01-01')
   SET @dt_Lottable13 = ISNULL(@dt_Lottable13,'1900-01-01')
   SET @dt_Lottable14 = ISNULL(@dt_Lottable14,'1900-01-01')
   SET @dt_Lottable15 = ISNULL(@dt_Lottable15,'1900-01-01')

   SET @n_Cnt = 1
   WHILE @n_Cnt <= 15
   BEGIN
      SET @c_Lottable = CASE @n_Cnt WHEN 1  THEN 'Lottable01'
                                    WHEN 2  THEN 'Lottable02'
                                    WHEN 3  THEN 'Lottable03'
                                    WHEN 4  THEN 'Lottable04'
                                    WHEN 5  THEN 'Lottable05'
                                    WHEN 6  THEN 'Lottable06'
                                    WHEN 7  THEN 'Lottable07'
                                    WHEN 8  THEN 'Lottable08'
                                    WHEN 9  THEN 'Lottable09'
                                    WHEN 10 THEN 'Lottable10'
                                    WHEN 11 THEN 'Lottable11'
                                    WHEN 12 THEN 'Lottable12'
                                    WHEN 13 THEN 'Lottable13'
                                    WHEN 14 THEN 'Lottable14'
                                    WHEN 15 THEN 'Lottable15'
                                    END

      SET @c_LottableLabel = CASE @n_Cnt  WHEN 1  THEN @c_Lottable01Label
                                          WHEN 2  THEN @c_Lottable02Label
                                          WHEN 3  THEN @c_Lottable03Label
                                          WHEN 4  THEN @c_Lottable04Label
                                          WHEN 5  THEN ''
                                          WHEN 6  THEN @c_Lottable06Label
                                          WHEN 7  THEN @c_Lottable07Label
                                          WHEN 8  THEN @c_Lottable08Label
                                          WHEN 9  THEN @c_Lottable09Label
                                          WHEN 10 THEN @c_Lottable10Label
                                          WHEN 11 THEN @c_Lottable11Label
                                          WHEN 12 THEN @c_Lottable12Label
                                          WHEN 13 THEN @c_Lottable13Label
                                          WHEN 14 THEN @c_Lottable14Label
                                          WHEN 15 THEN @c_Lottable15Label
                                          END
      SET @c_LottableValue = CASE @n_Cnt  WHEN 1  THEN @c_Lottable01
                                          WHEN 2  THEN @c_Lottable02
                                          WHEN 3  THEN @c_Lottable03
                                          WHEN 4  THEN CONVERT(NVARCHAR(10), @dt_Lottable04, 112)
                                          WHEN 5  THEN CONVERT(NVARCHAR(10), @dt_Lottable05, 112)
                                          WHEN 6  THEN @c_Lottable06
                                          WHEN 7  THEN @c_Lottable07
                                          WHEN 8  THEN @c_Lottable08
                                          WHEN 9  THEN @c_Lottable09
                                          WHEN 10 THEN @c_Lottable10
                                          WHEN 11 THEN @c_Lottable11
                                          WHEN 12 THEN @c_Lottable12
                                          WHEN 13 THEN CONVERT(NVARCHAR(10), @dt_Lottable13, 112)
                                          WHEN 14 THEN CONVERT(NVARCHAR(10), @dt_Lottable14, 112)
                                          WHEN 15 THEN CONVERT(NVARCHAR(10), @dt_Lottable15, 112)
                                          END

      IF @n_Cnt IN (4,5,13,14,15) AND ISNULL(@c_LottableValue,'19000101') = '19000101' 
      BEGIN
         SET @c_LottableValue= ''
      END

      SET @b_LottableRequired = 0

      IF @c_LottableLabel <> '' 
      BEGIN
         SET @b_LottableRequired = 1
      END 

      SELECT @c_ExLotLBChk_Doctype = ISNULL(CL.Long,'')
      FROM CODELKUP CL (NOLOCK) 
      WHERE CL.Listname = 'EXLOTLBCHK' 
      AND CL.Storerkey = @c_Storerkey 
      AND CL.Code = @c_Lottable
      
      IF CHARINDEX(@c_DocType, @c_ExLotLBChk_Doctype) > 0 -- IF found Exclude for lottable
      BEGIN
         SET @b_LottableRequired = 0
      END
      
      IF @b_LottableRequired = 1 AND @c_LottableValue = ''
      BEGIN
         SET @c_Cnt = RIGHT('00' + CONVERT(NVARCHAR(2), @n_Cnt),2)
         SET @n_continue = 3      
         SET @n_err = 83040
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Lottable' + @c_Cnt + ': ' + @c_LottableLabel + ' is required'
                       + '. (isp_RFID_Receiving_Add)'
         GOTO QUIT_SP
      END
      SET @n_Cnt = @n_Cnt + 1
   END

   -- GET SumCartonQty, QtyReceived
   -- INSERT PIECERECEIPTDETAIL / UPDATE 
   IF @n_SessionID > 0
   BEGIN
      SELECT @n_RowID = WIP.RowID 
      FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)
      WHERE WIP.SessionID  = @n_SessionID
      AND   WIP.Storerkey  = @c_StorerKey
      AND   WIP.Sku        = @c_Sku
      AND   WIP.ToLoc      = @c_ToLoc
      AND   WIP.ToID       = @c_ToID
      AND   WIP.RFIDNo1    = @c_RFIDNo1                                             --(Wan01)
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
   END   

   IF @n_RowID > 0 
   BEGIN
      UPDATE RECEIPTDETAIL_WIP
         SET Qty = Qty + @n_Qty
            ,EditDate = GETDATE()
      WHERE RowID = @n_RowID

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3      
         SET @n_err = 83050
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPTDETAIL_WIP Failed. (isp_RFID_Receiving_Add)'
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      INSERT INTO RECEIPTDETAIL_WIP
         (  SessionID
         ,  Facility
         ,  ReceiptKey
         ,  POKey
         ,  Storerkey
         ,  Sku
         ,  Qty
         ,  ToLoc
         ,  ToID
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
         ,  RFIDNo1
         ,  RFIDNo2
         ,  TIDNo1
         ,  TIDNo2
         ,  UserDefine02
         ,  UserDefine04
         )
      VALUES
         (  @n_SessionID
         ,  @c_Facility
         ,  @c_ReceiptKey
         ,  @c_POKey
         ,  @c_Storerkey
         ,  @c_Sku
         ,  @n_Qty
         ,  @c_ToLoc
         ,  @c_ToID
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
         ,  @c_RFIDNo1
         ,  @c_RFIDNo2
         ,  @c_TidNo1
         ,  @c_TidNo2
         ,  @c_CarrierReference
         ,  @c_TrackingNo
         )

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3      
         SET @n_err = 83060
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Insert Into RECEIPTDETAIL_WIP Failed. (isp_RFID_Receiving_Add)'
         GOTO QUIT_SP
      END

      IF @n_SessionID = 0
      BEGIN
         SET @n_RowID = SCOPE_IDENTITY()
         SET @n_SessionID = @n_RowID
  
         UPDATE RECEIPTDETAIL_WIP
          SET SessionID = @n_SessionID
         WHERE RowID = @n_RowID

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3      
            SET @n_err = 83070
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPTDETAIL_WIP Failed. (isp_RFID_Receiving_Add)'
            GOTO QUIT_SP
         END
      END
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_Receiving_Add'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   REVERT      
END  

GO