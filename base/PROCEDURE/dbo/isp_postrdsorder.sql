SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_PostRdsOrder                                   */
/* Creation Date:  01-Aug-2008                                          */
/* Copyright: IDS                                                       */
/* Written by:  Shong                                                   */
/*                                                                      */
/* Purpose:  Post RDS Orders to WMS Orders Table                        */
/*                                                                      */
/* Input Parameters:  @n_RdsOrderNo                                     */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RDS Application                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 24-Sep-2008  Larry     Add facilty for orderdetail                   */ 
/* 28-May-2014  TKLIM     Added Lottables 06-15                         */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_PostRdsOrder] (
   @n_RdsOrderNo int, 
   @c_OrderKey   NVARCHAR(10) OUTPUT,
   @b_Success    int OUTPUT,
   @n_err        int OUTPUT,
   @c_errmsg     NVARCHAR(215) OUTPUT)
AS 
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_rdsOrderLineNo     NVARCHAR(10), 
           @c_facility           NVARCHAR(5),  --Larry add facilty for orderdetail 24 Sep 2008
           @c_PackIndicator      NVARCHAR(18), 
           @c_Lottable01         NVARCHAR(18), 
           @c_Lottable02         NVARCHAR(18), 
           @c_Lottable03         NVARCHAR(18),
           @d_Lottable04         DATETIME,
           @d_Lottable05         DATETIME,
           @c_Lottable06         NVARCHAR(30),
           @c_Lottable07         NVARCHAR(30),
           @c_Lottable08         NVARCHAR(30),
           @c_Lottable09         NVARCHAR(30),
           @c_Lottable10         NVARCHAR(30),
           @c_Lottable11         NVARCHAR(30),
           @c_Lottable12         NVARCHAR(30),
           @d_Lottable13         DATETIME,
           @d_Lottable14         DATETIME,
           @d_Lottable15         DATETIME,
           @c_ExternOrderKey     NVARCHAR(50),   --tlting_ext
           @c_StorerKey          NVARCHAR(15),
           @c_Status             NVARCHAR(10),
           @c_LoadKey            NVARCHAR(10),
           @c_SKU                NVARCHAR(20),
           @n_Qty                int,
           @n_OrderLineNumber    int,
           @c_OrderLineNumber    NVARCHAR(5),
           @c_PackUOM3           NVARCHAR(10),
           @c_PackKey            NVARCHAR(10),
           @n_Continue           int, 
           @n_StartTCnt          int,            
           @c_BuyerPO            NVARCHAR(20), 
           @c_SectionKey         NVARCHAR(10) 

   SET @n_StartTCnt=@@TRANCOUNT 
   SET @n_Continue=1 

   BEGIN TRAN 

   SET @c_OrderKey = ''
   SELECT @c_OrderKey       = OrderKey, 
          @c_ExternOrderKey = ExternOrderKey,
          @c_StorerKey      = StorerKey, 
          @c_BuyerPO        = BuyerPO, 
          @c_SectionKey     = SectionKey   
   FROM rdsOrders WITH (NOLOCK) 
   WHERE rdsOrderNo = @n_RdsOrderNo 

   IF ISNULL( RTRIM(@c_OrderKey), '') = ''
   BEGIN
      SELECT @c_OrderKey  = OrderKey
      FROM   ORDERS WITH (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
      AND    ExternOrderKey = @c_ExternOrderKey 
      AND    BuyerPO        = @c_BuyerPO 
      AND    STATUS NOT IN ('9','CANC')  -- To skip the Shipped or Cancel orders added by Ricky July 1st, 2008
   END
 
   IF ISNULL( RTRIM(@c_OrderKey), '') <> ''
   BEGIN 
      IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey )
      BEGIN
         SELECT @c_Status  = ORDERS.Status,
                @c_LoadKey = ISNULL(LPD.LoadKey, ''),
                @c_ExternOrderKey = ISNULL(ORDERS.ExternOrderKey, '') 
         FROM ORDERS WITH (NOLOCK) 
         LEFT OUTER JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.OrderKey = ORDERS.OrderKey 
         WHERE ORDERS.OrderKey = @c_OrderKey 
         
         IF (@c_Status BETWEEN '1' AND '9') -- OR (@c_Status = 'CANC')
         BEGIN
            SET @b_Success = -1
            SET @n_err = 60001
            SET @c_errmsg = 'PO # :' + RTRIM(@c_ExternOrderKey) + ' Already Processed/Cancel. No Update Allow'
            GOTO QUIT 
         END 

         DELETE ORDERS 
         WHERE  OrderKey = @c_OrderKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'Delete ORDERS Failed!'
            GOTO QUIT
         END
      END 
   END 

   IF ISNULL( RTRIM(@c_OrderKey), '') = '' 
   BEGIN
      -- get Next Order Number from nCounter
      SET @b_success = 1

      EXECUTE dbo.nspg_getkey 
          'ORDER' , 
           10 , 
           @c_Orderkey OUTPUT , 
           @b_success  OUTPUT, 
           @n_err      OUTPUT, 
           @c_errmsg   OUTPUT 

   END

   IF NOT EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)
   BEGIN 
      -- This is New Orders
      INSERT INTO [ORDERS]
           ([OrderKey]           ,[StorerKey]           ,[ExternOrderKey]
           ,[Facility]           ,[OrderDate]           ,[DeliveryDate]
           ,[Priority]           ,[ConsigneeKey]        ,[C_Contact1]
           ,[C_Contact2]         ,[C_Company]           ,[C_Address1]
           ,[C_Address2]         ,[C_Address3]          ,[C_Address4]
           ,[C_City]             ,[C_State]             ,[C_Zip]
           ,[C_Country]          ,[C_ISOCntryCode]      ,[C_Phone1]
           ,[C_Phone2]           ,[C_Fax1]              ,[C_Fax2]
           ,[C_vat]              ,[BuyerPO]             ,[BillToKey]
           ,[B_contact1]         ,[B_Contact2]          ,[B_Company]
           ,[B_Address1]         ,[B_Address2]          ,[B_Address3]
           ,[B_Address4]         ,[B_City]              ,[B_State]
           ,[B_Zip]              ,[B_Country]           ,[B_ISOCntryCode]
           ,[B_Phone1]           ,[B_Phone2]            ,[B_Fax1]
           ,[B_Fax2]             ,[B_Vat]               ,[MarkforKey]
           ,[M_Contact1]         ,[M_Contact2]          ,[M_Company]
           ,[M_Address1]         ,[M_Address2]          ,[M_Address3]
           ,[M_Address4]         ,[M_City]              ,[M_State]
           ,[M_Zip]              ,[M_Country]           ,[M_ISOCntryCode]
           ,[M_Phone1]           ,[M_Phone2]            ,[M_Fax1]
           ,[M_Fax2]             ,[M_vat]               ,[IncoTerm]
           ,[PmtTerm]            ,[OpenQty]             
           ,[Status]             ,[DischargePlace]      ,[DeliveryPlace]
           ,[IntermodalVehicle]  ,[CountryOfOrigin]     ,[CountryDestination]
           ,[UpdateSource]       ,[Type]                ,[OrderGroup]
           ,[Door]               ,[Route]               ,[Stop]
           ,[Notes]              ,[Notes2]              ,[ContainerType]
           ,[ContainerQty]       ,[BilledContainerQty]  ,[SOStatus]
           ,[InvoiceNo]          ,[InvoiceAmount]       ,[Salesman]
           ,[GrossWeight]        ,[Capacity]            ,[PrintFlag]
           ,[Rdd]                ,[SequenceNo]          ,[Rds]
           ,[SectionKey]         ,[PrintDocDate]        ,[LabelPrice]
           ,[POKey]              ,[ExternPOKey]         ,[XDockFlag]
           ,[UserDefine01]       ,[UserDefine02]        ,[UserDefine03]
           ,[UserDefine04]       ,[UserDefine05]        ,[UserDefine06]
           ,[UserDefine07]       ,[UserDefine08]        ,[UserDefine09]
           ,[UserDefine10]       ,[Issued]              ,[DeliveryNote]
           ,[PODCust]            ,[PODArrive]           ,[PODReject]
           ,[PODUser]            ,[XDockPOKey]          ,[SpecialHandling]
           ,[RoutingTool]        )
      SELECT @c_OrderKey         ,[StorerKey]           ,[ExternOrderKey]
           ,[Facility]           ,[StartDate]           ,[EndDate]
           ,[Priority]           ,[ConsigneeKey]        ,[C_Contact1]
           ,[C_Contact2]         ,[C_Company]           ,[C_Address1]
           ,[C_Address2]         ,[C_Address3]          ,[C_Address4]
           ,[C_City]             ,[C_State]             ,[C_Zip]
           ,[C_Country]          ,[C_ISOCntryCode]      ,[C_Phone1]
           ,[C_Phone2]           ,[C_Fax1]              ,[C_Fax2]
           ,[C_vat]              ,[BuyerPO]             ,[BillToKey]
           ,[B_contact1]         ,[B_Contact2]          ,[B_Company]
           ,[B_Address1]         ,[B_Address2]          ,[B_Address3]
           ,[B_Address4]         ,[B_City]              ,[B_State]
           ,[B_Zip]              ,[B_Country]           ,[B_ISOCntryCode]
           ,[B_Phone1]           ,[B_Phone2]            ,[B_Fax1]
           ,[B_Fax2]             ,[B_Vat]               ,[MarkforKey]
           ,[M_Contact1]         ,[M_Contact2]          ,[M_Company]
           ,[M_Address1]         ,[M_Address2]          ,[M_Address3]
           ,[M_Address4]         ,[M_City]              ,[M_State]
           ,[M_Zip]              ,[M_Country]           ,[M_ISOCntryCode]
           ,[M_Phone1]           ,[M_Phone2]            ,[M_Fax1]
           ,[M_Fax2]             ,[M_vat]               ,[IncoTerm]
           ,[PmtTerm]            ,[OpenQty]             
           ,[Status]             ,[DischargePlace]      ,[DeliveryPlace]
           ,[IntermodalVehicle]  ,[CountryOfOrigin]     ,[CountryDestination]
           ,[UpdateSource]       ,[Type]                ,[OrderGroup]
           ,[Door]               ,[Route]               ,[Stop]
           ,[Notes]              ,[Notes2]              ,[ContainerType]
           ,[ContainerQty]       ,[BilledContainerQty]  ,[SOStatus]
           ,[InvoiceNo]          ,[InvoiceAmount]       ,[Salesman]
           ,[GrossWeight]        ,[Capacity]            ,[PrintFlag]
           ,[Rdd]                ,[SequenceNo]          ,[Rds]
           ,[SectionKey]         ,[PrintDocDate]        ,[LabelPrice]
           ,[POKey]              ,[ExternPOKey]         ,[XDockFlag]
           ,[UserDefine01]       ,[UserDefine02]        ,[UserDefine03]
           ,[UserDefine04]       ,[UserDefine05]        ,[UserDefine06]
           ,[UserDefine07]       ,[UserDefine08]        ,[UserDefine09]
           ,[UserDefine10]       ,[Issued]              ,[DeliveryNote]
           ,[PODCust]            ,[PODArrive]           ,[PODReject]
           ,[PODUser]            ,[XDockPOKey]          ,[SpecialHandling]
           ,[RoutingTool]
      FROM rdsOrders WITH (NOLOCK)
      WHERE rdsOrderNo = @n_rdsOrderNo 

      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Insert ORDERS Failed!'
         GOTO QUIT
      END
      ELSE
      BEGIN
         UPDATE rdsOrders
            SET ORDERKEY = @c_OrderKey 
         WHERE rdsOrderNo = @n_rdsOrderNo 
         SET @n_Err = @@ERROR
        IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'UPDATE rdsOrders Failed!'
            GOTO QUIT
         END
      END
       
      SELECT @c_facility = FACILITY 
      FROM RDSOrders WITH (NOLOCK) 
      WHERE rdsOrderNo = @n_RdsOrderNo
      
      SET @n_OrderLineNumber = 0 

      DECLARE Csr_InsertOrderDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT rdsOrderLineNo, PackIndicator, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
         FROM rdsOrderDetail WITH (NOLOCK)
         WHERE rdsOrderNo = @n_RdsOrderNo 

      OPEN Csr_InsertOrderDetail 
      
      FETCH NEXT FROM Csr_InsertOrderDetail INTO 
            @c_rdsOrderLineNo, @c_PackIndicator, 
            @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DECLARE Csr_InsertOrderDetailSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT SKU, Qty 
            FROM   rdsOrderDetailSize WITH (NOLOCK) 
            WHERE  rdsOrderNo = @n_RdsOrderNo 
            AND    rdsOrderLineNo = @c_rdsOrderLineNo 
            AND    Qty > 0 
            
         OPEN Csr_InsertOrderDetailSize

         FETCH NEXT FROM Csr_InsertOrderDetailSize INTO
            @c_SKU, @n_Qty 

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @n_OrderLineNumber = @n_OrderLineNumber + 1
            SELECT @c_OrderLineNumber = RIGHT(REPLICATE ('0', 5) + RTRIM(Convert(char(5), @n_OrderLineNumber ) ) , 5)

            SELECT @c_PackUOM3 = PACK.PackUOM3,
                   @c_PackKey  = PACK.PackKey 
            FROM   SKU WITH (NOLOCK)
            JOIN   PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey 
            WHERE  SKU.StorerKey = @c_StorerKey
            AND    SKU.SKU = @c_SKU 

            IF ISNULL(RTRIM(@c_SectionKey), '') <> '' 
               SET @c_Lottable01 = @c_SectionKey

            INSERT INTO ORDERDETAIL 
                    (OrderKey,      OrderLineNumber,     ExternOrderKey,      ExternLineNo,   
                     Sku,           StorerKey,           OpenQty,             UOM, 
                     PackKey,       UserDefine03,        UserDefine04,        Facility,
                     Lottable01,    Lottable02,          Lottable03,          Lottable04,       Lottable05,
                     Lottable06,    Lottable07,          Lottable08,          Lottable09,       Lottable10,
                     Lottable11,    Lottable12,          Lottable13,          Lottable14,       Lottable15)   --Larry add facilty for orderdetail 24 Sep 2008                      
            VALUES  (@c_OrderKey,   @c_OrderLineNumber,  @c_ExternOrderkey,   @c_rdsOrderLineNo, 
                     @c_SKU,        @c_Storerkey,        @n_Qty,              @c_PackUOM3,
                     @c_PackKey,    @c_PackIndicator,    0,                   @c_facility,
                     @c_Lottable01, @c_Lottable02,       @c_Lottable03,       @d_Lottable04,    @d_Lottable05,       
                     @c_Lottable06, @c_Lottable07,       @c_Lottable08,       @c_Lottable09,    @c_Lottable10,
                     @c_Lottable11, @c_Lottable12,       @d_Lottable13,       @d_Lottable14,    @d_Lottable15) --Larry add facilty for orderdetail 24 Sep 2008

            SET @n_Err = @@ERROR
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3
               SET @b_success = -1
               SET @c_ErrMsg = 'Insert ORDERDETAIL Failed!'
               GOTO QUIT
            END

            FETCH NEXT FROM Csr_InsertOrderDetailSize INTO
               @c_SKU, @n_Qty 
         END 
         CLOSE Csr_InsertOrderDetailSize 
         DEALLOCATE Csr_InsertOrderDetailSize

         FETCH NEXT FROM Csr_InsertOrderDetail into 
               @c_rdsOrderLineNo, @c_PackIndicator, 
               @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
               @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
               @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      END -- While Csr_InsertOrderDetail cursor loop
      CLOSE Csr_InsertOrderDetail
      DEALLOCATE Csr_InsertOrderDetail
   END -- If b_success = 1  

QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspItrnAddMove'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   

END -- Procedure

GO