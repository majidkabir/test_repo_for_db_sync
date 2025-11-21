SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_PopulateASNToSO_BR                                           */
/* Creation Date: 15-05-2019                                            */
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
/* Date         Author    Version  Purposes                             */
/*29/07/2019    WLCHOOI     1.1    WMS-9122 - Change mapping            */
/*                                 ExternLineNo and SUM(Qty) (WL01)     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_PopulateASNToSO_BR] 
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

   DECLARE @c_ExternOrderKey        NVARCHAR(50),
           @d_OrderDate             DATETIME,
           @d_DeliveryDate          DATETIME,
           @c_ConsigneeKey          NVARCHAR(15),
           @c_C_contact1            NVARCHAR(30),
           @c_C_Company             NVARCHAR(45),
           @c_C_Address1            NVARCHAR(45),
           @c_C_Address2            NVARCHAR(45),
           @c_C_City                NVARCHAR(45),
           @c_C_State               NVARCHAR(2),
           @c_C_Zip                 NVARCHAR(18),
           @c_C_Country             NVARCHAR(30),
           @c_BillToKey             NVARCHAR(15),
           @c_B_Company             NVARCHAR(45),
           @c_B_Address1            NVARCHAR(45),
           @c_B_Address2            NVARCHAR(45),
           @c_B_City                NVARCHAR(45),
           @c_B_State               NVARCHAR(2),           
           @c_B_Zip                 NVARCHAR(18),
           @c_B_Country             NVARCHAR(30),
           @c_CountryDest           NVARCHAR(30),
           @c_OrderGroup            NVARCHAR(20),
           @c_Salesman              NVARCHAR(30),
           @c_Facility              NVARCHAR(5),
           @c_ExternPOKey           NVARCHAR(20),
           @c_UserDefine01          NVARCHAR(20),
           @c_UserDefine03          NVARCHAR(20),
           @c_POKey                 NVARCHAR(18),
           @c_NewOrderKey           NVARCHAR(10),
           @c_Type                  NVARCHAR(10),
           @c_ReceiptLineNo         NVARCHAR(10),
           @c_StorerKey             NVARCHAR(15),
           @c_OrderLine             NVARCHAR(5),

           --OD
           @c_ODExternOrderKey      NVARCHAR(50),
           @c_ODExternLineNo        NVARCHAR(10),
           @c_ODSKU                 NVARCHAR(20),
           @c_ODStorerkey           NVARCHAR(15),
           @c_ODRetailSku           NVARCHAR(20),
           @c_ODUOM                 NVARCHAR(10),
           @c_ODPackKey             NVARCHAR(10),
           @n_ODExtendedPrice       FLOAT,
           @c_ODUserDefine05        NVARCHAR(18),
           @c_ODUserDefine10        NVARCHAR(18)

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
           @c_POLine                NVARCHAR(5),
           @n_LineNo                INT,
           @c_ToFacility            NVARCHAR(5),
           @n_ExpectedQty           INT,
           @n_QtyReceived           INT
           
   DECLARE @n_continue              INT,
           @n_StartTCnt             INT,
           @n_RowCnt                INT

   CREATE TABLE #OrderDetailWIP (
	[OrderKey]        [nvarchar](10) NOT NULL,
	[OrderLineNumber] [nvarchar](5) NOT NULL,
	[ExternOrderKey]  [nvarchar](50) NOT NULL,
	[ExternLineNo]    [nvarchar](20) NULL,
	[Sku]             [nvarchar](20) NOT NULL,
	[StorerKey]       [nvarchar](15) NOT NULL,
	[RetailSku]       [nvarchar](20) NOT NULL,
	[OriginalQty]     [int] NOT NULL,
	[OpenQty]         [int] NOT NULL,
	[UOM]             [nvarchar](10) NOT NULL,
	[PackKey]         [nvarchar](10) NOT NULL,
	[ExtendedPrice]   [float] NULL,
	[Lottable01]      [nvarchar](18) NOT NULL,
	[Lottable02]      [nvarchar](18) NOT NULL,
	[Lottable03]      [nvarchar](18) NOT NULL,
	[UserDefine05]    [nvarchar](18) NULL,
	[UserDefine10]    [nvarchar](18) NULL,
	[Lottable08]      [nvarchar](30) NOT NULL )

   SELECT TOP 1 @c_Facility = R.Facility
   FROM RECEIPT R(NOLOCK) 
   WHERE R.RECEIPTKEY = @c_ReceiptKey
             
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0, @n_StartTCnt = @@TRANCOUNT, @n_RowCnt = 0

   BEGIN TRAN

   -- Insert into Orders Header
   DECLARE cur_POKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT POKey
   FROM RECEIPTDETAIL RD (NOLOCK)
   WHERE RD.ReceiptKey = @c_ReceiptKey
   AND RD.ReceiptLineNumber  = CASE WHEN @c_ReceiptLineNumber <> '' AND @c_ReceiptLineNumber <> NULL 
                                    THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END

   OPEN cur_POKey
   
   FETCH NEXT FROM cur_POKey INTO @c_POKey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      IF @n_continue = 1 OR @n_continue = 2  --001
      BEGIN
         SELECT TOP 1 
                @c_ExternOrderKey  =  SUBSTRING(ISNULL(PO.ExternPOKey,''),4,20),
                @d_OrderDate       =  GETDATE(),     
                @d_DeliveryDate    =  ISNULL(PO.Userdefine06,''),  
                @c_ConsigneeKey    =  ISNULL(PO.Userdefine08,''),  
                @c_C_contact1      =  ISNULL(PO.Userdefine09,''),    
                @c_C_Company       =  ISNULL(PO.Userdefine09,''),    
                @c_C_Address1      =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 1 ),''), 
                @c_C_Address2      =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 2 ),''), 
                @c_C_City          =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 3 ),''),  
                @c_C_State         =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 4 ),''), 
                @c_C_Zip           =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 5 ),''),  
                @c_C_Country       =  ISNULL((SELECT COLVALUE FROM dbo.fnc_delimsplit ('|',PO.Notes) WHERE SEQNO = 6 ),''),  
                @c_BillToKey       =  ISNULL(PO.BuyersReference,''),  
                @c_B_Company       =  ISNULL(PO.BuyerName,''),  
                @c_B_Address1      =  ISNULL(PO.BuyerAddress1,''),  
                @c_B_Address2      =  ISNULL(PO.BuyerAddress2,''),  
                @c_B_City          =  ISNULL(PO.BuyerCity,''),  
                @c_B_State         =  ISNULL(PO.BuyerState,''), 
                @c_B_Zip           =  ISNULL(PO.BuyerZip,''), 
                @c_B_Country       =  ISNULL(PO.BuyerAddress4,''), 
                @c_CountryDest     =  ISNULL(PO.Notes,''), 
                @c_OrderGroup      =  ISNULL(PO.POGroup,''), 
                @c_Salesman        =  ISNULL(PO.Userdefine02,''),
                @c_ExternPOKey     =  SUBSTRING(ISNULL(PO.ExternPOKey,''),4,20),
                @c_UserDefine01    =  ISNULL(PO.Userdefine01,''),
                @c_UserDefine03    =  ISNULL(PO.OtherReference,''),
                @c_StorerKey       =  ISNULL(PO.Storerkey,''),
                @c_Type            =  ISNULL(PO.POType,'')         
         FROM   PO (NOLOCK)
         JOIN   CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = 'BRPROCTYPE' AND CODELKUP.CODE = PO.POType AND CODELKUP.code2 = PO.PoGroup
                                 AND CODELKUP.StorerKey = PO.Storerkey AND CODELKUP.SHORT = '1'
         WHERE  PO.POKey = @c_POKey

         SELECT @n_RowCnt = @@ROWCOUNT

         IF @n_RowCnt = 0
            GOTO NEXT_RECORD

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
               INSERT INTO ORDERS (Orderkey, ExternOrderKey, OrderDate, DeliveryDate, ConsigneeKey, C_contact1, C_Company, C_Address1, C_Address2, C_City, C_State
                                 , C_Zip, C_Country, BillToKey, B_Company, B_Address1, B_Address2, B_City, B_State, B_Zip, B_Country, CountryDestination, OrderGroup
                                 , Salesman, Facility, ExternPOKey, UserDefine01, UserDefine03, Storerkey, [Type])
               VALUES ( @c_NewOrderKey, @c_ExternOrderKey, @d_OrderDate, @d_DeliveryDate, @c_ConsigneeKey, @c_C_contact1, @c_C_Company, @c_C_Address1, @c_C_Address2        
                      , @c_C_City, @c_C_State, @c_C_Zip, @c_C_Country, @c_BillToKey, @c_B_Company, @c_B_Address1, @c_B_Address2, @c_B_City, @c_B_State, @c_B_Zip
                      , @c_B_Country, @c_CountryDest, @c_OrderGroup, @c_Salesman, @c_Facility, @c_ExternPOKey, @c_UserDefine01, @c_UserDefine03, @c_StorerKey, @c_Type )

               SET @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                  SET @n_err = 81085   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to Orders table Failed (isp_PopulateASNToSO_BR)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  GOTO QUIT_SP  
               END 
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate OrderKey Failed! (isp_PopulateASNToSO_BR)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
               GOTO QUIT_SP
            END
         END    
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63530   
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": StorerKey is BLANK! (isp_PopulateASNToSO_BR)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            GOTO QUIT_SP
         END
      END -- if continue = 1 or 2

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN         
         SELECT @c_POLine = SPACE(5), @n_LineNo = 1
         --SELECT @c_ExternReceiptLine = SPACE(5)

         WHILE 1=1
         BEGIN

            SET ROWCOUNT 1
      
            SELECT @c_ODExternOrderKey = SUBSTRING(ISNULL(PODetail.ExternPOKey,''),4,20), 
                   @c_ODExternLineNo   = '', --PODetail.ExternLineNo,  --WL01
                   @c_ODSKU            = PODetail.Sku,   
                   @c_ODStorerkey      = PODetail.StorerKey,   
                   @c_ODRetailSku      = PODetail.RetailSku,
                   @c_ODUOM            = PODetail.UOM,
                   @c_ODPackKey        = PODetail.Packkey,
                   @n_ODExtendedPrice  = PODetail.UnitPrice,
                   @c_ODUserDefine05   = SKU.SUSR5,
                   @c_ODUserDefine10   = PODetail.UserDefine05,
                   @c_POLine           = PODetail.POLineNumber
             FROM PODetail (NOLOCK)
             JOIN SKU (NOLOCK) ON SKU.SKU = PODetail.SKU AND SKU.StorerKey = PODetail.StorerKey
             WHERE ( PODetail.POKey = @c_POKey ) AND             
                   ( PODetail.POLineNumber > @c_POLine )
             ORDER by PODetail.POLineNumber

             IF @@ROWCOUNT = 0
               BREAK

            SET ROWCOUNT 0      

            IF dbo.fnc_RTrim(@c_POKey) IS NOT NULL AND 
               dbo.fnc_RTrim(@c_POLine) IS NOT NULL 
            BEGIN
                 -- Lottable 01-15 Reserved for future usage
                 DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                     SELECT SUM(ISNULL(PODetail.QtyReceived,0)) AS Qty,
                        ISNULL(PODetail.Lottable01,''),
                        ISNULL(PODetail.Lottable02,''),
                        ISNULL(PODetail.Lottable03,''),
                        ISNULL(PODetail.Lottable04,'19000101'),
                        ISNULL(PODetail.Lottable05,'19000101'),
                        ISNULL(PODetail.Lottable06,''),
                        ISNULL(PODetail.Lottable07,''),
                        ISNULL(PODetail.Lottable08,''),
                        ISNULL(PODetail.Lottable09,''),
                        ISNULL(PODetail.Lottable10,''),
                        ISNULL(PODetail.Lottable11,''),
                        ISNULL(PODetail.Lottable12,''),
                        ISNULL(PODetail.Lottable13,'19000101'),
                        ISNULL(PODetail.Lottable14,'19000101'),
                        ISNULL(PODetail.Lottable15,'19000101')
                     FROM PODetail (NOLOCK) 
                     WHERE (PODetail.POKey = @c_POKey AND
                            PODetail.POLineNumber = @c_POLine)
                     GROUP BY PODetail.StorerKey, PODetail.SKU, 
                              PODetail.Lottable01, PODetail.Lottable02, PODetail.Lottable03, PODetail.Lottable04, PODetail.Lottable05,
                              PODetail.Lottable06, PODetail.Lottable07, PODetail.Lottable08, PODetail.Lottable09, PODetail.Lottable10,
                              PODetail.Lottable11, PODetail.Lottable12, PODetail.Lottable13, PODetail.Lottable14, PODetail.Lottable15

                  OPEN PICK_CUR
               
                  FETCH NEXT FROM PICK_CUR
                     INTO @n_QtyReceived, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                                          @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                          @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     SELECT @c_OrderLine = RIGHT( '0000' + dbo.fnc_RTrim(CAST(@n_LineNo AS NVARCHAR(5))), 5)

                     IF @n_QtyReceived IS NULL
                        SELECT @n_QtyReceived = 0                      
   
                     INSERT INTO #OrderDetailWIP   (OrderKey,             OrderLineNumber,     ExternOrderKey,  --WL01
                                                    ExternLineNo,         StorerKey,           SKU, 
                                                    RetailSKU,            OpenQty,             UOM,                 
                                                    Packkey,              ExtendedPrice,       OriginalQty,
                                                    Lottable01,           Lottable02,          Lottable03,
                                                    UserDefine05,         UserDefine10,        Lottable08 )
                                     VALUES        (@c_NewOrderKey,       @c_OrderLine,        @c_ExternOrderkey,
                                                    @c_ODExternLineNo,    @c_ODStorerkey,      @c_ODSKU,
                                                    @c_ODRetailSku,       @n_QtyReceived,      @c_ODUOM,              
                                                    @c_ODPackKey,         @n_ODExtendedPrice,  @n_QtyReceived,
                                                    @c_Lottable01,        @c_Lottable02,       @c_Lottable03,
                                                    @c_ODUserDefine05,    @c_ODUserDefine10,   @c_Lottable08 )
                     SET @n_err = @@ERROR  
                     IF @n_err <> 0  
                     BEGIN  
                         SET @n_continue = 3  
                         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
                         SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert to ORDERDETAIL Failed (isp_PopulateASNToSO_BR)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
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
      NEXT_RECORD:
      FETCH NEXT FROM cur_POKey INTO @c_POKey
   END
   CLOSE cur_POKey
   DEALLOCATE cur_POKey

   --WL01 Start
   --SELECT DISTINCT ORDERKEY FROM #OrderDetailWIP

   INSERT INTO ORDERDETAIL (OrderKey,             OrderLineNumber,     ExternOrderKey, 
                            ExternLineNo,         StorerKey,           SKU, 
                            RetailSKU,            OpenQty,             UOM,             
                            Packkey,              ExtendedPrice,       OriginalQty,
                            Lottable01,           Lottable02,          Lottable03,
                            UserDefine05,         UserDefine10,        Lottable08 )
   SELECT OrderKey,
          RIGHT('00000' + CAST(ROW_NUMBER() OVER ( PARTITION BY OrderKey ORDER BY OrderKey ) AS NVARCHAR(5) ), 5) ,                 
          ExternOrderKey,
          RIGHT('00000' + CAST(ROW_NUMBER() OVER ( PARTITION BY OrderKey ORDER BY OrderKey ) AS NVARCHAR(5) ), 5) ,  
          StorerKey,
          SKU, 
          RetailSKU,
          SUM(OpenQty),
          UOM,           
          Packkey,
          ExtendedPrice,
          SUM(OriginalQty),
          Lottable01,
          Lottable02,
          Lottable03,
          UserDefine05,
          UserDefine10,
          Lottable08 
    FROM #OrderDetailWIP
    GROUP BY OrderKey,
             ExternOrderKey,
             StorerKey,
             SKU, 
             RetailSKU,
             UOM,           
             Packkey,
             ExtendedPrice,
             Lottable01,
             Lottable02,
             Lottable03,
             UserDefine05,
             UserDefine10,
             Lottable08 
   --WL01 End

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
      execute nsp_logerror @n_err, @c_errmsg, "isp_PopulateASNToSO_BR"  
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