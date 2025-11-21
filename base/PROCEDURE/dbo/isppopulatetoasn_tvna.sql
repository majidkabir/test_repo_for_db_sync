SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispPopulateToASN_TVNA                                            */
/* Creation Date: 22-FEB-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21764 - [AU]_ADIDAS_AutoCreateASN_New                   */
/*                                                                      */
/* Called By: ntrMBOLHeaderUpdate                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 22-FEB-2023  CSCHONG 1.0  DevOps Combine Script                      */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateToASN_TVNA] 
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
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),
           @c_Facility              NVARCHAR(5),
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
           @n_ShippedQty            INT

   DECLARE @c_NewReceiptKey         NVARCHAR(10),
           @c_ReceiptLine           NVARCHAR(5),
           @n_LineNo                INT,
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           INT,
           @n_QtyReceived           INT,
           @n_RemainExpectedQty     INT,
           @c_Toloc                 NVARCHAR(30),
           @c_ToID                  NVARCHAR(30),
           @c_ToLot                 NVARCHAR(30),
           @n_CtnOrder              INT,
           @c_mbolkey               NVARCHAR(20),
           @c_UDF01                 NVARCHAR(50),
           @c_UDF02                 NVARCHAR(50),
           @c_ExternLineNo          NVARCHAR(20),
           @c_WarehouseReference    NVARCHAR(10),
           @c_Dropid                NVARCHAR(20),
           @c_Channel               NVARCHAR(80),
           @c_ReceiptLineNo         NVARCHAR(5),
           @c_ReceiptGroup          NVARCHAR(10),
           @c_RecType               NVARCHAR(10),
           @c_DocType               NVARCHAR(10),
           @c_CarrierName           NVARCHAR(15),
           @n_cnt                   INT,
           @c_RHNotes               NVARCHAR(100),
           @c_Sellername            NVARCHAR(45),
           @c_sellercompany         NVARCHAR(45),
           @c_RDUDF01               NVARCHAR(30),
           @c_AutofinalizeREC       NVARCHAR(1) = '0',
           @c_RaiseErr              NVARCHAR(1) = 'N'     --CS01

    
   DECLARE @n_continue              INT,
           @b_success               INT,
           @n_err                   INT,
           @c_errmsg                NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   --Retrieve info
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN             
      SELECT TOP 1 @c_StorerKey          = ORDERS.StorerKey
                 , @c_ExternReceiptKey   = ORDERS.ExternOrderKey
                 , @c_ReceiptGroup       =  ORDERS.UserDefine09
                 , @c_RecType            = ORDERS.type
                 , @c_Sellername         = MBOL.ExternMBOLKey
                 , @c_CarrierName        = ORDERS.ConsigneeKey
                 , @c_Facility           = ORDERS.Facility
                 , @c_sellercompany      = ORDERS.salesman
                 , @c_UDF01              = ISNULL(C.UDF01, '')
                 , @c_UDF02              = ISNULL(C.UDF02, '')
              --   , @c_PackKey            = ORDERDETAIL.PackKey
              --   , @c_UOM                = ORDERDETAIL.UOM
                 , @c_WarehouseReference = ORDERS.OrderKey
                 , @c_mbolkey            = ORDERS.mbolkey 
                 , @c_RHNotes             = 'ASN for stocks pulled from WES'
                 , @c_AutofinalizeREC    =ISNULL(c.short,'0')
      FROM ORDERS (NOLOCK)
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      LEFT JOIN   MBOL        WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)    
      LEFT OUTER JOIN  CODELKUP C WITH (NOLOCK) ON (C.listname = 'ORDTYP2ASN' AND C.Code = ORDERS.type   
                                                and C.storerkey= ORDERS.StorerKey AND c.UDF01=orders.salesman)
      WHERE ORDERS.OrderKey = @c_OrderKey
      ORDER BY ORDERDETAIL.OrderLineNumber       
      
      IF @@ROWCOUNT = 0
         GOTO QUIT_SP
   END    

      SELECT @c_Toloc = LOC.LOC 
      FROM Codelkup CL (NOLOCK) 
      JOIN Orders (nolock) on CL.Storerkey = Orders.Storerkey and 
                              CL.Code = Orders.Type and CL.UDF01 = Orders.Salesman 
      JOIN  LOC (nolock) on LOC.Facility = Orders.Facility and CL.UDF02 = LOC.LOC
      WHERE Orders.Storerkey = @c_StorerKey and CL.Listname = 'ORDTYP2ASN' AND ORDERS.OrderKey = @c_OrderKey

    IF ISNULL(@c_Toloc,'') =''
    BEGIN
       SET @c_Toloc = ''
    END


--     --toid
--      Select @c_ToID = PLD.PalletKey 
--      FROM PackDetail PD (nolock)
--      join packheader PH (nolock) on PD.Pickslipno = PH.Pickslipno 
--      join orders O (nolock) on PH.orderkey = O.orderkey 
--      join CartonTrack CT (nolock) on PD.LabelNo = CT.LabelNo
--      and CT.KeyName = PD.Storerkey join PalletDetail PLD (nolock)
--      on PLD.CaseId = PD.LabelNo and PLD.UserDefine02 = CT.TrackingNo
--      and PLD.userdefine01 = O.orderkey
--      WHERE o.Storerkey = @c_StorerKey AND o.OrderKey = @c_OrderKey


----RD UDF01
--         Select @c_RDUDF01 = CT.TrackingNo 
--         FROM PackDetail PD (nolock) 
--         join packheader PH (nolock) on PD.Pickslipno = PH.Pickslipno 
--         join orders O (nolock) on PH.orderkey = O.orderkey join
--         CartonTrack CT (Nolock) on PD.LabelNo = CT.LabelNo 
--         and CT.KeyName = PD.Storerkey 
--         WHERE o.Storerkey = @c_StorerKey AND o.OrderKey = @c_OrderKey
--         Group By CT.TrackingNo, PD.SKU


   -- Create receipt
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN          
      IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                 WHERE WarehouseReference = @c_WarehouseReference
                 AND ExternReceiptKey = @c_ExternReceiptKey
                 AND StorerKey = @c_StorerKey)
      BEGIN
          GOTO QUIT_SP
      END
      ELSE
      BEGIN 
         -- get next receipt key
         SELECT @b_success = 0
         EXECUTE nspg_getkey
            'RECEIPT'
            , 10
            , @c_NewReceiptKey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, StorerKey, ReceiptGroup, Facility
                               , RecType, mbolkey, SellerName, SellerCompany, notes, WarehouseReference,DOCTYPE)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_StorerKey, @c_ReceiptGroup, @c_facility
                  , @c_RecType, @c_mbolkey, @c_Sellername, @c_sellercompany, @c_RHNotes, @c_WarehouseReference,'A')
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateToASN_TVNA)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
                 --LOTATTRIBUTE.Lottable01,
                 --LOTATTRIBUTE.Lottable02,
                 LOTATTRIBUTE.Lottable03,
                 --LOTATTRIBUTE.Lottable04,
                 --LOTATTRIBUTE.Lottable05,
                 --ISNULL(LOTATTRIBUTE.Lottable06,''),
                 --ISNULL(LOTATTRIBUTE.Lottable07,''),
                 --ISNULL(LOTATTRIBUTE.Lottable08,''),
                 --ISNULL(LOTATTRIBUTE.Lottable09,''),
                 --ISNULL(LOTATTRIBUTE.Lottable10,''),
                 --ISNULL(LOTATTRIBUTE.Lottable11,''),
                 --ISNULL(LOTATTRIBUTE.Lottable12,''),
                 --LOTATTRIBUTE.Lottable13,
                 --LOTATTRIBUTE.Lottable14,
                 --LOTATTRIBUTE.Lottable15,
                 OD.UOM,
                 PICKDETAIL.SKU,
              --   PICKDETAIL.CaseID,
                 PLD.PalletKey,
                 CT.TrackingNo,
                 OD.PackKey
          FROM PICKDETAIL (NOLOCK) 
          JOIN LotAttribute (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)
          JOIN SKU S WITH (NOLOCK) ON S.Storerkey = Pickdetail.Storerkey AND S.SKU = Pickdetail.sku
          --JOIN PackDetail PD (nolock) ON pd.LabelNo = PickDetail.DropId and PD.SKU = PickDetail.SKU
          --join packheader PH (nolock) on PD.Pickslipno = PH.Pickslipno 
          CROSS APPLY (SELECT DISTINCT PH.OrderKey AS orderkey ,pd.LabelNo AS labelno,PD.sku AS sku,PD.StorerKey AS storerkey
                       FROM PackDetail PD (nolock) 
                       JOIN packheader PH (nolock) on PD.Pickslipno = PH.Pickslipno 
                       WHERE pd.LabelNo = PickDetail.DropId and PD.SKU = PickDetail.SKU) AS PHD
          join orders O (nolock) on PHD.orderkey = O.orderkey 
          JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = O.OrderKey AND od.OrderLineNumber= Pickdetail.OrderLineNumber 
          join CartonTrack CT (nolock) on PHD.LabelNo = CT.LabelNo
               and CT.KeyName = PHD.Storerkey join PalletDetail PLD (nolock)
               on PLD.CaseId = PHD.LabelNo and PLD.UserDefine02 = CT.TrackingNo
               and PLD.userdefine01 = O.orderkey
          WHERE PICKDETAIL.OrderKey = @c_OrderKey 
          GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                  -- LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02,
                   LOTATTRIBUTE.Lottable03, 
                   --LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05,
                   --LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                   --LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15,
                   OD.UOM, PICKDETAIL.SKU,PLD.PalletKey,CT.TrackingNo,OD.PackKey  

      OPEN PICK_CUR
            
      FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable03,
                                    @c_UOM, @c_sku, @c_toid,@c_RDUDF01,@c_PackKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN         
         SET @n_LineNo = @n_LineNo + 1

         SELECT @c_ReceiptLine = RIGHT( '0000' + LTRIM(RTRIM(CAST(@n_LineNo AS NVARCHAR(5 )))), 5)
   
         IF @n_QtyReceived IS NULL
            SELECT @n_QtyReceived = 0                      
   
         INSERT INTO RECEIPTDETAIL (ReceiptKey,                ReceiptLineNumber,   ExternReceiptKey, 
                                    StorerKey,                 SKU, 
                                    QtyExpected,               QtyReceived,
                                    ToLoc,        Lottable03,              
                                    --Lottable01,                Lottable02,          Lottable03,       Lottable04,       Lottable05,
                                    --Lottable06,                Lottable07,          Lottable08,       Lottable09,       Lottable10,
                                    --Lottable11,                Lottable12,          Lottable13,       Lottable14,       Lottable15,
                                    BeforeReceivedQty,         Toid,                Tolot,            Channel,          Packkey,
                                    UOM,UserDefine01)
                     VALUES        (@c_NewReceiptKey,          @c_ReceiptLine,      @c_ExternReceiptKey,
                                    @c_StorerKey,              @c_SKU,
                                    ISNULL(@n_QtyReceived,0),  0,              
                                    @c_Toloc,@c_Lottable03,
                                    --@c_Lottable01,             @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05, 
                                    --@c_Lottable06,             @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                                    --@c_Lottable11,             @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15,
                                    CASE WHEN @c_Toloc <> '' THEN ISNULL(@n_QtyReceived,0) ELSE 0 END,  @c_toid,   '',         '',       @c_PackKey,
                                    @c_UOM,@c_RDUDF01)
     
         FETCH NEXT FROM PICK_CUR INTO @n_QtyReceived, @c_Lottable03, 
                                       @c_UOM, @c_sku, @c_toid,@c_RDUDF01,@c_PackKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE PICK_CUR
      DEALLOCATE PICK_CUR
   END

   --Finalize
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN                                                       
     IF @c_toloc <> '' AND @c_AutofinalizeREC = '1'
      BEGIN
         EXEC dbo.ispFinalizeReceipt      
               @c_ReceiptKey        = @c_NewReceiptKey      
              ,@b_Success           = @b_Success  OUTPUT      
              ,@n_err               = @n_err     OUTPUT      
              ,@c_ErrMsg            = @c_ErrMsg    OUTPUT       
                                   
         IF @b_Success <> 1      
         BEGIN
            SET @n_continue = 1     --CS01
            SET @c_errmsg='ASN Finalize Error (ispPopulateToASN_TVNA): ' +  RTRIM(ISNULL(@c_errmsg,'')) 
            SET @c_RaiseErr = 'Y'                       --CS01
         END       

        UPDATE RECEIPT WITH (ROWLOCK)
        SET ASNStatus = '9'
        WHERE ReceiptKey = @c_NewReceiptKey AND ASNStatus <> '9'

        SET @n_err = @@Error

        IF @n_err <> 0
        BEGIN
             SET @n_continue = 3
             SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
             SET @n_err = 63530
             SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Error on Table Receipt (ispPopulateToASN_TVNA)' + ' ( ' +
                       ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        END

      END

   END

 QUIT_SP:

    IF @n_continue = 3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
    
       --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
       --BEGIN
          --ROLLBACK TRAN
       --END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateToASN_TVNA'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_success = 1
       --CS01 S  
       IF @c_RaiseErr='Y' AND ISNULL(@c_errmsg,'') <> ''
       BEGIN
            EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateToASN_TVNA'
            --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      END
      --CS01 E
       -- WHILE @@TRANCOUNT >= ISNULL(@n_starttcnt
       -- BEGIN
       --    COMMIT TRAN
       -- END
       RETURN
    END            
END

GO