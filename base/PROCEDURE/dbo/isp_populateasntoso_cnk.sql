SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_PopulateASNToSO_CNK                                          */
/* Creation Date: 19-04-2019                                            */
/* Copyright: LFL                                                       */
/* Written by: WLCHOOI                                                  */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: isp_PopulateASNToSO_Wrapper                               */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_PopulateASNToSO_CNK] 
   @c_ReceiptKey            NVARCHAR(10),
   @c_ReceiptLineNumber     NVARCHAR(5) = '',
   @b_Success               INT           OUTPUT,
   @n_Err                   INT           OUTPUT,
   @c_ErrMsg                NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternOrderkey        NVARCHAR(50),
           @c_Company               NVARCHAR(45),
           @c_Address1              NVARCHAR(45),
           @c_Address2              NVARCHAR(45),
           @c_Zip                   NVARCHAR(45),
           @c_ConsigneeKey          NVARCHAR(15),
           @c_NewOrderKey           NVARCHAR(10),
           @d_DeliveryDate          DATETIME,
           @c_Type                  NVARCHAR(10),
           @c_ReceiptLineNo         NVARCHAR(10),
           @c_PackKey               NVARCHAR(10),           

           @c_SKU                   NVARCHAR(20),
           @n_OriginalQty           INT,
           @c_ExternReceiptLine     NVARCHAR(10),

           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5)
           
   DECLARE @c_Lottable01            NVARCHAR(18),
           @c_Lottable02            NVARCHAR(18),
           @c_Lottable03            NVARCHAR(18),
           @d_Lottable04            DATETIME,
           @d_Lottable05            DATETIME,
           @c_Lottable06            NVARCHAR(30),
           @c_Lottable07            NVARCHAR(30),
           @c_Lottable08            NVARCHAR(30),
           @c_Lottable09            NVARCHAR(30),
           @c_Lottable10            NVARCHAR(30),
           @c_Lottable11            NVARCHAR(30),
           @c_Lottable12            NVARCHAR(30),
           @d_Lottable13            DATETIME,
           @d_Lottable14            DATETIME,
           @d_Lottable15            DATETIME,
           @n_ShippedQty            INT

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                INT,

           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           INT,
           @n_QtyReceived           INT,
           @n_RemainExpectedQty     INT,
           @c_loclast               NVARCHAR(30),
           @c_userdefine08          NVARCHAR(30) ,
           @c_userdefine07          NVARCHAR(30),
           @c_warehousereference    NVARCHAR(10)
    
   DECLARE @n_continue              int,
           @c_salesofftake          NVARCHAR(1), -- Add by June 27.Mar.02
           @n_StartTCnt             INT

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   -- Insert into Orders Header
   
   IF @n_continue = 1 OR @n_continue = 2  --001
   BEGIN         
      SELECT TOP 1 
             @c_ConsigneeKey   = ISNULL(RECEIPT.CarrierKey,''),
             @c_StorerKey      = ISNULL(RECEIPT.StorerKey,''), 
             @c_ExternOrderkey = ISNULL(RECEIPT.ExternReceiptKey,''),
             @c_Company        = ISNULL(STORER.Company,''),
             @c_Address1       = ISNULL(STORER.Address1,''),
             @c_Address2       = ISNULL(STORER.Address2,''),
             @c_Zip            = ISNULL(STORER.City,''),
             @d_DeliveryDate   = DATEADD(day, 1, GETDATE()),
             @c_Type           = ISNULL(CODELKUP.SHORT,''),
             @c_ReceiptLineNo  = RECEIPTDETAIL.ReceiptLineNumber
      FROM   RECEIPT (NOLOCK)
      JOIN   RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey
      JOIN   STORER (NOLOCK) ON STORER.StorerKey = RECEIPT.CarrierKey AND STORER.type = '2'
      JOIN   CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = 'ASNTYP2SO' AND CODELKUP.CODE = RECEIPT.RECTYPE AND RECEIPT.StorerKey = CODELKUP.Storerkey
      WHERE  RECEIPT.ReceiptKey = @c_ReceiptKey
      ORDER BY CASE WHEN CODELKUP.STORERKEY = '' THEN 2 ELSE 1 END, CODELKUP.STORERKEY

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
      BEGIN
         -- get next order key
         SELECT @b_success = 0
         EXECUTE   nspg_getkey
         "ORDER"
         , 10
         , @c_NewOrderKey OUTPUT
         , @b_success     OUTPUT
         , @n_err         OUTPUT
         , @c_errmsg      OUTPUT

         IF @b_success = 1
         BEGIN
            INSERT INTO ORDERS (OrderKey, ExternOrderKey, StorerKey, ConsigneeKey, C_Company, C_Address1, C_Address2, C_Zip, DeliveryDate, Type)
            VALUES (@c_NewOrderKey, @c_ExternOrderkey, @c_StorerKey, @c_ConsigneeKey, @c_Company, @c_Address1, @c_Address2, @c_Zip, @d_DeliveryDate, @c_Type)

            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_continue = 3  
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
               SET @n_err = 81085   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to Orders table Failed (isp_PopulateASNToSO_CNK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               GOTO QUIT_SP  
            END 
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate OrderKey Failed! (isp_PopulateASNToSO_CNK)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            GOTO QUIT_SP
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63530   
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": StorerKey is BLANK! (isp_PopulateASNToSO_CNK)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         GOTO QUIT_SP
      END
   END -- if continue = 1 or 2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_ReceiptLine = SPACE(5), @n_LineNo = 1
      SELECT @c_ExternReceiptLine = SPACE(5)

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1
      
         SELECT @c_SKU               = RECEIPTDETAIL.Sku,   
                @n_OriginalQty       = RECEIPTDETAIL.QtyReceived,
                @c_UOM               = RECEIPTDETAIL.UOM,   
                @c_Lottable02        = RECEIPTDETAIL.Lottable02,   
                @c_ReceiptLine       = RECEIPTDETAIL.ReceiptLineNumber,
                @c_ExternReceiptLine = RECEIPTDETAIL.ExternLineNo,
                @c_PackKey           = RECEIPTDETAIL.Packkey
          FROM RECEIPTDETAIL (NOLOCK)
         WHERE ( RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey ) AND             
               ( RECEIPTDETAIL.ReceiptLineNumber > @c_ReceiptLine )
         ORDER by RECEIPTDETAIL.ReceiptLineNumber
         IF @@ROWCOUNT = 0
            BREAK

         SET ROWCOUNT 0      
         IF dbo.fnc_RTrim(@c_ReceiptKey) IS NOT NULL AND 
            dbo.fnc_RTrim(@c_ReceiptLine) IS NOT NULL 
         BEGIN
              -- Lottable 01-15 Reserved for future usage
              DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT SUM(ISNULL(RECEIPTDETAIL.QtyReceived,0)) AS Qty,
                     RECEIPTDETAIL.Lottable01,
                     RECEIPTDETAIL.Lottable02,
                     RECEIPTDETAIL.Lottable03,
                     RECEIPTDETAIL.Lottable04,
                     RECEIPTDETAIL.Lottable05,
                     ISNULL(RECEIPTDETAIL.Lottable06,''),
                     ISNULL(RECEIPTDETAIL.Lottable07,''),
                     ISNULL(RECEIPTDETAIL.Lottable08,''),
                     ISNULL(RECEIPTDETAIL.Lottable09,''),
                     ISNULL(RECEIPTDETAIL.Lottable10,''),
                     ISNULL(RECEIPTDETAIL.Lottable11,''),
                     ISNULL(RECEIPTDETAIL.Lottable12,''),
                     RECEIPTDETAIL.Lottable13,
                     RECEIPTDETAIL.Lottable14,
                     RECEIPTDETAIL.Lottable15
                  FROM RECEIPTDETAIL (NOLOCK) 
                  WHERE (RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey AND
                         RECEIPTDETAIL.ReceiptLineNumber = @c_ReceiptLine)
                  GROUP BY RECEIPTDETAIL.StorerKey, RECEIPTDETAIL.SKU, 
                           RECEIPTDETAIL.Lottable01, RECEIPTDETAIL.Lottable02, RECEIPTDETAIL.Lottable03, RECEIPTDETAIL.Lottable04, RECEIPTDETAIL.Lottable05,
                           RECEIPTDETAIL.Lottable06, RECEIPTDETAIL.Lottable07, RECEIPTDETAIL.Lottable08, RECEIPTDETAIL.Lottable09, RECEIPTDETAIL.Lottable10,
                           RECEIPTDETAIL.Lottable11, RECEIPTDETAIL.Lottable12, RECEIPTDETAIL.Lottable13, RECEIPTDETAIL.Lottable14, RECEIPTDETAIL.Lottable15

               OPEN PICK_CUR
               
               FETCH NEXT FROM PICK_CUR
                  INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                       @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)
                  --SELECT @c_NewOrderKey,      @c_OrderLine,        @c_ExternOrderkey,
                  --                           @c_ReceiptLine,      @c_StorerKey,        @c_SKU,
                  --                           @n_OriginalQty,      @c_UOM,              @c_Lottable02 
                  IF @n_QtyReceived IS NULL
                     SELECT @n_QtyReceived = 0                      
   
                  INSERT INTO ORDERDETAIL   (OrderKey,            OrderLineNumber,     ExternOrderKey, 
                                             ExternLineNo,        StorerKey,           SKU, 
                                             OpenQty,             UOM,                 Lottable02,
                                             Packkey)
                              VALUES        (@c_NewOrderKey,      @c_OrderLine,        @c_ExternOrderkey,
                                             @c_ReceiptLine,      @c_StorerKey,        @c_SKU,
                                             @n_OriginalQty,      @c_UOM,              @c_Lottable02,
                                             @c_PackKey)
                  SET @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                      SET @n_continue = 3  
                      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                      SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to ORDERDETAIL Failed (isp_PopulateASNToSO_CNK)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                      GOTO QUIT_SP
                  END
                                             
   
                  SELECT @n_LineNo = @n_LineNo + 1
   
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE PICK_CUR
               DEALLOCATE PICK_CUR
            END
         END
      END -- WHILE
      SET ROWCOUNT 0
   END -- if continue = 1 or 2 001

   QUIT_SP:  
   WHILE @@TRANCOUNT < @n_starttcnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
          COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, "isp_PopulateASNToSO_CNK"  
--      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
END  

GO