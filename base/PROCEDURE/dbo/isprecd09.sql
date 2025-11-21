SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRECD09                                          */
/* Creation Date: 23-MAR-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19225-[TW] EAT Exceed StorerConfig SP for ASN Trigger New*/
/*                                                                      */
/* Called By:isp_ReceiptDetailTrigger_Wrapper from Receiptdetail Trigger*/
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 25-MAR-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[ispRECD09]
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT,
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_TableName       NVARCHAR(30),
           @c_Listname        NVARCHAR(50),
           @c_UDF01           NVARCHAR(50),
           @c_Userdefine03    NVARCHAR(30) = '',
           @c_TransmitLogKey  NVARCHAR(10),
           @c_GetReceiptkey   NVARCHAR(10),
           @c_Receiptkey      NVARCHAR(10),
           @c_Option1         NVARCHAR(50),
           @c_Facility        NVARCHAR(20) = '',
           @c_ExtRectKey      NVARCHAR(50) = '',
           @c_NewOrderKey     NVARCHAR(10),  
           @c_RDSKU           NVARCHAR(20)= '',
           @c_RDUOM           NVARCHAR(10),
           @c_LOTTABLE02      NVARCHAR(30),
           @n_expectedqty     INT,
           @n_LineNo          INT,
           @c_RDLineNumber    NVARCHAR(10),
           @c_OrderLine       NVARCHAR(5),
           @c_GetOrderLine    NVARCHAR(5),
           @c_getordkey       NVARCHAR(20),
           @c_GetExtRectKey   NVARCHAR(50) = '',
           @c_packkey         NVARCHAR(10) = ''
       

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   SET @c_TableName = 'WSGRRCPTLOG'
   SET @c_Listname  = 'RECTYPE'
   SET @c_UDF01     = 'GR'

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

     SELECT TOP 1 @c_Option1 = Option1
     FROM STORERCONFIG(NOLOCK)
     WHERE StorerKey = @c_Storerkey
     AND Configkey = 'ReceiptDetailTrigger_SP'
     AND Svalue = 'ispRECD09'


 SELECT TOP 1   @c_GetReceiptkey = R.Receiptkey
               ,@c_Facility = R.facility
               ,@c_ExtRectKey = R.ExternReceiptkey
      FROM #INSERTED I
      JOIN RECEIPT R (NOLOCK) ON I.Receiptkey = R.Receiptkey
      WHERE I.Storerkey = @c_Storerkey

--SELECT @c_Action '@c_Action'
   IF @c_Action IN ('INSERT')
   BEGIN
         --Check if Receipt.RecType is in Codelkup.Code where Listname = RECTYPE and UDF01 = GR
         IF EXISTS (SELECT 1 FROM dbo.RECEIPT R (NOLOCK) 
                    WHERE R.RecType = 'RTRF' and R.DocType = 'R'
                    AND R.Storerkey = @c_Storerkey AND R.ReceiptKey = @c_GetReceiptkey)
         BEGIN

       IF NOT EXISTS (SELECT 1 FROM ORDERS OH (NOLOCK) WHERE OH.StorerKey = @c_Storerkey AND OH.ExternOrderKey = @c_ExtRectKey AND OH.type = @c_Option1)
       BEGIN

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
            VALUES (@c_NewOrderKey, @c_ExtRectKey, @c_StorerKey, '', '', '', '', '', '', @c_Option1)
  

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN

               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to Orders table Failed (ispRECD09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_SP
            END
         END
         ELSE
         BEGIN

            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63820
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate OrderKey Failed! (ispRECD09)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            GOTO QUIT_SP
         END
       END

            SET @n_LineNo = 1

 
            --Loop Every sku and insert into Orders and Orderdetail table
            DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT TOP 1 RD.ReceiptKey, RD.sku,RD.uom,RD.QTYEXPECTED,RD.LOTTABLE02,RD.ExternReceiptKey,RD.ReceiptLineNumber,RD.PackKey--,oh.OrderKey
            FROM RECEIPTDETAIL RD (NOLOCK) 
         --   JOIN dbo.ORDERS OH (NOLOCK) ON OH.ExternOrderKey=RD.ExternReceiptKey AND oh.StorerKey=rd.StorerKey
            WHERE RD.ReceiptKey=@c_GetReceiptkey
            ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber DESC

            OPEN CUR_LOOP

            FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_RDSKU,@c_RDUOM,@n_expectedqty,@c_LOTTABLE02,@c_GetExtRectKey,@c_RDLineNumber,@c_packkey

            WHILE @@FETCH_STATUS <> -1
            BEGIN
              SET @c_getordkey = ''
               SELECT @b_success = 1

               SELECT @c_getordkey = OH.Orderkey
               FROM dbo.ORDERS OH (NOLOCK)
               WHERE OH.ExternOrderKey=@c_GetExtRectKey

               IF NOT EXISTS (SELECT 1 FROM dbo.ORDERDETAIL OD WITH (NOLOCK) WHERE OD.OrderKey=@c_getordkey AND OD.sku = @c_RDSKU AND OD.OrderLineNumber=@c_RDLineNumber)
               BEGIN
                  

              -- SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5) 


               INSERT INTO ORDERDETAIL   (OrderKey,            OrderLineNumber,     ExternOrderKey,
                                             ExternLineNo,      StorerKey,           SKU,
                                             OriginalQty,      OpenQty,              UOM,                 
                                             Lottable02, Lottable06,PackKey)
                              VALUES        (@c_getordkey,      @c_RDLineNumber,        @c_ExtRectKey,
                                             '',      @c_StorerKey,        @c_RDSKU,
                                             @n_expectedqty, @n_expectedqty,      @c_RDUOM,         'ECOM',
                                             @c_Lottable02,@c_packkey)

               SELECT @n_err = @@ERROR

               SET @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                      SET @n_continue = 3
                      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                      SET @n_err = 63830   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to ORDERDETAIL Failed (ispRECD09)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                      GOTO QUIT_SP
                  END

                END
                 -- SELECT @n_LineNo = @n_LineNo + 1

               FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_RDSKU,@c_RDUOM,@n_expectedqty,@c_LOTTABLE02,@c_GetExtRectKey,@c_RDLineNumber,@c_packkey
            END --Cursor
         END

   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispRECD09'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO