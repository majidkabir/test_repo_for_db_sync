SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_RCM_ASN_ULP_StockOwnerChange                        */
/* Creation Date: 2024-09-30                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-23788 - Stock Owner Change Without Physical Move        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*                                                                      */
/* Version: 1.1                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-09-30  Wan      1.0   Created.                                  */
/* 2025-01-24  Wan01    1.1   UWP-29270 - [FCR-2160] Unilver Modify     */
/*                            Shelf Life logic for storer-to-storer ASN */
/*                            receiving functionality                   */
/************************************************************************/
CREATE     PROC [dbo].[msp_RCM_ASN_ULP_StockOwnerChange]
   @c_Receiptkey  NVARCHAR(10)
,  @b_success  INT          = 1  OUTPUT
,  @n_err      INT          = 0  OUTPUT
,  @c_errmsg   NVARCHAR(225)= '' OUTPUT
,  @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1
         , @n_Count              INT = 0

         , @n_WarningNo          INT          = 0
         , @n_ErrGroupKey        INT          = 0
         , @c_ProceedWithWarning CHAR(1)      = 'N'
         , @c_UserName           NVARCHAR(128)= SUSER_SNAME()

         , @c_ASNStatus          NVARCHAR(10) = ''
         , @c_userdefine03       NVARCHAR(30) = ''

         , @c_ExternOrderkey     NVARCHAR(50) = ''
         , @n_ReceiptLineNo      INT          = 0
         , @c_ReceiptLineNo      NVARCHAR(5)  = ''
         , @c_ReceiptLineNumber  NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku_Prior          NVARCHAR(20) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Lot                NVARCHAR(10) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @n_Qty                INT          = 0
         , @n_QtyRemaining       INT          = 0
         , @n_QtyExpected        INT          = 0
         , @c_Lottable01         NVARCHAR(18) = ''
         , @c_Lottable02         NVARCHAR(18) = ''
         , @c_Lottable03         NVARCHAR(18) = ''
         , @d_Lottable04         DATETIME
         , @d_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30) = ''
         , @c_Lottable07         NVARCHAR(30) = ''
         , @c_Lottable08         NVARCHAR(30) = ''
         , @c_Lottable09         NVARCHAR(30) = ''
         , @c_Lottable10         NVARCHAR(30) = ''
         , @c_Lottable11         NVARCHAR(30) = ''
         , @c_Lottable12         NVARCHAR(30) = ''
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME


         , @CUR_Sku              CURSOR
         , @CUR_PD               CURSOR

   SET @b_success = 1
   SET @n_err     = 0
   SET @c_errmsg  = ''

   SELECT @c_ExternOrderkey = rh.UserDefine08
         ,@c_ASNStatus = rh.ASNStatus, @c_userdefine03 = rh.userdefine03
         ,@c_Storerkey = rh.Storerkey                                               --(Wan01)       
   FROM RECEIPT rh (NOLOCK)
   WHERE rh.Receiptkey = @c_ReceiptKey

    IF(Isnull(@c_ExternOrderkey,'')='')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Extern order key is empty. (msp_RCM_ASN_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END

   IF @c_ASNStatus = '9'
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': ASN is closed. (msp_RCM_ASN_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END

   IF Not Exists(select 1 from CODELKUP WITH (NOLOCK) where LISTNAME='VENDORCODE' and UDF01=@c_userdefine03)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Company name does not match with codeluk up. (msp_RCM_ASN_ULP_StockOwnerChange)'
   GOTO QUIT_SP
   END

   ;with ib (storerkey, sku, qtyexpected) AS
   (
      SELECT rd.Storerkey, rd.sku, SUM(rd.qtyexpected)
      FROM RECEIPTDETAIL rd (NOLOCK)
      WHERE rd.Receiptkey = @c_Receiptkey
      GROUP by rd.receiptkey, rd.storerkey, rd.sku
   )
   , ob (Storerkey, Sku, Qtyshipped) AS
   (
      SELECT pd.storerkey , pd.sku, sum(pd.qty)
      FROM orders o (NOLOCK)
      join PICKDETAIL pd(NOLOCK) on pd.orderkey = o.orderkey
      WHERE o.type= 'PI'
      AND  o.Externorderkey = @c_ExternOrderkey
      and pd.status = '9'
      GROUP BY o.Externorderkey, pd.Storerkey , pd.Sku
   )
      SELECT @n_Count = 1
      FROM ib
      LEFT OUTER JOIN ob on ib.sku = ob.sku
      where ib.qtyexpected <> ISNULL(ob.qtyshipped,0)

   IF (@n_Count>0)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68020
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Mismatch Qty To Received And Shipped Qty for Sku found. (msp_RCM_ASN_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END


  IF EXISTS (
       SELECT 1 FROM PICKDETAIL pd WITH (NOLOCK)
           join ORDERS od (NOLOCK) on pd.OrderKey=od.OrderKey
            LEFT JOIN RECEIPTDETAIL rd (NOLOCK)
            ON pd.sku = rd.sku
            WHERE
           rd.sku IS NULL and
           rd.ReceiptKey=@c_receiptKey
           and od.type= 'PI'
          and pd.status = '9'
           and od.ExternOrderKey=@c_ExternOrderkey
  )
   Begin
      SET @n_Continue = 3
      SET @n_Err = 68021
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Mismatch in SKU from pickdetails and ASN details. (msp_RCM_ASN_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   end

   SELECT TOP 1 @c_ReceiptLineNo = rd.ReceiptLineNumber
   FROM RECEIPTDETAIL rd (NOLOCK)
   WHERE rd.ReceiptKey = @c_Receiptkey
   ORDER BY rd.ReceiptLineNumber DESC

   SET @n_ReceiptLineNo = CONVERT(INT, @c_ReceiptLineNo)
   
   SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey = @c_Storerkey                                                  --(Wan01) 
         ,pd.Sku
         ,pd.Lot
         ,pd.Loc
         ,pd.ID
         ,Qty = ISNULL(SUM(pd.qty),0)
         ,la.Lottable01
         ,la.Lottable02
         ,la.Lottable03
         ,Lottable04 = ISNULL(la.Lottable04, '1900-01-01')
         ,Lottable05 = ISNULL(la.Lottable05, '1900-01-01')
         ,la.Lottable06
         ,la.Lottable07
         ,la.Lottable08
         ,la.Lottable09
         ,la.Lottable10
         ,la.Lottable11
         ,la.Lottable12
         ,Lottable13 = ISNULL(la.Lottable13, '1900-01-01')
         ,Lottable14 = ISNULL(la.Lottable14, '1900-01-01')
         ,Lottable15 = ISNULL(la.Lottable15, '1900-01-01')
   FROM WAVEDETAIL wd (NOLOCK)
   JOIN ORDERS oh (NOLOCK) ON oh.Orderkey = wd.Orderkey
   JOIN PICKDETAIL pd (NOLOCK) ON pd.orderkey = wd.orderkey
   JOIN LOTATTRIBUTE la (NOLOCK) ON la.lot = pd.Lot
   WHERE oh.ExternOrderKey  = @c_ExternOrderkey
   --AND   pd.Sku = @c_Sku
   GROUP BY pd.Sku                                                                  --(Wan01) 
         ,  pd.Lot
         ,  pd.Loc
         ,  pd.ID
         ,  la.Lottable01
         ,  la.Lottable02
         ,  la.Lottable03
         ,  ISNULL(la.Lottable04, '1900-01-01')
         ,  ISNULL(la.Lottable05, '1900-01-01')
         ,  la.Lottable06
         ,  la.Lottable07
         ,  la.Lottable08
         ,  la.Lottable09
         ,  la.Lottable10
         ,  la.Lottable11
         ,  la.Lottable12
         ,  ISNULL(la.Lottable13, '1900-01-01')
         ,  ISNULL(la.Lottable14, '1900-01-01')
         ,  ISNULL(la.Lottable15, '1900-01-01')
   ORDER BY MAX(pd.Storerkey)                                                       --(Wan01)                                   
         ,  pd.Sku

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO @c_Storerkey
                              , @c_Sku
                              , @c_Lot
                              , @c_Loc
                              , @c_ID
                              , @n_Qty
                              , @c_Lottable01
                              , @c_Lottable02
                              , @c_Lottable03
                              , @d_Lottable04
                              , @d_Lottable05
                              , @c_Lottable06
                              , @c_Lottable07
                              , @c_Lottable08
                              , @c_Lottable09
                              , @c_Lottable10
                              , @c_Lottable11
                              , @c_Lottable12
                              , @d_Lottable13
                              , @d_Lottable14
                              , @d_Lottable15

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @n_QtyRemaining = @n_Qty
      IF @c_Sku_Prior <> @c_Sku
      BEGIN
         SET @n_QtyExpected = 0
      END

      GET_NEXT_REC:
      IF @n_QtyExpected = 0
      BEGIN
         SET @c_ReceiptLineNumber = ''
         SELECT TOP 1 @n_QtyExpected = rd.QtyExpected
               , @c_ReceiptLineNumber = rd.ReceiptLineNumber
         FROM RECEIPTDETAIL rd (NOLOCK)
         WHERE rd.ReceiptKey = @c_Receiptkey
         AND   rd.Sku = @c_Sku
         AND   rd.BeforeReceivedQty = 0
         AND   rd.FinalizeFlag = 'N'
         ORDER BY rd.ReceiptLineNumber
      END

      IF @c_ReceiptLineNumber > ''
      BEGIN
         IF @n_Qty > @n_QtyExpected
         BEGIN
            SET @n_Qty = @n_QtyExpected
         END

         SET @n_QtyExpected = @n_QtyExpected - @n_Qty
         SET @n_QtyRemaining= @n_QtyRemaining- @n_Qty
         
         
         --(Wan01) - START
         SET @c_Lottable06 = '' 
         SELECT @c_Lottable07 = dbo.fnc_CalcShelfLifeBUD(@c_Storerkey,@c_Sku, @d_Lottable04,@d_Lottable13)
         --(Wan01) - END

         IF @n_QtyExpected = 0
         BEGIN
            UPDATE RECEIPTDETAIL WITH (ROWLOCK)
               SET UserDefine01 = CONVERT(NVARCHAR(10),QtyExpected)
                  ,QtyExpected = @n_Qty
                  ,BeforeReceivedQty = @n_Qty
                  ,ToLoc=@c_Loc
              ,ToId=@c_ID
              ,Lottable01= CASE WHEN ISNULL(Lottable01,'')='' THEN 'ML11' ELSE Lottable01 END
              ,Lottable02=@c_Lottable02
              ,Lottable04=@d_Lottable04
              ,Lottable06=@c_Lottable06                                             --(Wan01)
              ,Lottable07=@c_Lottable07                                             --(Wan01)
              ,Lottable09=@c_Lottable09
              ,Lottable10=@c_Lottable10
              ,Lottable11=@c_Lottable11
              ,Lottable12=@c_Lottable12
              ,Lottable13=@d_Lottable13
              ,Lottable14=@d_Lottable14
              ,Lottable15=@d_Lottable15
                  ,TrafficCop = NULL
            WHERE ReceiptKey = @c_Receiptkey
            AND ReceiptLineNumber = @c_ReceiptLineNumber

            IF @n_QtyRemaining > 0
            BEGIN
               SET @n_Qty = @n_QtyRemaining
               GOTO GET_NEXT_REC
            END
         END
         ELSE
         BEGIN
            SET @n_ReceiptLineNo = @n_ReceiptLineNo + 1
            
            SET @c_ReceiptLineNo = RIGHT('00000' + CONVERT(NVARCHAR(5),@n_ReceiptLineNo),5)
            INSERT INTO RECEIPTDETAIL (Receiptkey
                                      ,ReceiptLineNumber
                                      ,Storerkey
                                      ,Sku
                                      ,Packkey
                                      ,UOM
                                      ,QtyExpected
                                      ,BeforeReceivedQty
                                      ,ToLoc
                                      ,ToID
                                      ,PutawayLoc
                                      ,ExternReceiptKey
                                      ,POKey
                                      ,POLineNumber
                                      ,ExternPOKey
                                      ,ExternLineNo
                                      ,Vesselkey
                                      ,Voyagekey
                                      ,Lottable01
                                      ,Lottable02
                                      ,Lottable03
                                      ,Lottable04
                                      --,Lottable05
                                      ,Lottable06
                                      ,Lottable07
                                      ,Lottable08
                                      ,Lottable09
                                      ,Lottable10
                                      ,Lottable11
                                      ,Lottable12
                                      ,Lottable13
                                      ,Lottable14
                                      ,Lottable15
                                      ,UserDefine01
                                      ,UserDefine02
                                      ,UserDefine03
                                      ,UserDefine04
                                      ,UserDefine05
                                      ,UserDefine06
                                      ,UserDefine07
                                      ,UserDefine08
                                      ,UserDefine09
                                      ,UserDefine10
                                      ,SubReasonCode
                                      ,Channel
                                      ,FinalizeFlag)
            SELECT Receiptkey
                  ,@c_ReceiptLineNo
                  ,Storerkey
                  ,Sku
                  ,Packkey
                  ,UOM
                  ,@n_Qty
                  ,@n_Qty
                  ,@c_Loc
                  ,@c_ID
                  ,PutawayLoc
                  ,ExternReceiptKey
                  ,POKey
                  ,POLineNumber
                  ,ExternPOKey
                  ,ExternLineNo
                  ,Vesselkey
                  ,Voyagekey
                  ,CASE WHEN ISNULL(Lottable01,'')='' THEN 'ML11' ELSE Lottable01 END
                  ,@c_Lottable02
                  ,Lottable03
                  ,@d_Lottable04
--                ,@d_Lottable05
                  ,@c_Lottable06 --(Wan01)      
                  --,CASE WHEN [dbo].[fnc_CalcShelfLifeBUD](@c_Storerkey,@c_Sku, @d_Lottable04,@d_Lottable13) 
                  --      IN ('ML18', 'ML13')
                  --      THEN '1'
                  --      ELSE '' END
                  ,@c_Lottable07--(wan01)[dbo].[fnc_CalcShelfLifeBUD](@c_Storerkey,@c_Sku, @d_Lottable04,@d_Lottable13)
                  ,Lottable08
                  ,@c_Lottable09
                  ,@c_Lottable10
                  ,@c_Lottable11
                  ,@c_Lottable12
                  ,@d_Lottable13
                  ,@d_Lottable14
                  ,@d_Lottable15
                  ,UserDefine01
                  ,@c_ReceiptLineNumber
                  ,UserDefine03
                  ,UserDefine04
                  ,UserDefine05
                  ,UserDefine06
                  ,UserDefine07
                  ,UserDefine08
                  ,UserDefine09
                  ,UserDefine10
                  ,SubReasonCode
                  ,Channel
                  ,FinalizeFlag
            FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_Receiptkey
            AND ReceiptLineNumber = @c_ReceiptLineNumber
         END
      END

      SET @c_Sku_Prior = @c_Sku
      FETCH NEXT FROM @CUR_PD INTO @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
                                 , @n_Qty
                                 , @c_Lottable01
                                 , @c_Lottable02
                                 , @c_Lottable03
                                 , @d_Lottable04
                                 , @d_Lottable05
                                 , @c_Lottable06
                                 , @c_Lottable07
                                 , @c_Lottable08
                                 , @c_Lottable09
                                 , @c_Lottable10
                                 , @c_Lottable11
                                 , @c_Lottable12
                                 , @d_Lottable13
                                 , @d_Lottable14
                                 , @d_Lottable15
   END
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   WHILE @n_Continue = 1
   BEGIN
      SET @n_ErrGroupKey = 0

      EXEC WM.lsp_FinalizeReceipt_Wrapper
         @c_ReceiptKey           = @c_Receiptkey
      ,  @c_ReceiptLineNumber    = ''
      ,  @b_Success              = @b_Success      OUTPUT
      ,  @n_Err                  = @n_Err          OUTPUT
      ,  @c_ErrMsg               = @c_ErrMsg       OUTPUT
      ,  @n_WarningNo            = @n_WarningNo    OUTPUT
      ,  @c_ProceedWithWarning   = @c_ProceedWithWarning
      ,  @c_UserName             =''
      ,  @n_ErrGroupKey          = @n_ErrGroupKey  OUTPUT
      ,  @n_SkipGenID            = 1

      SELECT TOP 1 @c_ErrMsg = ErrMsg FROM WM.WMS_Error_List (NOLOCK)
      WHERE WriteType = 'ERROR'
      AND   SourceType= 'lsp_FinalizeReceipt_Wrapper' and ErrGroupKey=@n_ErrGroupKey

      IF @@ROWCOUNT > 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

       IF (@c_ProceedWithWarning='Y')
        BEGIN
         break
        ENd

      SET @c_ProceedWithWarning = 'Y'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'msp_RCM_ASN_ULP_StockOwnerChange'
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
END -- procedure

GO