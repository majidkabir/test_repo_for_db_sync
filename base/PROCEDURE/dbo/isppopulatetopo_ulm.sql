SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: ispPopulateTOPO_ULM                                 */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: KHLim                                                    */  
/*                                                                      */  
/* Purpose: Populate PO Detail from ORDERS (Auto PO)                    */  
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
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */   
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/* 22-Dec-2010  NJOW01   1.0  199537-Extract PO facility from codelkup. */
/*                            short and listname=ORDTYP2PO              */
/* 16-Feb-2012  NJOW02   1.1  235759-Populate orderlinenumber if        */
/*                            userdefine08 is empty                     */
/* 27-May-2014  TKLIM    1.2  Added Lottables 06-15                     */
/* 28-Jan-2019  TLTING_ext 1.3 enlarge externorderkey field length      */ 
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPopulateTOPO_ULM]   
   @c_OrderKey NVARCHAR(10)  
AS  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF          
  
  
   DECLARE  @c_ExternPOKey       NVARCHAR(20),  
            @c_SKU               NVARCHAR(20),  
            @c_PackKey           NVARCHAR(10),  
            @c_UOM               NVARCHAR(5),  
            @c_SKUDescr          NVARCHAR(60),  
            @c_StorerKey         NVARCHAR(15),  
            @c_POType            NVARCHAR(10),  
            @c_OrderType         NVARCHAR(10),
            @c_UserDefine08      NVARCHAR(10),
            @c_UserDefine09      NVARCHAR(30),
            @c_Listname          NVARCHAR(10),  
            @c_OrderLine         NVARCHAR(5),  
            @c_Facility          NVARCHAR(5),  
            @c_FacilityPO        NVARCHAR(5),
            @c_Notes             NVARCHAR(MAX),
            @c_Code              NVARCHAR(30),
            @c_ExternOrderKey    NVARCHAR(50),   --tlting_ext
            @c_Lottable01        NVARCHAR(18),  
            @c_Lottable02        NVARCHAR(18),  
            @c_Lottable03        NVARCHAR(18),  
            @d_Lottable04        DATETIME,
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @c_Lottable11        NVARCHAR(30),
            @c_Lottable12        NVARCHAR(30),
            @d_Lottable13        DATETIME,
            @d_Lottable14        DATETIME,
            @d_Lottable15        DATETIME

   DECLARE  @c_NewPOKey          NVARCHAR(10),  
            @c_POLine            NVARCHAR(5),  
            @n_LineNo            int,  
            @c_SellersReference  NVARCHAR(15),
            @c_SellerName        NVARCHAR(45),  
            @c_SellerAddress1    NVARCHAR(45),  
            @c_SellerAddress2    NVARCHAR(45),  
            @c_SellerCity        NVARCHAR(45),  
            @c_SellerState       NVARCHAR(45),  
            @c_SellerZip         NVARCHAR(18),  
            @n_QtyReceived       int,
            @n_QtyOrdered        int
      
   DECLARE  @n_continue          int,  
            @b_success           int,  
            @n_err               int,  
            @c_errmsg            NVARCHAR(255),  
            @n_starttcnt         int,  
            @n_check             int
            --,@n_emailalert     int  
  
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0  
   SET @n_StartTCnt = @@TRANCOUNT   
   -- set constant values  
   SET @c_Listname   = 'ORDTYP2ASN'
   --SET @n_emailalert = 0
  
   -- insert into PO Header  
  
   IF @n_continue = 1 OR @n_continue = 2  --001  
   BEGIN    
      DECLARE ORD_CUR CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT ISNULL(RTRIM(ExternPOKey),'') 
      FROM   ORDERDETAIL WITH (NOLOCK)
      WHERE  OrderKey = @c_OrderKey  

      OPEN ORD_CUR
      FETCH NEXT FROM ORD_CUR INTO @c_ExternPOKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN      
         SELECT @c_StorerKey         = ISNULL(RTRIM(ORDERS.Storerkey),''),
                @c_ExternOrderKey    = ISNULL(RTRIM(ORDERS.ExternOrderKey),''),
                @c_Facility          = ISNULL(RTRIM(ORDERS.Facility),''),  
                @c_OrderType         = ISNULL(RTRIM(ORDERS.Type),''),
                @c_SellersReference  = ISNULL(RTRIM(ORDERS.ConsigneeKey),''),  
                @c_SellerName        = ISNULL(RTRIM(STORER.Company),''),  
                @c_SellerAddress1    = ISNULL(RTRIM(STORER.Address1),''),  
                @c_SellerAddress2    = ISNULL(RTRIM(STORER.Address2),''),  
                @c_SellerCity        = ISNULL(RTRIM(STORER.City),''),  
                @c_SellerState       = ISNULL(RTRIM(STORER.State),''),  
                @c_SellerZip         = ISNULL(RTRIM(STORER.Zip),'')  
         FROM   ORDERS      WITH (NOLOCK)  
         JOIN   MBOL        WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)  
         JOIN   ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)  
         JOIN   STORER      WITH (NOLOCK) ON (STORER.Storerkey = ORDERS.Consigneekey)  
         WHERE  ORDERS.OrderKey         = @c_OrderKey
           AND  ISNULL(RTRIM(ORDERDETAIL.ExternPOKey),'') = @c_ExternPOKey

         -- ensure CODELKUP has been setup  
         SELECT @n_Check = Count(1) FROM CODELKUP WITH (NOLOCK)  
         WHERE Listname = @c_Listname
           AND Code     = @c_OrderType
        
         IF @n_Check <> 1   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63501     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+ ': CODELKUP Setup not exists(For Type). Listname:' + ISNULL(RTRIM(@c_Listname), '')   
                           + ', Code: ' + @c_OrderType + ' (ispPopulateTOPO_ULM)'  + ' ( '   
                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP  
         END  

         IF ISNULL(RTRIM(@c_SellersReference),'') = ''    
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63502     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': SellerKey is blank (ispPopulateTOPO_ULM)' + ' ( '   
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP  
         END   
     
         IF ISNULL(RTRIM(@c_Facility),'') = ''  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63503     
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Facility is blank (ispPopulateTOPO_ULM)' + ' ( '   
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP  
         END   
     
         IF @n_continue = 1 OR @n_continue = 2  
         BEGIN  
            IF ISNULL(RTRIM(@c_StorerKey),'') <> '' 
            BEGIN  
               IF EXISTS ( SELECT 1 FROM CODELKUP WITH (NOLOCK)  
                              WHERE ListName = @c_Listname  
                                AND Code     = @c_OrderType  
                                AND Short    = @c_Facility)  
               BEGIN
                  SELECT @c_POType     = Description,
                         @c_Code       = Code
                         --@c_FacilityPO = CAST(Notes AS NVARCHAR(5))
                  FROM CODELKUP WITH (NOLOCK)  
                  WHERE ListName       = @c_Listname  
                    AND Code           = @c_OrderType  
                    AND Short          = @c_Facility

                  SELECT @c_UserDefine09 = CAST(Notes AS NVARCHAR(30)),
                         @c_Notes      = CAST(Notes2 AS NVARCHAR(MAX)),
                         @c_FacilityPO = Short  --NJOW01
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName       = 'ORDTYP2PO'
                    AND Description    = @c_SellersReference 
                    AND Long           = @c_Code

                  -- get next PO key  
                  SELECT @b_success = 0  
                  EXECUTE   nspg_getkey  
                           'PO'  
                           , 10  
                           , @c_NewPOKey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
                    
                  IF @b_success = 1  
                  BEGIN  
                     INSERT INTO PO (POKey, ExternPOkey, StorerKey, BuyersReference, OtherReference,
                        POType, SellersReference, SellerName, SellerAddress1, SellerAddress2, 
                        SellerCity, SellerState, SellerZip, Notes, UserDefine09)  
                     VALUES (@c_NewPOKey, @c_ExternPOKey, @c_StorerKey, @c_ExternOrderKey, @c_OrderKey,
                        @c_POType, @c_SellersReference, @c_SellerName, @c_SellerAddress1, @c_SellerAddress2, 
                        @c_SellerCity, @c_SellerState, @c_SellerZip, @c_Notes, @c_UserDefine09) 
                  END  
                  ELSE  
                  BEGIN  
                     --SELECT @n_emailalert = 0
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505     
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate PO Key Failed! (ispPopulateTOPO_ULM)' + ' ( '   
                                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                     GOTO QUIT_SP  
                  END
               END  
               ELSE  
               BEGIN 
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507   
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Criteria not match! (ispPopulateTOPO_ULM)' + ' ( '   
                                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  GOTO QUIT_SP  
               END
            END      
            ELSE  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63506     
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOPO_ULM)' + ' ( ' +   
                                ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT_SP  
            END  
         END -- if continue = 1 or 2  

         SELECT @c_OrderLine = SPACE(5), @n_LineNo = 1  

         WHILE 1=1  
         BEGIN  
            SET ROWCOUNT 1
            SELECT @c_SKU         = ORDERDETAIL.Sku,       
                   @c_PackKey     = ORDERDETAIL.PackKey,       
                   @c_UOM         = ORDERDETAIL.UOM,       
                   @c_SKUDescr    = SKU.DESCR,       
                   @c_UserDefine08 = CASE WHEN ISNULL(ORDERDETAIL.UserDefine08,'') = '' THEN
                                          ORDERDETAIL.OrderLineNumber
                                     ELSE
                                          ISNULL(RTRIM(ORDERDETAIL.UserDefine08),'') 
                                     END,  --NJOW02
                   @c_OrderLine   = ORDERDETAIL.OrderLineNumber
            FROM ORDERDETAIL WITH (NOLOCK)  
            JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey   
            JOIN SKU    WITH (NOLOCK) ON SKU.StorerKey = ORDERDETAIL.StorerKey AND SKU.Sku = ORDERDETAIL.Sku   
            WHERE ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.SHIPPEDQTY > 0
              AND ORDERDETAIL.OrderKey     = @c_orderkey
              AND ISNULL(RTRIM(ORDERDETAIL.ExternPOKey),'')  = @c_ExternPOKey
              AND ORDERDETAIL.OrderLineNumber > @c_OrderLine
            ORDER by ORDERDETAIL.OrderLineNumber  
            IF @@ROWCOUNT = 0  
               BREAK
            SET ROWCOUNT 0

            IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND ISNULL(RTRIM(@c_OrderLine), '') <> ''  
            BEGIN  
               DECLARE PICK_CUR CURSOR FAST_FORWARD READ_ONLY FOR   
               SELECT SUM(ISNULL(PICKDETAIL.Qty,0)) AS Qty,  
                      ISNULL(LOTATTRIBUTE.Lottable01,''),  
                      ISNULL(LOTATTRIBUTE.Lottable02,''),  
                      ISNULL(LOTATTRIBUTE.Lottable03,''),  
                      LOTATTRIBUTE.Lottable04,
                      ISNULL(LOTATTRIBUTE.Lottable06,''),
                      ISNULL(LOTATTRIBUTE.Lottable07,''),
                      ISNULL(LOTATTRIBUTE.Lottable08,''),
                      ISNULL(LOTATTRIBUTE.Lottable09,''),
                      ISNULL(LOTATTRIBUTE.Lottable10,''),
                      ISNULL(LOTATTRIBUTE.Lottable11,''),
                      ISNULL(LOTATTRIBUTE.Lottable12,''),
                      LOTATTRIBUTE.Lottable13,
                      LOTATTRIBUTE.Lottable14,
                      LOTATTRIBUTE.Lottable15
               FROM PICKDETAIL   WITH (NOLOCK)   
               JOIN LotAttribute WITH (NOLOCK) ON PickDetail.LOT = LotAttribute.LOT
               WHERE PICKDETAIL.OrderKey        = @c_OrderKey
                 AND PICKDETAIL.OrderLineNumber = @c_OrderLine
               GROUP BY PICKDETAIL.StorerKey, PICKDETAIL.SKU, 
                        LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03, LOTATTRIBUTE.Lottable04,
                        LOTATTRIBUTE.Lottable06, LOTATTRIBUTE.Lottable07, LOTATTRIBUTE.Lottable08, LOTATTRIBUTE.Lottable09, LOTATTRIBUTE.Lottable10,
                        LOTATTRIBUTE.Lottable11, LOTATTRIBUTE.Lottable12, LOTATTRIBUTE.Lottable13, LOTATTRIBUTE.Lottable14, LOTATTRIBUTE.Lottable15

               OPEN PICK_CUR  

               FETCH NEXT FROM PICK_CUR  
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  SELECT @c_POLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)  

                  INSERT INTO PODETAIL (POKey,                    POLineNumber,     ExternPOkey,      
                                       ExternLineNo,              StorerKey,        SKU,   
                                       QtyOrdered,                QtyReceived,      UOM,                 
                                       PackKey,                   Facility,
                                       Lottable01,                Lottable02,       Lottable03,    Lottable04,   
                                       Lottable06,                Lottable07,       Lottable08,    Lottable09,    Lottable10,
                                       Lottable11,                Lottable12,       Lottable13,    Lottable14,    Lottable15)
                      VALUES          (@c_NewPOKey,               @c_POLine,        @c_ExternPOKey,        
                                       @c_UserDefine08,           @c_StorerKey,     @c_SKU,  
                                       ISNULL(@n_QtyReceived,0),  0,                @c_UOM,              
                                       @c_Packkey,                @c_FacilityPO,
                                       @c_Lottable01,             @c_Lottable02,    @c_Lottable03, @d_Lottable04, 
                                       @c_Lottable06,             @c_Lottable07,    @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                       @c_Lottable11,             @c_Lottable12,    @d_Lottable13, @d_Lottable14, @d_Lottable15)   

                  SELECT @n_LineNo = @n_LineNo + 1  

                  FETCH NEXT FROM PICK_CUR  
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04,
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10, 
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
                   
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE PICK_CUR
               DEALLOCATE PICK_CUR  
            END  
         END   -- WHILE

         FETCH NEXT FROM ORD_CUR INTO @c_ExternPOKey
      END
      CLOSE ORD_CUR
      DEALLOCATE ORD_CUR

    QUIT_SP:  
  
    IF @n_continue = 3  -- Error Occured - Process And Return  
    BEGIN  
       SELECT @b_success = 0  
   
       IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt  
       BEGIN  
          ROLLBACK TRAN  
       END  
--       IF @n_emailalert = 1
--       BEGIN
--          DECLARE @c_recipientList NVARCHAR(max),
--                  @c_body NVARCHAR(max)
--          SET @c_recipientList = 'kahhwee.lim@idsgroup.com' --'Wengkeong.lau@idsgroup.com;Jason.lim@idsgroup.com'
--          SET @c_body = 'Auto PO Creation fail upon MBOL. OrderKey:' + @c_orderkey
--
--          EXEC msdb.dbo.sp_send_dbmail 
--          @recipients = @c_recipientList,
--          @subject = 'Auto PO Creation fail upon MBOL',
--          @body = @c_body,
--          @body_format = 'HTML' ;
--       END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOPO_ULM'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN  
    END  
    ELSE  
    BEGIN  
       SELECT @b_success = 1  
      -- WHILE @@TRANCOUNT >= @n_starttcnt  
      -- BEGIN  
      --    COMMIT TRAN  
      -- END  
       RETURN  
    END     
 END -- if continue = 1 or 2 001  
  
-- end procedure  


GO