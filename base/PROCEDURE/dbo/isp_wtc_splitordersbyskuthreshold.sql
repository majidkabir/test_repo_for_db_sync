SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_WTC_SplitOrdersBySkuThreshold                  */
/* Creation Date:  19-Oct-2005                                          */
/* Copyright: IDS                                                       */
/* Written by:  YokeBeen                                                */
/*                                                                      */
/* Purpose:  The RCM function from Wave Module to allow the Selection   */
/*           and Split Orders at Sku Level - (SOS#39325)                */
/*                                                                      */
/* Input Parameters:  @c_WaveKey  - (Wavekey)                           */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                     @n_err                                           */
/*                     @c_errmsg                                        */
/*                                                                      */
/* Usage:  Indent Process - Split Orders by Sku Threshold.              */
/*                                                                      */
/* Called By: ids_n_cst_policy_splitordbyskuthreshold                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 15-Dec-2005  MaryVong  SOS44146                                      */
/*                        1) Filtered by OrderDetail.Status = '0';      */ 
/*                           (OrderDetail.LoadKey = '' OR               */
/*                            OrderDetail.LoadKey IS NULL)              */
/*                        2) Do not copy listed columns from original   */
/*                           order to new created order (leave to       */
/*                           default values):                           */
/*                           Orders     : Status, OpenQty               */
/*                           OrderDetail: Status, QtyPreAllocated,      */
/*                                        QtyAllocated, QtyPicked,      */
/*                                        AdjustedQty, ShippedQty       */
/* 19-Jan-2006  YokeBeen  Modified the program not to split the Sku     */
/*                        that has no SOH. - (SOS#44926) (YokeBeen01)   */
/* 21-May-2014  TKLIM     Added Lottables 06-15                         */
/************************************************************************/

CREATE PROC [dbo].[isp_WTC_SplitOrdersBySkuThreshold]
            @c_WaveKey  NVARCHAR(10), 
            @b_Success  INT OUTPUT, 
            @n_err      INT OUTPUT, 
            @c_errmsg   NVARCHAR(250) OUTPUT 
AS  
BEGIN  
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int  
   SELECT @b_debug = 0

   DECLARE @n_continue           int  
         , @n_starttcnt          int            -- Holds the current transaction count  
         , @n_cnt                int            -- Holds @@ROWCOUNT after certain operations  
         , @n_err2               int            -- For Additional Error Detection  
         , @cStorerkey           NVARCHAR(15) 
         , @cSKU                 NVARCHAR(20)
         , @nQtyOrdered          int 
         , @nBalQtyOnHand        int 
         , @cThreshold           NVARCHAR(10)
         , @nThreshold           int 
         , @nQty                 int 
         , @cPreOrderkey         NVARCHAR(10)
         , @cOrderkey            NVARCHAR(10)
         , @cOrderLineNumber     NVARCHAR(5)
         , @nOrdersLineNumber    NVARCHAR(5)
         , @cOrdersLineNumber    NVARCHAR(5)
         , @cOrderType           NVARCHAR(10) 
         , @c_Orderkey           NVARCHAR(10) 
         , @c_WaveDetailKey      NVARCHAR(10) 

   SELECT  @n_continue           = 1 
         , @n_starttcnt          = @@TRANCOUNT 
         , @n_cnt                = 0 
         , @n_err2               = 0 
         , @b_success            = 0 
         , @n_err                = 0 
         , @c_errmsg             = '' 
         , @cStorerkey           = '' 
         , @cSKU                 = '' 
         , @nQtyOrdered          = 0 
         , @nBalQtyOnHand        = 0 
         , @cThreshold           = '' 
         , @nThreshold           = 0 
         , @nQty                 = 0 
         , @cPreOrderkey         = '' 
         , @cOrderkey            = '' 
         , @cOrderLineNumber     = '' 
         , @nOrdersLineNumber    = '' 
         , @cOrdersLineNumber    = '' 
         , @cOrderType           = '' 
         , @c_WaveDetailKey      = '' 


   DECLARE @cExecStatements nvarchar(4000)
   SELECT @cExecStatements = ''


   -- 1st Cursor Loop to get OpenQty by Sku
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @b_debug = 1 SELECT 'Started 1st Cursor Sku...'

      DECLARE CurSku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

      SELECT OrderDetail.Storerkey, OrderDetail.Sku, SUM(OrderDetail.OpenQty) 
        FROM Orders (NOLOCK) 
        JOIN OrderDetail (NOLOCK) ON (Orders.Orderkey = OrderDetail.Orderkey)
        JOIN WaveDetail (NOLOCK) ON (OrderDetail.Orderkey = WaveDetail.Orderkey) 
       WHERE WaveDetail.Wavekey = @c_WaveKey
         AND Orders.Status = '0' 
         AND (OrderDetail.LoadKey = '' OR OrderDetail.LoadKey IS NULL) -- SOS44146
       GROUP BY OrderDetail.Storerkey, OrderDetail.Sku 
       ORDER BY OrderDetail.Storerkey, OrderDetail.Sku 

      OPEN CurSku 
      FETCH NEXT FROM CurSku INTO @cStorerkey, @cSKU, @nQtyOrdered   

      WHILE @@FETCH_STATUS <> -1  -- CurSku Loop 
      BEGIN
         IF @@FETCH_STATUS = 0
         BEGIN
            -- Initialization
            SELECT @nBalQtyOnHand = 0  -- (YokeBeen01)

            -- Get the Balance Qty On Hand 
            SELECT @nBalQtyOnHand = SUM(LotxLocxID.Qty - LotxLocxID.QtyAllocated - LotxLocxID.QtyPicked) 
              FROM LotxLocxID (NOLOCK) 
              JOIN LOC (NOLOCK) ON (LotxLocxID.Loc = LOC.Loc AND LOC.Status <> 'HOLD' AND 
                                    LOC.LocationFlag <> 'HOLD' AND LOC.LocationFlag <> 'DAMAGE') 
              JOIN LOT (NOLOCK) ON (LotxLocxID.Lot = LOT.Lot AND LotxLocxID.Sku = LOT.Sku AND 
                                    LotxLocxID.Storerkey = LOT.Storerkey AND LOT.Status <> 'HOLD') 
              JOIN ID (NOLOCK) ON (LotxLocxID.Id = ID.Id AND ID.Status <> 'HOLD') 
             WHERE LotxLocxID.Storerkey = @cStorerkey
               AND LotxLocxID.Sku = @cSKU 
             GROUP BY LotxLocxID.Sku 
             ORDER BY LotxLocxID.Sku ASC  

            -- (YokeBeen01) - Start
            -- Continue for Order Splitting only when the SOH > 0 
            IF @nBalQtyOnHand > 0 
            BEGIN 
               -- Get the right Qty for Threshold comparison
               IF @nQtyOrdered > @nBalQtyOnHand  
                  SET @nQty = @nBalQtyOnHand 
               ELSE 
                  SET @nQty = @nQtyOrdered 

               -- Get the Threshold being set from the SKU.BUSR4
               SELECT @cThreshold = SKU.BUSR4 
                 FROM SKU (NOLOCK) 
                WHERE Storerkey = @cStorerkey 
                  AND Sku = @cSKU 

               -- Verify & assign the right value for the Threshold checking
               IF ISNUMERIC(@cThreshold) = 1 
               BEGIN 
                  SET @nThreshold = CAST(@cThreshold AS INT) 
               END 
               ELSE
               BEGIN 
                  -- Threshold not being set to the proper values, must not split the Orders.
                  SET @nThreshold = @nQty + 1 
               END 

               -- Get the ORDERS.Type from the CODELKUP table 
               SELECT @cOrderType = ISNULL(dbo.fnc_RTrim(dbo.fnc_LTrim(Code)),'BATCH') 
                 FROM CODELKUP (NOLOCK) 
                WHERE Listname = 'WTCORDTYPE'

               -- Threshold checking & Orders Splitting 
               IF @nQty > @nThreshold  
               BEGIN 
                  IF @b_debug = 1 SELECT 'Started 2nd Cursor Order...'

                  SET @cPreOrderkey = '' 

                  -- 2nd Cursor loop for Orders by Item 
                  DECLARE CurOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

                  SELECT OrderDetail.Orderkey , OrderDetail.OrderLineNumber 
                    FROM OrderDetail (NOLOCK) 
                    JOIN WaveDetail (NOLOCK) ON (OrderDetail.Orderkey = WaveDetail.Orderkey) 
                   WHERE WaveDetail.Wavekey = @c_WaveKey 
                     AND OrderDetail.Sku = @cSKU 
                     AND OrderDetail.Status = '0'   -- SOS44146
                     AND (OrderDetail.LoadKey = '' OR OrderDetail.LoadKey IS NULL) -- SOS44146
                   GROUP BY OrderDetail.Orderkey , OrderDetail.OrderLineNumber 
                   ORDER BY OrderDetail.Orderkey , OrderDetail.OrderLineNumber 

                  OPEN CurOrder 
                  FETCH NEXT FROM CurOrder INTO @cOrderkey , @cOrderLineNumber 

                  WHILE @@FETCH_STATUS <> -1  -- CurOrder Loop 
                  BEGIN
                     IF @@FETCH_STATUS = 0
                     BEGIN
                        IF @b_debug = 1 SELECT 'Started Order Header insertion...'
                        SET @nOrderslinenumber = 0

                        IF @cPreOrderkey <> @cOrderkey -- Check if to create the Order Header
                        BEGIN 
                           EXECUTE dbo.nspg_getkey 
                                 'ORDER' , 
                                 10 , 
                                 @c_Orderkey OUTPUT , 
                                 @b_success OUTPUT, 
                                 @n_err OUTPUT, 
                                 @c_errmsg OUTPUT 
                           -- Insert ORDERS records   
                           BEGIN TRAN 
                           INSERT INTO dbo.ORDERS 
                             ( OrderKey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate,   
                               Priority, ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1,   
                               C_Address2, C_Address3, C_Address4, C_City, C_State, C_Zip, C_Country,   
                               C_ISOCntryCode, C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat, BuyerPO,   
                               BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2,   
                               B_Address3, B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode,   
                               B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, IncoTerm, PmtTerm,
                               -- SOS44146   
                               -- OpenQty, Status, DischargePlace, DeliveryPlace, IntermodalVehicle,
                               DischargePlace, DeliveryPlace, IntermodalVehicle, 
                               -- SOS44146  
                               CountryOfOrigin, CountryDestination, UpdateSource, Type, OrderGroup,   
                               Door, Route, Stop, Notes, EffectiveDate, TrafficCop, ArchiveCop,   
                               ContainerType, ContainerQty, BilledContainerQty, SOStatus, MBOLKey,   
                               InvoiceNo, InvoiceAmount, Salesman, GrossWeight, Capacity, PrintFlag,   
                               LoadKey, Rdd, Notes2, SequenceNo, Rds, SectionKey, Facility, PrintDocDate,   
                               LabelPrice, POKey, ExternPOKey, XDockFlag, UserDefine01, UserDefine02,   
                               UserDefine03, UserDefine04, UserDefine05, UserDefine06, UserDefine07,   
                               UserDefine08, UserDefine09, UserDefine10, Issued, DeliveryNote,   
                               PODCust, PODArrive, PODReject, PODUser, xdockpokey, SpecialHandling ) 
                           SELECT @c_Orderkey, StorerKey, ExternOrderKey, OrderDate, DeliveryDate,   
                               Priority, ConsigneeKey, C_contact1, C_Contact2, C_Company, C_Address1,   
                               C_Address2, C_Address3, C_Address4, C_City, C_State, C_Zip, C_Country,   
                               C_ISOCntryCode, C_Phone1, C_Phone2, C_Fax1, C_Fax2, C_vat, BuyerPO,   
                               BillToKey, B_contact1, B_Contact2, B_Company, B_Address1, B_Address2,   
                               B_Address3, B_Address4, B_City, B_State, B_Zip, B_Country, B_ISOCntryCode,   
                               B_Phone1, B_Phone2, B_Fax1, B_Fax2, B_Vat, IncoTerm, PmtTerm,  
                               -- SOS44146 
                               -- OpenQty, Status, DischargePlace, DeliveryPlace, IntermodalVehicle,
                               DischargePlace, DeliveryPlace, IntermodalVehicle,   
                               -- SOS44146
                               CountryOfOrigin, CountryDestination, UpdateSource, @cOrderType, OrderGroup,   
                               Door, Route, Stop, Notes, EffectiveDate, TrafficCop, ArchiveCop,   
                               ContainerType, ContainerQty, BilledContainerQty, SOStatus, MBOLKey,   
                               @cSKU, InvoiceAmount, Salesman, GrossWeight, Capacity, PrintFlag,   
                               LoadKey, Rdd, Notes2, SequenceNo, Rds, SectionKey, Facility, PrintDocDate,   
                               LabelPrice, POKey, ExternPOKey, XDockFlag, UserDefine01, UserDefine02,   
                               UserDefine03, UserDefine04, UserDefine05, UserDefine06, UserDefine07,   
                               UserDefine08, '', UserDefine10, Issued, DeliveryNote,   
                               PODCust, PODArrive, PODReject, PODUser, xdockpokey, SpecialHandling  
                             FROM ORDERS (NOLOCK) 
                            WHERE Orderkey = @cOrderkey AND Storerkey = @cStorerkey 

                           IF @@ERROR = 0
                           BEGIN
                              COMMIT TRAN

                              IF @b_debug = 1 SELECT 'Started WaveDetail insertion...'

                              -- Get latest WaveDetailKey
                              EXECUTE dbo.nspg_getkey 
                                    'WavedetailKey' , 
                                    10 , 
                                    @c_WaveDetailKey OUTPUT , 
                                    @b_success OUTPUT, 
                                    @n_err OUTPUT, 
                                    @c_errmsg OUTPUT 
                              -- Insert WAVEDETAIL records   
                              BEGIN TRAN 
                              INSERT INTO WAVEDETAIL (WaveDetailKey, WaveKey, OrderKey)
                              VALUES (@c_WaveDetailKey, @c_WaveKey, @c_Orderkey)

                              IF @@ERROR = 0
                              BEGIN
                                 COMMIT TRAN
                              END
                              ELSE
                              BEGIN
                                 ROLLBACK TRAN
                                 SELECT @n_Continue = 3
                                 SELECT @n_err = 65003
                                 SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
                                       ': Insert into WAVEDETAIL failed (isp_WTC_SplitOrdersBySkuThreshold)'  
                              END
                           END
                           ELSE
                           BEGIN
                              ROLLBACK TRAN
                              SELECT @n_Continue = 3
                              SELECT @n_err = 65002
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
                                    ': Insert into ORDERS failed (isp_WTC_SplitOrdersBySkuThreshold)'  
                           END
                        END -- IF @cPreOrderkey <> @cOrderkey -- Check if to create the Order Header

                        IF @b_debug = 1 SELECT 'Started Order Detail insertion...'

                        -- Detail Table processing
                        SELECT @cPreOrderkey = @cOrderkey 
                        SELECT @nOrderslinenumber = @nOrderslinenumber + 1
                        SELECT @cOrderslinenumber = RIGHT(REPLICATE ('0', 5) + dbo.fnc_RTrim(Convert(char(5), @nOrdersLinenumber ) ) , 5)

                        BEGIN TRAN
                        INSERT INTO dbo.ORDERDETAIL 
                             ( OrderKey, OrderLineNumber, OrderDetailSysId, ExternOrderKey, ExternLineNo,   
                               Sku, StorerKey, ManufacturerSku, RetailSku, AltSku, OriginalQty,   
                               -- SOS44146  
                               -- OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked, 
                               -- UOM, PackKey, PickCode, CartonGroup, Lot, ID, Facility, Status, UnitPrice,
                               OpenQty,
                               UOM, PackKey, PickCode, CartonGroup, Lot, ID, Facility, UnitPrice,  
                               -- SOS44146 
                               Tax01, Tax02, ExtendedPrice, UpdateSource, 
                               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                               EffectiveDate, TrafficCop, ArchiveCop,   
                               TariffKey, FreeGoodQty, GrossWeight, Capacity, LoadKey, MBOLKey, QtyToProcess,   
                               MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04,   
                               UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,   
                               POkey, ExternPOKey )  
                        SELECT @c_Orderkey, @cOrderslinenumber, OrderDetailSysId, ExternOrderKey, ExternLineNo,   
                               Sku, StorerKey, ManufacturerSku, RetailSku, AltSku, OriginalQty,
                               -- SOS44146   
                               -- OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated, QtyAllocated, QtyPicked,   
                               -- UOM, PackKey, PickCode, CartonGroup, Lot, ID, Facility, Status, UnitPrice,                            
                               OpenQty,   
                               UOM, PackKey, PickCode, CartonGroup, Lot, ID, Facility, UnitPrice, 
                               -- SOS44146  
                               Tax01, Tax02, ExtendedPrice, UpdateSource, 
                               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                               EffectiveDate, TrafficCop, ArchiveCop,   
                               TariffKey, FreeGoodQty, GrossWeight, Capacity, LoadKey, MBOLKey, QtyToProcess,   
                               MinShelfLife, UserDefine01, UserDefine02, UserDefine03, UserDefine04,   
                               UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,   
                               POkey, ExternPOKey  
                          FROM ORDERDETAIL (NOLOCK) 
                         WHERE Orderkey = @cOrderkey AND OrderLineNumber = @cOrderLineNumber 
                           AND Sku = @cSKU AND Storerkey = @cStorerkey 
   
                        IF @@ERROR = 0
                        BEGIN
                           COMMIT TRAN  

                           IF @b_debug = 1 SELECT 'Delete Detail Line...'

                           BEGIN TRAN
                           DELETE dbo.ORDERDETAIL 
                            WHERE Orderkey = @cOrderkey AND OrderLineNumber = @cOrderLineNumber 
                              AND Sku = @cSKU 

                           IF @@ERROR = 0
                           BEGIN
                              COMMIT TRAN  
                              IF @b_debug = 1 SELECT 'Detail Line being deleted.'
                           END
                           ELSE
                           BEGIN
                              ROLLBACK TRAN
                              SELECT @n_Continue = 3
                              SELECT @n_err = 65004
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
                                    ': Delete from ORDERDETAIL failed (isp_WTC_SplitOrdersBySkuThreshold)'  
                           END  
                        END
                        ELSE
                        BEGIN
                           ROLLBACK TRAN
                           SELECT @n_Continue = 3
                           SELECT @n_err = 65005
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
                                 ': Insert into ORDERDETAIL failed (isp_WTC_SplitOrdersBySkuThreshold)'  
                        END  

                        IF @b_debug = 1 SELECT 'Ended Insertion & Deletion...'

                     END -- IF @@FETCH_STATUS = 0 - 2nd CurOrder

                     FETCH NEXT FROM CurOrder INTO @cOrderkey , @cOrderLineNumber 
                  END -- WHILE @@FETCH_STATUS <> -1  -- CurOrder Loop 

                  CLOSE CurOrder 
                  DEALLOCATE CurOrder
               -- 2nd Cursor loop for Orders by Item
               END -- IF @nQty > @nThreshold  
            END -- IF @nBalQtyOnHand > 0 
            -- (YokeBeen01) - End

         END -- IF @@FETCH_STATUS = 0 - 1st CurSku

         FETCH NEXT FROM CurSku INTO @cStorerkey, @cSKU, @nQtyOrdered   
      END -- WHILE @@FETCH_STATUS <> -1 -- CurSku Loop 

      CLOSE CurSku 
      DEALLOCATE CurSku

      -- Purge old records from ORDERS for those being splitted with no detail lines
      IF @b_debug = 1 SELECT 'Delete Orders...'

      BEGIN TRAN 
      DELETE ORDERS 
       WHERE OrderKey IN ( SELECT ORDERS.Orderkey
                             FROM ORDERS (NOLOCK) 
                             JOIN WAVEDETAIL (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey) 
                             LEFT OUTER JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) 
                            WHERE WAVEDETAIL.Wavekey = @c_WaveKey 
                              AND ORDERDETAIL.Orderkey = NULL 
                            GROUP BY WAVEDETAIL.Wavekey, ORDERS.Orderkey, ORDERDETAIL.Orderkey  
                           HAVING COUNT(ORDERDETAIL.Orderkey) = 0 ) 

      IF @@ERROR = 0
      BEGIN
         COMMIT TRAN  

         -- Purge old records from WAVEDETAIL for those being splitted with no order detail lines
         IF @b_debug = 1 SELECT 'Delete Wave Detail Line...'

         BEGIN TRAN 
         DELETE WAVEDETAIL  
          WHERE WaveDetailKey IN ( SELECT WAVEDETAIL.WaveDetailKey 
                                    FROM WAVEDETAIL (NOLOCK) 
                                    LEFT OUTER JOIN ORDERDETAIL (NOLOCK) 
                                         ON (WAVEDETAIL.Orderkey = ORDERDETAIL.Orderkey) 
                                   WHERE WAVEDETAIL.Wavekey = @c_WaveKey 
                                     AND ORDERDETAIL.Orderkey = NULL 
                                   GROUP BY WAVEDETAIL.WaveDetailkey 
                                  HAVING COUNT(ORDERDETAIL.Orderkey) = 0 )

         IF @@ERROR = 0
         BEGIN
            COMMIT TRAN  
            IF @b_debug = 1 SELECT 'Wave Detail Line being deleted...'
         END
         ELSE
         BEGIN
            ROLLBACK TRAN
            SELECT @n_Continue = 3
            SELECT @n_err = 65007 
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
                  ': Delete from WAVEDETAIL failed (isp_WTC_SplitOrdersBySkuThreshold)'  
         END  
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
         SELECT @n_Continue = 3
         SELECT @n_err = 65006 
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + 
               ': Delete from ORDERS failed (isp_WTC_SplitOrdersBySkuThreshold)'  
      END  

      IF @b_debug = 1 SELECT 'Ended Process...'
   END -- 1st Cursor Loop to get OpenQty by Sku


   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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

      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_WTC_SplitOrdersBySkuThreshold'  
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
END -- end of procedure  

GO