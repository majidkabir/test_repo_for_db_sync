SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ18                                            */
/* Creation Date: 20-Sep-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-10609 - CN_PVH QHW_Exceed_PostFinalizeReceiptSP            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ18]  
(     @c_Receiptkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
  ,   @b_debug       NVARCHAR(1) = '0'
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue       INT,
           @n_StartTranCount INT,
           @c_Storerkey      NVARCHAR(15),
           @c_Facility       NVARCHAR(5),
           @c_authority      NVARCHAR(30),
           @c_option1        NVARCHAR(50),
           @c_option2        NVARCHAR(50),
           @c_option3        NVARCHAR(50),
           @c_option4        NVARCHAR(50),
           @c_option5        NVARCHAR(4000),
           @c_Sku            NVARCHAR(20)

   --CS01 Start         
   DECLARE  
           @n_StartTCnt             INT
         , @c_DocType               NVARCHAR(10)
         , @c_RecType               NVARCHAR(10)

         , @c_Packkey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_UDF10                 NVARCHAR(30)
         , @c_UDF02                 NVARCHAR(30)

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
         , @c_RecGrp                NVARCHAR(20)
         , @c_ExtRecKey             NVARCHAR(20)
         , @c_lot                   NVARCHAR(10)
         , @c_Lot01                 NVARCHAR(18)
         , @c_Lot02                 NVARCHAR(18)
         , @c_Lot03                 NVARCHAR(18)
         , @c_Lot06                 NVARCHAR(30)
         , @d_Lot04                 DATETIME
         , @d_Lot05                 DATETIME
         , @c_Lot07                 NVARCHAR(30)
         , @c_Lot08                 NVARCHAR(30)
         , @c_Lot09                 NVARCHAR(30)
         , @c_Lot10                 NVARCHAR(30)
         , @c_Lot11                 NVARCHAR(30)
         , @c_Lot12                 NVARCHAR(30)
         , @d_Lot13                 DATETIME
         , @d_Lot14                 DATETIME
         , @d_Lot15                 DATETIME


 
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
         ,  UserDefine02   NVARCHAR(30)   NULL
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
      --CS01 End                               
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                    
   
   --CS01 Start
   SET @c_Facility = ''
   SET @c_Storerkey= ''
   SET @c_DocType  = ''
   SET @c_RecType  = ''
   SET @c_UDF10 = ''
   SET @c_UDF02 = ''
   SET @c_RecGrp = ''
   SET @c_ExtRecKey = ''
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
  
   SELECT TOP 1 @c_Facility = RECEIPT.Facility
         ,@c_Storerkey= RECEIPT.Storerkey
         ,@c_DocType  = RECEIPT.DocType
         ,@c_RecType  = RECEIPT.RecType
         ,@c_UDF10    = RECEIPT.userdefine10
         ,@c_UDF02    = RECEIPT.userdefine02
         ,@c_RecGrp   = RECEIPT.ReceiptGroup
         ,@c_ExtRecKey = RECEIPT.externreceiptkey
   FROM   RECEIPT WITH (NOLOCK)
   WHERE  RECEIPT.ReceiptKey = @c_ReceiptKey
   --AND    RECEIPT.DocType = 'R'
   --AND    RECEIPT.userdefine02='TU'
    AND    RECEIPT.RecType <> 'NIF'

/*   IF @c_DocType <> 'R'
   BEGIN
      GOTO QUIT_SP
   END 
    
   IF @c_RecType = 'NIF'
   BEGIN
      GOTO QUIT_SP
   END 

   IF @c_UDF02 <> 'TU'
   BEGIN
      GOTO QUIT_SP
   END
   */

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
      
      SELECT TOP 1 @c_AdjustmentType2 = UDF03
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PVHQHWASN'
      AND   Storerkey = @c_Storerkey
      AND   Short = @c_DocType
      AND   long = @c_RecGrp
     
      SET @c_ReasonCode = ''
      
      SELECT TOP 1 @c_ReasonCode = UDF04
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PVHQHWASN'
      AND   Storerkey = @c_Storerkey
      AND   Short = @c_DocType
      AND   long = @c_RecGrp
      
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

    BEGIN TRAN 

   SET @n_KeyNo = -1
   DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT KeyLineNo = ROW_NUMBER() OVER (PARTITION BY RECEIPTDETAIL.ReceiptKey
                                        , CASE WHEN sum(RECEIPTDETAIL.QtyExpected) > sum(RECEIPTDETAIL.QtyReceived) THEN 0 
                                          WHEN sum(RECEIPTDETAIL.QtyExpected) < sum(RECEIPTDETAIL.QtyReceived) THEN 5
                                          ELSE 9 END 
                                          ORDER BY 
                                          CASE WHEN sum(RECEIPTDETAIL.QtyExpected) > sum(RECEIPTDETAIL.QtyReceived) THEN 0 
                                               WHEN sum(RECEIPTDETAIL.QtyExpected) < sum(RECEIPTDETAIL.QtyReceived) THEN 5
                                               ELSE 9 END DESC)
         ,RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.Packkey
         ,RECEIPTDETAIL.UOM
         ,sum(RECEIPTDETAIL.QtyExpected)
         ,sum(RECEIPTDETAIL.QtyReceived)
   FROM RECEIPT WITH (NOLOCK)  
   JOIN RECEIPTDETAIL WITH (NOLOCK)  ON   RECEIPTDETAIL.ReceiptKey = RECEIPT.ReceiptKey
   JOIN   CODELKUP C WITH (NOLOCK) ON C.ListName = 'PVHQHWASN'
                                   AND   C.Storerkey = RECEIPT.Storerkey
                                   AND   C.Short = RECEIPT.DocType
                                   AND   C.long = RECEIPT.ReceiptGroup
   WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
   AND    RECEIPT.RecType <> 'NIF'
   AND ISNULL(c.udf03,'') <> ''
   GROUP BY RECEIPTDETAIL.ReceiptKey, RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.Packkey
         ,RECEIPTDETAIL.UOM
   ORDER BY CASE WHEN sum(RECEIPTDETAIL.QtyExpected) > sum(RECEIPTDETAIL.QtyReceived) THEN 0 
                 WHEN sum(RECEIPTDETAIL.QtyExpected) < sum(RECEIPTDETAIL.QtyReceived) THEN 5
                 ELSE 9 END DESC

   OPEN CUR_RECDET
   
   FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                 ,  @c_Sku
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_QtyExpected
                                 ,  @n_QtyReceived
                                  

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_QtyVariance = 0
	  SET @c_lot = ''

	  IF @b_debug = '1'
	  BEGIN
	     SELECT @c_Sku '@c_Sku',@n_QtyExpected '@n_QtyExpected', @n_QtyReceived '@n_QtyReceived'
	  END

      IF @n_QtyExpected > @n_QtyReceived
      BEGIN
         SET @n_QtyVariance = @n_QtyExpected - @n_QtyReceived
         SET @c_AdjustmentType= @c_AdjustmentType1

       SELECT TOP 1  @c_Lot01 = RECEIPTDETAIL.lottable01
             ,@c_Lot02 = RECEIPTDETAIL.lottable02
             ,@c_Lot03 = RECEIPTDETAIL.lottable03
             ,@d_Lot04 = RECEIPTDETAIL.lottable04
             ,@d_Lot05 = RECEIPTDETAIL.lottable05
             ,@c_Lot06 = RECEIPTDETAIL.lottable06
             ,@c_Lot07 = RECEIPTDETAIL.lottable07
             ,@c_Lot08 = RECEIPTDETAIL.lottable08
             ,@c_Lot09 = RECEIPTDETAIL.lottable09
             ,@c_Lot10 = RECEIPTDETAIL.lottable10
             ,@c_Lot11 = RECEIPTDETAIL.lottable11
             ,@c_Lot12 = RECEIPTDETAIL.lottable12
             ,@d_Lot13 = RECEIPTDETAIL.lottable13
             ,@d_Lot14 = RECEIPTDETAIL.lottable14
             ,@d_Lot15 = RECEIPTDETAIL.lottable15
       FROM RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK)
       WHERE RECEIPTDETAIL.Receiptkey = @c_ReceiptKey
	   AND  RECEIPTDETAIL.SKU=@c_Sku
         --SET @c_ReasonCode = @c_ShortReasonCode
      END
      ELSE 
      BEGIN

         SET @n_QtyVariance = @n_QtyReceived - @n_QtyExpected
         SET @c_AdjustmentType= @c_AdjustmentType2

       SELECT TOP 1 @c_lot = AJD.LOT
       FROM ADJUSTMENT ADJ WITH (NOLOCK)
       JOIN ADJUSTMENTDETAIL AJD WITH (NOLOCK) ON AJD.AdjustmentKey = ADJ.AdjustmentKey
       WHERE ADJ.UserDefine01 = @c_ReceiptKey
	   AND AJD.SKU = @c_Sku

       IF ISNULL(@c_lot,'' ) <> ''
       BEGIN
       SELECT TOP 1  @c_Lot01 = LOTT.lottable01
             ,@c_Lot02 = LOTT.lottable02
             ,@c_Lot03 = LOTT.lottable03
             ,@d_Lot04 = LOTT.lottable04
             ,@d_Lot05 = LOTT.lottable05
             ,@c_Lot06 = LOTT.lottable06
             ,@c_Lot07 = LOTT.lottable07
             ,@c_Lot08 = LOTT.lottable08
             ,@c_Lot09 = LOTT.lottable09
             ,@c_Lot10 = LOTT.lottable10
             ,@c_Lot11 = LOTT.lottable11
             ,@c_Lot12 = LOTT.lottable12
             ,@d_Lot13 = LOTT.lottable13
             ,@d_Lot14 = LOTT.lottable14
             ,@d_Lot15 = LOTT.lottable15
       FROM lotattribute LOTT WITH (NOLOCK)
       WHERE LOTT.lot = @c_lot

       END
	   ELSE
	   BEGIN
	     SELECT TOP 1  @c_Lot01 = RECEIPTDETAIL.lottable01
             ,@c_Lot02 = RECEIPTDETAIL.lottable02
             ,@c_Lot03 = RECEIPTDETAIL.lottable03
             ,@d_Lot04 = RECEIPTDETAIL.lottable04
             ,@d_Lot05 = RECEIPTDETAIL.lottable05
             ,@c_Lot06 = RECEIPTDETAIL.lottable06
             ,@c_Lot07 = RECEIPTDETAIL.lottable07
             ,@c_Lot08 = RECEIPTDETAIL.lottable08
             ,@c_Lot09 = RECEIPTDETAIL.lottable09
             ,@c_Lot10 = RECEIPTDETAIL.lottable10
             ,@c_Lot11 = RECEIPTDETAIL.lottable11
             ,@c_Lot12 = RECEIPTDETAIL.lottable12
             ,@d_Lot13 = RECEIPTDETAIL.lottable13
             ,@d_Lot14 = RECEIPTDETAIL.lottable14
             ,@d_Lot15 = RECEIPTDETAIL.lottable15
       FROM RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK)
       WHERE RECEIPTDETAIL.Receiptkey = @c_ReceiptKey
	   AND  RECEIPTDETAIL.SKU=@c_Sku
	   END

         --SET @c_ReasonCode = @c_OverReasonCode
      END


	  IF @b_debug = '1'
	  BEGIN
	    SELECT @c_ReceiptKey '@c_ReceiptKey',@c_Sku '@c_Sku',@c_Lot01 '@c_Lot01',@c_Lot02 '@c_Lot02',@d_Lot04 '@d_Lot04',@c_Lot06 '@c_Lot06'
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
              --SET @c_AdjustmentType = @c_AdjustmentType1
               END

               INSERT INTO #TMP_ADJ
               (  KeyNo
               ,  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               ,  UserDefine02
               )
               VALUES 
               (  @n_KeyNo
               ,  @c_AdjustmentType
               ,  @c_Storerkey
               ,  @c_Facility
               ,  @c_ReceiptKey
               ,  @c_ExtRecKey 
               )
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60020  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJ Table. (ispASNFZ18)' 
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
               (  @n_KeyNo
               ,  @c_AdjustmentLineNumber
               ,  @c_StorerKey
               ,  @c_Sku
               ,  @c_Packkey
               ,  @c_UOM
               ,  @c_lot
               ,  @c_Loc
               ,  ''
               ,  @n_QtyVariance
               ,  @c_ReasonCode
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
               SET @n_err = 60030  
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJDET Table. (ispASNFZ18)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP
            END

            SET @n_Cnt = @n_Cnt + 1
         END
      END

	  IF @b_debug ='1'
	  BEGIN
	     SELECT '#TMP_ADJ', *  FROM #TMP_ADJ
		 SELECT '#TMP_ADJDET',* FROM #TMP_ADJDET
	  END

      FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                    ,  @c_Sku
                                    ,  @c_Packkey
                                    ,  @c_UOM
                                    ,  @n_QtyExpected
                                    ,  @n_QtyReceived 
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
         SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispASNFZ18)' 
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
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ##TMP_ADJ Table. (ispASNFZ18)' 
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
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update #TMP_ADJDET Table. (ispASNFZ18)' 
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
            ,  UserDefine02
            )
         SELECT 
               Adjustmentkey
            ,  AdjustmentType
            ,  Storerkey
            ,  Facility
            ,  UserDefine01
            ,  Userdefine02
         FROM #TMP_ADJ
         WHERE Adjustmentkey = @c_Adjustmentkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60070  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispASNFZ18)' 
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
            SET @n_err = 60080  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispASNFZ18)' 
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

 --   select @c_AdjustmentKey '@c_AdjustmentKey'
	--select * from ADJUSTMENT (nolock) where adjustmentkey=@c_AdjustmentKey
	--select * from ADJUSTMENTDETAIL (nolock) where adjustmentkey=@c_AdjustmentKey

      EXECUTE isp_FinalizeADJ
               @c_ADJKey   = @c_AdjustmentKey
            ,  @b_Success  = @b_Success OUTPUT 
            ,  @n_err      = @n_err     OUTPUT 
            ,  @c_errmsg   = @c_errmsg  OUTPUT   

      IF @n_err <> 0  
      BEGIN 
         SET @n_continue= 3 
         SET @n_err  = 60090
         SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ18)'
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
		    ,TrafficCop = NULL  
         WHERE AdjustmentKey = @c_AdjustmentKey


         IF @n_err <> 0  
         BEGIN 
            SET @n_continue= 3 
            SET @n_err  = 60090
            SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ18)'
            GOTO QUIT_SP 
         END
      END

      FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
   END 
   CLOSE CUR_ADJ
   DEALLOCATE CUR_ADJ
   --CS01 End                 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ18'
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
    
END

GO