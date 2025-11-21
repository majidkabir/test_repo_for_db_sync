SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* SP: ispPopulateTOASN_hasbro                                          */
/* Creation Date: 01st DEC 2022                                         */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: Populate ASN Detail from ORDERS                             */
/*                                                                      */
/* Usage: WMS-21178 - [CN] HasBro Auto MBOL to ASN NEW                  */
/*                                                                      */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 01-Dec-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/* 25-Apr-2023  CSCHONG  1.1  WMs-21178 fix auto generate asn issue(CS01)*/
/* 15-Jun-2023  WLChooi  1.2  WMS-22835 - Modify Column (WL01)          */
/* 01-Aug-2023  NJOW01   1.3  WMS-23264	Change lottable02 mapping       */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateTOASN_hasbro]
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExternReceiptKey      NVARCHAR(20),
           @c_SKU                   NVARCHAR(20),
           @c_PackKey               NVARCHAR(10),
           @c_UOM                   NVARCHAR(5),
           @c_SKUDescr              NVARCHAR(60),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(20),
           @c_ExternOrderLine       NVARCHAR(10)

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
           @n_ShippedQty            int

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                int,
           @c_ConsigneeKey          NVARCHAR(15),
           @c_MBStatus              NVARCHAR(10),
           @n_ExpectedQty           int,
           @n_QtyReceived           int,
           @n_RemainExpectedQty     int,
           @c_Toloc                 NVARCHAR(30),
           @c_ToID                  NVARCHAR(30) ,
           @c_ToLot                 NVARCHAR(30),
           @c_rhudf02               NVARCHAR(10),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_Getmbolkey            NVARCHAR(20),
           @n_ctnord                INT,
           @c_UDF01                 NVARCHAR(50),
           @c_UDF02                 NVARCHAR(50),
           @c_UDF03                 NVARCHAR(50),   --CS01
           @c_ExternLineNo          NVARCHAR(20),
           @c_AltSKU                NVARCHAR(20),
           @c_Dropid                NVARCHAR(20),
           @c_channel               NVARCHAR(80),
           @c_GetOrderkey           NVARCHAR(20),
           @c_GetSKU                NVARCHAR(20),
           @c_ODExtLineNo           NVARCHAR(10),
           @c_MBOtherReference      NVARCHAR(50),
           @c_ReceiptLineNo         NVARCHAR(5),
           @n_cnt                   INT,
           @c_pokey                 NVARCHAR(20),
           @c_Rectype               NVARCHAR(20),
           @c_getStorerkey          NVARCHAR(20) =''

   DECLARE @n_continue              INT,
           @b_success               INT,
           @n_err                   INT,
           @c_errmsg                NVARCHAR(255),
           @n_StartTranCnt          INT

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = '', @n_StartTranCnt = @@TRANCOUNT 

   --Retrieve info
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        SET @c_Getmbolkey=''
        SET @n_ctnord = 1
        SET @c_getStorerkey = '18906'   

        SELECT @c_Getmbolkey=oh.mbolkey,
               @c_Storerkey = oh.Storerkey  
        FROM ORDERS oh (NOLOCK)
        WHERE oh.OrderKey=@c_OrderKey

        SELECT @c_MBStatus = MB.Status
              ,@c_MBOtherReference = MB.OtherReference
        FROM dbo.MBOL MB WITH (NOLOCK)
        WHERE MB.MbolKey = @c_Getmbolkey

       --IF @c_MBStatus <>'9'
       --BEGIN
       --     GOTO QUIT_SP
       --END


       SELECT @n_ctnord = COUNT (DISTINCT oh.orderkey)
       FROM ORDERS oh (NOLOCK)
       WHERE oh.MBOLKey=@c_Getmbolkey

       SELECT @c_UDF01 = ISNULL(UDF01,'')
             ,@c_UDF02 = ISNULL(udf02,'')
             ,@c_UDF03 = ISNULL(udf03,'')       --CS01
       FROM dbo.CODELKUP (NOLOCK)
       WHERE Storerkey = @c_getStorerkey AND listname='HASFAC' 


       IF @c_MBOtherReference NOT LIKE @c_UDF03 + '%'          --CS01 S
       BEGIN
            GOTO QUIT_SP
       END                                                      --CS01 E


      SELECT TOP 1
             @c_ExternReceiptKey = CASE WHEN @n_ctnord = 1 THEN ORDERS.ExternOrderkey ELSE '' END,
             @c_rhudf02 = ORDERS.Orderkey,
             @c_facility = @c_UDF01,
             @c_GetSKU  = ORDERDETAIL.SKU,
           --  @c_packkey  =   ORDERDETAIL.Packkey,
         --    @c_UOM      = ORDERDETAIL.UOM,
             @c_pokey    = @c_Getmbolkey,
             @c_Rectype = @c_UDF02
      FROM   ORDERS (NOLOCK)
      --JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      JOIN   ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
      ORDER BY ORDERDETAIL.orderlinenumber

      IF @@ROWCOUNT = 0
         GOTO QUIT_SP

   END

   -- Create receipt
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)
                 WHERE POKey = @c_pokey
                 --AND ExternReceiptKey = @c_ExternReceiptKey
                 AND StorerKey = @c_StorerKey)
      BEGIN
          GOTO QUIT_SP
      END
      ELSE
      BEGIN
         --IF ISNULL(@c_StorerKey,'') <> ''
         --BEGIN
            -- get next receipt key
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
               "RECEIPT"
               , 10
               , @c_NewReceiptKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT


            IF @b_success = 1
            BEGIN
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptGroup, Facility,RecType,DocType, carriername, UserDefine01,UserDefine02,userdefine10,POKey, MBOLKey)   --WL01
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_getStorerkey, '',@c_facility,@c_Rectype,'A','','','','','',@c_Getmbolkey)   --WL01

                  SET @n_err = @@Error

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                     SET @n_err = 63498   
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Error on Table Receipt (ispPopulateTOASN_hasbro)' + ' ( ' + 
                                   ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
                  END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! (ispPopulateTOASN_hasbro)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            END
      END
   END

   -- Create receiptdetail
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_OrderLine = SPACE(5), @n_LineNo = 0
      SELECT @c_ExternOrderLine = SPACE(5)


      DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,
                 LOTATTRIBUTE.Lottable03,
                 OD.ExternLineNo,
                 OD.AltSku,
                 ISNULL(LOTATTRIBUTE.Lottable07,''),
                 ISNULL(LOTATTRIBUTE.Lottable08,''),
                 P.PackUOM3,P.PackKey,
                 PICKDETAIL.SKU,
                 PICKDETAIL.dropID,
                 LOTATTRIBUTE.Lottable02  --NJOW01
          FROM PICKDETAIL (NOLOCK)
          JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = Pickdetail.orderkey AND OD.OrderLineNumber=Pickdetail.orderlinenumber
                                             AND OD.StorerKey =Pickdetail.storerkey AND OD.sku = Pickdetail.sku
          JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
          JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.sku
          JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
          WHERE PICKDETAIL.OrderKey = @c_OrderKey
          GROUP BY  LOTATTRIBUTE.Lottable03,LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08,
                   PICKDETAIL.SKU,PICKDETAIL.dropID,OD.ExternLineNo,
                   OD.AltSku,P.PackUOM3,P.PackKey, LOTATTRIBUTE.Lottable02 --NJOW01

      OPEN PICK_CUR

      FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable03,@c_ODExtLineNo,@c_AltSKU,@c_Lottable07, @c_Lottable08,@c_UOM,@c_PackKey,
                                    @c_sku,@c_dropid, @c_Lottable02  --NJOW01 

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         --IF ISNULL(@n_LineNo, 0) = 0
         --BEGIN
         --   SET @n_LineNo = 1
         --END
         --ELSE
         --BEGIN
            SET @n_LineNo = @n_LineNo + 1
         --END

         SELECT @c_ReceiptLine = RIGHT( '0000' + LTRIM(RTRIM(CAST(@n_LineNo AS NVARCHAR(5 )))), 5)


         IF @n_QtyReceived IS NULL
            SELECT @n_QtyReceived = 0

         INSERT INTO RECEIPTDETAIL (ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, Sku, AltSku, POKey
                                  , ExternPoKey, QtyExpected, QtyReceived, UserDefine01, ToLoc, Lottable01, Lottable02
                                  , Lottable03, Lottable04, Lottable05, Lottable06, Lottable07, Lottable08, Lottable09
                                  , Lottable10, Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, BeforeReceivedQty
                                  , ToId, ToLot, Channel, PackKey, UOM)
         VALUES (@c_NewReceiptKey, @c_ReceiptLine, @c_ExternReceiptKey, @c_ODExtLineNo, @c_getStorerkey, @c_SKU, @c_AltSKU
               , '', @c_OrderKey, ISNULL(@n_QtyReceived, 0), 0, @c_Dropid, '', '', @c_Lottable02, @c_Lottable03, NULL, NULL, ''   --WL01  --NJOW01
               , @c_Lottable07, @c_Lottable08, '', '', '', '', NULL, NULL, NULL, ISNULL(@n_QtyReceived, 0), '', '', ''
               , @c_PackKey, @c_UOM)

         FETCH NEXT FROM PICK_CUR
            INTO @n_QtyReceived, @c_Lottable03,@c_ODExtLineNo,@c_AltSKU,@c_Lottable07, @c_Lottable08,@c_UOM,@c_PackKey,
                                    @c_sku,@c_dropid, @c_Lottable02 --NJOW01
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE PICK_CUR
      DEALLOCATE PICK_CUR
   END

   --Finalize
   --IF @n_continue = 1 OR @n_continue = 2
   --BEGIN
   --   SET @n_cnt = 0

   --   ;WITH ORD AS (SELECT PD.Sku, SUM(PD.Qty) AS Qty
   --                FROM PICKDETAIL PD (NOLOCK)
   --                WHERE PD.Orderkey = @c_Orderkey
   --                GROUP BY PD.Sku),
   --        REC AS (SELECT RD.Sku, SUM(BeforeReceivedQty) AS Qty
   --                FROM RECEIPT R (NOLOCK)
   --                JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
   --                WHERE R.Receiptkey = @c_NewReceiptKey
   --                GROUP BY RD.Sku)
   --   SELECT @n_cnt = COUNT(1)
   --   FROM ORD
   --   LEFT JOIN REC ON ORD.Sku = REC.Sku
   --   WHERE ORD.Qty <> ISNULL(REC.Qty,0)

   --   IF ISNULL(@n_cnt,0) <> 0
   --   BEGIN
   --      SET @n_continue = 3
   --      SET @n_err = 63530
   --      SET @c_errmsg='Create ASN Failed. ASN and Order Qty Not Tally. (ispPopulateTOASN_hasbro)'
   --   END
   --   ELSE
   --   BEGIN
   --      EXEC dbo.ispFinalizeReceipt
   --            @c_ReceiptKey        = @c_NewReceiptKey
   --           ,@b_Success           = @b_Success  OUTPUT
   --           ,@n_err               = @n_err     OUTPUT
   --           ,@c_ErrMsg            = @c_ErrMsg    OUTPUT

   --      IF @b_Success <> 1
   --      BEGIN
    --            SET @n_continue = 3
   --          SET @c_errmsg='ASN Finalize Error (ispPopulateTOASN_hasbro): ' +  RTRIM(ISNULL(@c_errmsg,''))
   --      END
   --   END
   --END

 QUIT_SP:

    IF @n_continue = 3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0

         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_StartTranCnt
            BEGIN
               COMMIT TRAN
            END
         END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_hasbro'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
        SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
    END
END

GO