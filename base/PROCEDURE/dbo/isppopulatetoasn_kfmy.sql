SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* SP: ispPopulateTOASN_KFMY                                            */  
/* Creation Date: 13th Nov 2019                                         */  
/* Copyright: IDS                                                       */  
/* Written by:CSCHONG                                                   */  
/*                                                                      */  
/* Purpose: WMS-10974  MYS_MONDELEZ_PRAI_Auto create ASN                */  
/*                                                                      */  
/* Input Parameters: Orderkey                                           */  
/*                                                                      */  
/* Output Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: ntrMBOLHeaderUpdate                                       */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */   
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 08-Apr-2020  CSCHONG   1.1   fix rollback issue (CS01)               */  
/* 17-Apr-2020  CSCHONG   1.2   WMS-10974 revised logic (CS02)          */  
/* 15-MAY-2020  CSCHONG   1.3   WMS-13335 revised sorting rule (CS03)   */    
/* 24-MAY-2023  NJOW01    1.4   WMS-22662 revised mapping               */
/* 24-MAY-2023  NJOW01    1.4   DEVOPS Combine Script                   */
/* 07-Jul-2023  NJOW02    1.5   WMS-23041 revised mapping               */
/************************************************************************/  
CREATE   PROCEDURE [dbo].[ispPopulateTOASN_KFMY]   
    @c_OrderKey NVARCHAR(10)  
   ,@b_debug   NVARCHAR(2) = '0'  
AS  
   SET NOCOUNT ON       -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF          
  
  
   DECLARE @c_ExternReceiptKey      NVARCHAR(20),  
           @c_SKU                   NVARCHAR(20),  
           @c_PackKey               NVARCHAR(10),  
           @c_UOM                   NVARCHAR(5),  
           @c_SKUDescr              NVARCHAR(60),  
           @c_StorerKey             NVARCHAR(15),  
           @c_OrderLine             NVARCHAR(5),  
           @n_MaxOrderLine          INT,  
           @c_Facility              NVARCHAR(5),  
           @c_ExternOrderLine       NVARCHAR(20),  
           @c_id                    NVARCHAR(18),  
           @c_ODExternOrderkey      NVARCHAR(50),  
           @c_PDOrderLine           NVARCHAR(5)          --CS02  
  
  
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
           @c_ConsigneeKey          NVARCHAR(15) = '',  
           @c_ToFacility            NVARCHAR(5),  
           @n_ExpectedQty           int,  
           @n_QtyReceived           int,  
           @n_RemainExpectedQty     int,  
           @c_warehousereference    NVARCHAR(18),            
  
           @c_ordertype             NVARCHAR(10),  
           @c_OHUserDefine01        NVARCHAR(20),         
           @c_ODUserDefine01        NVARCHAR(18),          
           @c_OHUserDefine02        NVARCHAR(20),          
           @c_ODUserDefine02        NVARCHAR(18)           
      
   DECLARE @n_continue              int,  
           @b_success               int,  
           @n_err                   int,  
           @c_errmsg                NVARCHAR(255),  
           @c_salesofftake          NVARCHAR(1),  
           @c_RecNotes              NVARCHAR(4000),  
           @c_RecStorerkey          NVARCHAR(20),  
           @c_RecFacility           NVARCHAR(20),  
           @c_RecType               NVARCHAR(10),  
           @c_RecCarrierkey         NVARCHAR(20),  
           @c_getlottable03         NVARCHAR(30),  
           @c_getlottable06         NVARCHAR(30),  
           @c_PLOC                  NVARCHAR(10),   --(CS03)                    
           @c_UserDefine01          NVARCHAR(18),  --NJOW01
           @c_UserDefine02          NVARCHAR(18),  --NJOW01
           @c_UserDefine04          NVARCHAR(18)   --NJOW01
           
   DECLARE @n_starttcnt             INT                        
  
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0  
  
   SET @n_starttcnt      = @@TRANCOUNT                   
   SET @c_OHUserDefine02 = ''     
   SET @n_MaxOrderLine = 1                         
   -- insert into Receipt Header  
  
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN              
      SET @c_id = ''  
      SET @c_OHUserDefine01 = ''  
         
      SELECT @c_RecCarrierkey      = ORDERS.Storerkey,  
             @c_StorerKey          = ORDERS.Storerkey,  
             @c_ExternReceiptKey   = ISNULL(ORDERS.BuyerPO,''),                   
             @c_WarehouseReference = ISNULL(ORDERS.ExternOrderkey,''),                             
             @c_RecFacility        = ISNULL(C.UDF02, ''),  
             @c_RecType            = ISNULL(C.UDF03, ''),  
             @c_RecStorerkey       = ISNULL(C.UDF01, ''),  
             @c_RecNotes           = ISNULL(MBOL.remarks,'')
      FROM   ORDERS      WITH (NOLOCK)  
      LEFT JOIN   MBOL        WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)  
      JOIN   ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)     
      LEFT OUTER JOIN  CODELKUP C WITH (NOLOCK) ON (C.listname = 'ORDTYP2ASN' AND C.Code = ORDERS.Consigneekey   
                                                and C.storerkey= ORDERS.StorerKey and C.Short=ORDERS.Facility)  
      WHERE  ORDERS.OrderKey = @c_OrderKey  
      
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN      
         IF ISNULL(RTRIM(@c_RecFacility),'') = ''  
         BEGIN  
            --CS02  
            --SELECT @n_continue = 3  
            --SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501     
            --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility is blank (ispPopulateTOASN_KFMY)' + ' ( '   
            --                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
            GOTO QUIT_SP                                                         
         END   
         
         IF NOT EXISTS (SELECT 1 FROM FACILITY WITH (NOLOCK) WHERE FACILITY = @c_RecFacility)  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility not Exists (ispPopulateTOASN_KFMY)' + ' ( '   
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
            GOTO QUIT_SP                               
         END   
      
         -- BEGIN TRAN   --CS01  
          
         IF ISNULL(RTRIM(@c_RecStorerkey),'') <> ''  
         BEGIN  
            -- get next receipt key  
            SELECT @b_success = 0  
            EXECUTE   nspg_getkey  
                     'RECEIPT'  
                     , 10  
                     , @c_NewReceiptKey OUTPUT  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
              
            IF @b_success = 1  
            BEGIN        
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, RecType, Facility, DocType, Notes  
                                  , CarrierKey)                                                          
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_RecStorerkey, @c_RecType, @c_RecFacility, 'A', @c_RecNotes   
                                  , @c_RecCarrierkey)   
                             
               --INSERT INTO TRACEINFO(TraceName,TimeIn,Step1,Step2,Step3,Step4,Step5)  
               --VALUES('PopulateToASN_RECH',getdate(),@c_RecStorerkey,@c_NewReceiptKey,@c_ExternReceiptKey,@c_warehousereference,@c_RecType)                                                                                                                             
            END  
            ELSE  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501     
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! (ispPopulateTOASN_KFMY)' + ' ( '   
                                      + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
               GOTO QUIT_SP  
            END  
         END      
         ELSE  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASN_KFMY)' + ' ( ' +   
                             ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
            GOTO QUIT_SP  
         END  
      
      END -- if continue = 1 or 2  
      
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN           
         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1  
         SELECT @c_ExternOrderLine = SPACE(5)  
      
         SET @n_MaxOrderLine = 0  
         
         IF @b_debug = '1'  
         BEGIN  
           SELECT 'START Orderkey ', @c_orderkey '@c_orderkey'--, @c_OrderLine '@c_OrderLine', @n_MaxOrderLine '@n_MaxOrderLine'  
         END  
      
         SET ROWCOUNT 1  
         SET @c_ODUserDefine01 = ''             
         SET @c_ODExternOrderkey = ''           
         SET @c_ExternOrderLine = ''   
         -- SET @c_OrderLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)       
           
         IF @b_debug = '1'  
         BEGIN  
            SELECT 'START CHECK RECEIPT DETAIL ', @c_orderkey '@c_orderkey', @c_OrderLine '@c_OrderLine', @n_MaxOrderLine '@n_MaxOrderLine'  
         END     
           
         IF @b_debug = '1'  
         BEGIN  
            SELECT 'CHECK RECEIPT DETAIL 1', @c_orderkey '@c_orderkey', @c_OrderLine '@c_OrderLine', @c_SKU '@c_SKU'  
                 , @n_MaxOrderLine '@n_MaxOrderLine', @n_LineNo '@n_LineNo'  
         END  
      
         SET ROWCOUNT 0        
         
         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,  
                   ISNULL(LOTATTRIBUTE.Lottable02,''),  
                   ISNULL(LOTATTRIBUTE.Lottable03,''),  
                   LOTATTRIBUTE.Lottable04,  
                   PICKDETAIL.sku,ORDERDETAIL.PackKey,ORDERDETAIL.UOM,                 --(CS03)  
                   ISNULL(ORDERS.consigneekey,''),  
                   receiptlinenumber = Right('00000'+ convert(varchar(5),ROW_NUMBER() OVER(ORDER BY PICKDETAIL.sku,PICKDETAIL.loc,    --(CS03 START)  
                                             ISNULL(LOTATTRIBUTE.Lottable02,''),ISNULL(LOTATTRIBUTE.Lottable03,'') ASC)),5),  
                   --externlineno = Right('00000'+ convert(varchar(5),ROW_NUMBER() OVER(ORDER BY PICKDETAIL.sku,PICKDETAIL.loc,  
                   --                           ISNULL(LOTATTRIBUTE.Lottable02,''),ISNULL(LOTATTRIBUTE.Lottable03,'') ASC)),5),          --(CS03 END)  
                   ISNULL(POD.ExternLineNo,''),  --NJOW01
                   PDOrderlineno = pickdetail.OrderLineNumber  
                   ,PLOC = PICKDETAIL.loc                                              --(CS03)  
                   ,ISNULL(POD.UserDefine01,''), ISNULL(POD.UserDefine02,''), ISNULL(POD.UserDefine04,'')  --NJOW01
            FROM PICKDETAIL   WITH (NOLOCK)   
            JOIN LotAttribute WITH (NOLOCK) ON (PickDetail.LOT = LotAttribute.LOT)  
            JOIN ORDERDETAIL WITH (NOLOCK) ON pickdetail.orderkey = orderdetail.orderkey  
            AND pickdetail.OrderLineNumber = orderdetail.OrderLineNumber  
            JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)   
            OUTER APPLY (SELECT TOP 1 POD.ExternLineNo, POD.Userdefine01, POD.Userdefine02, POD.Userdefine04
                         FROM PO (NOLOCK)
                         JOIN PODETAIL POD (NOLOCK) ON PO.Pokey = POD.POKey
                         WHERE PO.ExternPOKey = ORDERS.BuyerPO
                         AND POD.Sku = ORDERDETAIL.Sku) AS POD  --NJOW01
            WHERE (PICKDETAIL.OrderKey = @c_OrderKey)  
            AND ( ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0 )   
            GROUP BY LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,  
                     PICKDETAIL.sku,ORDERDETAIL.PackKey,ORDERDETAIL.UOM,                                 --(CS03)  
                     ISNULL(ORDERS.consigneekey,''),pickdetail.OrderLineNumber,PICKDETAIL.loc,            --(CS02)  --(CS03)  
                     ISNULL(POD.ExternLineNo,''), ISNULL(POD.UserDefine01,''), ISNULL(POD.UserDefine02,''), ISNULL(POD.UserDefine04,'')   --NJOW01
            
         OPEN PICK_CUR  
           
         FETCH NEXT FROM PICK_CUR  
               INTO @n_QtyReceived,  @c_Lottable02, @c_Lottable03, @d_Lottable04,@c_sku,@c_packkey,@c_UOM,@c_ConsigneeKey,  
                    @c_ReceiptLine,@c_ExternOrderLine,@c_PDOrderLine  ,@c_PLOC,                       --(CS02)  --(CS03)  
                    @c_UserDefine01, @c_UserDefine02, @c_UserDefine04   --NJOW01
         
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            SET @c_getlottable03 = ''  
            SET @c_getlottable06 = ''  
      
            IF @b_debug = '1'  
            BEGIN  
              SELECT 'CHECK BEFORE INSERT RECEIPT DETAIL ', @c_orderkey '@c_orderkey', @c_OrderLine '@c_OrderLine', @c_SKU '@c_SKU', @n_MaxOrderLine '@n_MaxOrderLine'  
              Print '@c_SKU : ' + @c_SKU + ', Storerkey : ' + @c_RecStorerkey  
            END  
              
              
            SET @c_getlottable03 = CASE WHEN charindex('_',@c_Lottable03,1) > 0 THEN substring(@c_Lottable03,(charindex('_',@c_Lottable03,1))+1,10) ELSE '' END  
            SET @c_getlottable06 = CASE WHEN charindex('_',@c_Lottable03,1) > 0 THEN substring(@c_Lottable03,1,(charindex('_',@c_Lottable03,1))-1) else @c_Lottable03 END   
                  
            IF @n_QtyReceived IS NULL  
            SELECT @n_QtyReceived = 0                        
              
            INSERT INTO RECEIPTDETAIL (ReceiptKey,    ReceiptLineNumber,      
                                       ExternLineNo,  StorerKey,           SKU,   
                                       QtyExpected,   QtyReceived,  
                                       UOM,           PackKey, toloc, lottable01,                             ---(CS02)              
                                       Lottable02,    Lottable03,    Lottable04,   
                                       Lottable06,Lottable07, 
                                       ExternReceiptkey, UserDefine01, UserDefine02, UserDefine04)      --NJOW01            
                                             
            VALUES        (@c_NewReceiptKey, @c_ReceiptLine,     
                           @c_ExternOrderLine, @c_RecStorerkey,     @c_SKU,                     
                           ISNULL(@n_QtyReceived,0),   0,                 
                            @c_UOM,           @c_Packkey, '','UR',                                            --(CS02)        
                            @c_Lottable02, @c_getlottable03, @d_Lottable04,      --NJOW02
                            @c_getlottable06,@c_ConsigneeKey, 
                            @c_ExternReceiptKey, @c_UserDefine01, @c_UserDefine02, @c_UserDefine04)  --NJOW01
      
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_Continue = 3        
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502     
                    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert ReceiptDetail Fail ! (ispPopulateTOASN_KFMY)' + ' ( ' +   
                          ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '  
                   GOTO QUIT_SP      
            END     
           
            --INSERT INTO TRACEINFO(TraceName,TimeIn,Step1,Step2,Step3,Step4,Step5)  
            --  VALUES('PopulateToASN_RECDETCHK',getdate(),@c_RecStorerkey,@c_NewReceiptKey,@c_OrderLine,@c_ExternOrderLine,@c_SKU)  
                                                                                                                                        
      
            IF @b_debug='1'  
            BEGIN  
              SELECT 'CHECK INSERT RECEIPTDETAIL'  
              SELECT * FROM RECEIPTDETAIL (NOLOCK)  
              WHERE Receiptkey = @c_NewReceiptKey  
            END  
        
            FETCH NEXT FROM PICK_CUR  
            INTO @n_QtyReceived, @c_Lottable02, @c_Lottable03, @d_Lottable04,@c_sku,@c_packkey,@c_UOM,@c_ConsigneeKey,  
                 @c_ReceiptLine,@c_ExternOrderLine, @c_PDOrderLine , @c_PLOC,                  --(CS02)   --(CS03)  
                 @c_UserDefine01, @c_UserDefine02, @c_UserDefine04   --NJOW01                      
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE PICK_CUR  
         DEALLOCATE PICK_CUR  
      END  
  
      SET ROWCOUNT 0  
  
      QUIT_SP:  
  
      IF @b_debug='1'  
      BEGIN  
         SELECT 'FINAL RECEIPTDETAIL'  
         SELECT top 10 * FROM RECEIPTDETAIL (NOLOCK)  
         Order by adddate desc  
      END  
  
      IF @n_continue = 3  -- Error Occured - Process And Return  
      BEGIN  
         SET @b_success = 0  
     
         --IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt  
         --BEGIN  
         --   ROLLBACK TRAN  
         --END  
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOASN_KFMY'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
      ELSE  
      BEGIN  
         SET @b_success = 1  
          --CS01   
          --WHILE @@TRANCOUNT > @n_StartTCnt        
          --  BEGIN        
          --    COMMIT TRAN        
          --  END      
         RETURN  
      END     
   END -- if continue = 1 or 2 001  

GO