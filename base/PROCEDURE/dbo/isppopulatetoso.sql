SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: ispPopulateTOSO                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: AQSACM                                                   */
/*                                                                      */
/* Purpose: Create new order based on un-shipped qty                    */
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
/* Date         Author    Ver.  Purposes                                */
/* 04-Feb-2010  AQSACM    1.0   Initial creation for SOS#160522         */
/* 30-Mar-2010  AQS-KC    1.0   SOS# 167369 - Fix for zero shipped qty  */
/*                              not populating to new order (KC01)      */
/* 28-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOSO]
   @c_OrderKey NVARCHAR(10)
AS
   SET NOCOUNT ON         -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_ExternOrderKey     NVARCHAR(50),   --tlting_ext
           @c_StorerKey          NVARCHAR(15),
           @c_RecType            NVARCHAR(10),
           @c_Listname           NVARCHAR(10),
           @c_OrderLine          NVARCHAR(5),
           @c_Facility           NVARCHAR(5),
           @c_ExternOrderLine    NVARCHAR(10),
           @n_SumPCKQty          int,
           @n_SumOriginQty       int,
           @n_OrderCnt           int

   DECLARE @c_ExternLineNo       NVARCHAR(20)
         , @c_Sku                NVARCHAR(20)
         , @c_ManufacturerSku    NVARCHAR(20)
         , @c_RetailSku          NVARCHAR(20)
         , @c_AltSku             NVARCHAR(20)
         , @c_UOM                NVARCHAR(10)
         , @c_PackKey            NVARCHAR(10)
         , @c_PickCode           NVARCHAR(10)
         , @c_CartonGroup        NVARCHAR(10)
         , @c_Lot                NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @n_UnitPrice          FLOAT
         , @n_Tax01              FLOAT
         , @n_Tax02              FLOAT
         , @n_ExtendedPrice      FLOAT
         , @c_ODUpdateSource     NVARCHAR(10)
         , @c_Lottable01         NVARCHAR(18)
         , @c_Lottable02         NVARCHAR(18)
         , @c_Lottable03         NVARCHAR(18)
         , @c_Lottable04         DATETIME
         , @c_Lottable05         DATETIME
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME
         , @c_ODEffectiveDate    DATETIME
         , @c_TariffKey          NVARCHAR(10)
         , @n_MinShelfLife       int
         , @n_FreeGoodQty        int
         , @n_ODGrossWeight      FLOAT
         , @n_ODCapacity         FLOAT
         , @n_QtyToProcess       int
         , @n_OpenQty            int
         , @n_OriginalQty        int
         , @c_ODUserDefine01     NVARCHAR(18)
         , @c_ODUserDefine02     NVARCHAR(18)
         , @c_ODUserDefine03     NVARCHAR(18)
         , @c_ODUserDefine04     NVARCHAR(18)
         , @c_ODUserDefine05     NVARCHAR(18)
         , @c_ODUserDefine06     NVARCHAR(18)
         , @c_ODUserDefine07     NVARCHAR(18)
         , @c_ODUserDefine08     NVARCHAR(18)
         , @c_ODUserDefine09     NVARCHAR(18)
         , @c_ODUserDefine10     NVARCHAR(18)
         , @c_ODPOKey            NVARCHAR(20)
         , @c_ODExternPOKey      NVARCHAR(20)
         , @n_PickQty            int
         , @c_CurrentODLineNo    NVARCHAR(5)


   DECLARE @c_NewOrderKey        NVARCHAR(10),
           @n_LineNo             int,
           @c_CarrierKey         NVARCHAR(15),
           @c_CarrierName        NVARCHAR(30),
           @c_CarrierAddress1    NVARCHAR(45),
           @c_CarrierAddress2    NVARCHAR(45),
           @c_CarrierCity        NVARCHAR(45),
           @c_CarrierState       NVARCHAR(2),
           @c_CarrierZip         NVARCHAR(10),
           @n_QtyReceived        int

   DECLARE @n_continue           int,
           @b_success            int,
           @n_err                int,
           @c_errmsg             NVARCHAR(255),
           @n_starttcnt          int,
           @n_check              int,
           @n_debug              int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT
   -- set constant values

   SET @n_OrderCnt = 0
   SET @c_ExternOrderKey = ''
   -- CHECK Balance QTY
   SET @n_SumPCKQty = 0
   SET @n_SumOriginQty = 0
   SET @n_debug = 0

   SELECT @n_SumPCKQty = SUM(PICKDETAIL.QTY) FROM PICKDETAIL WITH (NOLOCK)
   WHERE PICKDETAIL.OrderKey = ISNULL(RTRIM(@c_OrderKey), '')

   SELECT @n_SumOriginQty = SUM(ORDERDETAIL.ORIGINALQTY) FROM ORDERDETAIL WITH (NOLOCK)
   WHERE ORDERDETAIL.OrderKey = ISNULL(RTRIM(@c_OrderKey), '')

   IF @n_debug = 1
   BEGIN
      SELECT 'ispPopulateTOSO : @n_SumPCKQty',@n_SumPCKQty
      SELECT 'ispPopulateTOSO : @n_SumOriginQty',@n_SumOriginQty
   END

   IF @n_SumOriginQty > @n_SumPCKQty
   BEGIN

      SELECT @c_ExternOrderKey = ExternOrderKey FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.OrderKey = ISNULL(RTRIM(@c_OrderKey), '')

      SELECT @n_OrderCnt = count(1) FROM ORDERS WITH (NOLOCK)
      WHERE ORDERS.ExternOrderKey = ISNULL(RTRIM(@c_ExternOrderKey), '')
      AND ORDERS.SOSTATUS <> 'CANC'

      IF @n_debug = 1
      BEGIN
         SELECT 'ispPopulateTOSO : @c_ExternOrderKey',@c_ExternOrderKey
         SELECT 'ispPopulateTOSO : @n_OrderCnt',@n_OrderCnt
      END

      -- Get New Orderkey
      SELECT @b_success = 0
      EXECUTE   nspg_getkey
               'ORDER'
               , 10
               , @c_NewOrderKey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT


      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate SO Key Failed! (ispPopulateTOSO)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      IF @n_debug = 1
      BEGIN
         SELECT 'ispPopulateTOSO : @c_OrderKey',@c_OrderKey
         SELECT 'ispPopulateTOSO : @c_NewOrderKey',@c_NewOrderKey
      END

      -- Insert ORD HD Start
      INSERT INTO ORDERS
            (
             OrderKey,                    StorerKey,                 ExternOrderKey,            OrderDate,                 DeliveryDate,
             Priority,                    ConsigneeKey,              C_contact1,                C_Contact2,                C_Company,
             C_Address1,                  C_Address2,                C_Address3,                C_Address4,                C_City,
             C_State,                     C_Zip,                     C_Country,                 C_ISOCntryCode,            C_Phone1,
             C_Phone2,                    C_Fax1,                    C_Fax2,                    C_vat,                     BuyerPO,
             BillToKey,                   B_contact1,                B_Contact2,                B_Company,                 B_Address1,
             B_Address2,                  B_Address3,                B_Address4,                B_City,                    B_State,
             B_Zip,                       B_Country,                 B_ISOCntryCode,            B_Phone1,                  B_Phone2,
             B_Fax1,                      B_Fax2,                    B_Vat,                     IncoTerm,                  PmtTerm,
             Status,                      DischargePlace,            DeliveryPlace,             InterModalVehicle,         CountryOfOrigin,
             CountryDestination,          UpdateSource,              Type,                      OrderGroup,                Door,
             Route,                       Stop,                      Notes,                     EffectiveDate,             ContainerType,
             ContainerQty,                BilledContainerQty,        SOStatus,                  InvoiceNo,                 InvoiceAmount,
             Salesman,                    GrossWeight,               Capacity,                  PrintFlag,                 Rdd,
             Notes2,                      SequenceNo,                Rds,                       SectionKey,                Facility,
             PrintDocDate,                LabelPrice,                POKey,                     ExternPOKey,               XDockFlag,
             UserDefine01,                UserDefine02,              UserDefine03,              UserDefine04,              UserDefine05,
             UserDefine06,                UserDefine07,              UserDefine08,              UserDefine09,              UserDefine10,
             Issued,                      DeliveryNote,              PODCust,                   PODArrive,                 PODReject,
             PODUser,                     xdockpokey,                SpecialHandling,           RoutingTool,               M_Contact1,
             M_Contact2)
      SELECT @c_NewOrderKey,              ORDERS.StorerKey,          ORDERS.ExternOrderKey,     ORDERS.OrderDate,          ORDERS.DeliveryDate,
             ORDERS.Priority,             ORDERS.ConsigneeKey,       ORDERS.C_contact1,         ORDERS.C_Contact2,         ORDERS.C_Company,
             ORDERS.C_Address1,           ORDERS.C_Address2,         ORDERS.C_Address3,         ORDERS.C_Address4,         ORDERS.C_City,
             ORDERS.C_State,              ORDERS.C_Zip,              ORDERS.C_Country,          ORDERS.C_ISOCntryCode,     ORDERS.C_Phone1,
             ORDERS.C_Phone2,             ORDERS.C_Fax1,             ORDERS.C_Fax2,             ORDERS.C_vat,              ORDERS.BuyerPO,
             ORDERS.BillToKey,            ORDERS.B_contact1,         ORDERS.B_Contact2,         ORDERS.B_Company,          ORDERS.B_Address1,
             ORDERS.B_Address2,           ORDERS.B_Address3,         ORDERS.B_Address4,         ORDERS.B_City,             ORDERS.B_State,
             ORDERS.B_Zip,                ORDERS.B_Country,          ORDERS.B_ISOCntryCode,     ORDERS.B_Phone1,           ORDERS.B_Phone2,
             ORDERS.B_Fax1,               ORDERS.B_Fax2,             ORDERS.B_Vat,              ORDERS.IncoTerm,           ORDERS.PmtTerm,
             '0',                         ORDERS.DischargePlace,      ORDERS.DeliveryPlace,     ORDERS.InterModalVehicle,  ORDERS.CountryOfOrigin,
             ORDERS.CountryDestination,   ORDERS.UpdateSource,       ORDERS.Type,               ORDERS.OrderGroup,         ORDERS.Door,
             ORDERS.Route,                ORDERS.Stop,               ORDERS.Notes,              ORDERS.EffectiveDate,      ORDERS.ContainerType,
             ORDERS.ContainerQty,         ORDERS.BilledContainerQty, '0',                       ORDERS.InvoiceNo,          ORDERS.InvoiceAmount,
             ORDERS.Salesman,             ORDERS.GrossWeight,        ORDERS.Capacity,           ORDERS.PrintFlag,          ORDERS.Rdd,
             ORDERS.Notes2,               ORDERS.SequenceNo,         ORDERS.Rds,                ORDERS.SectionKey,         ORDERS.Facility,
             ORDERS.PrintDocDate,         ORDERS.LabelPrice,         ORDERS.POKey,              ORDERS.ExternPOKey,        ORDERS.XDockFlag,
             ORDERS.UserDefine01,         ORDERS.UserDefine02,       ORDERS.UserDefine03,       ORDERS.UserDefine04,       ORDERS.UserDefine05,
             ORDERS.UserDefine06,         ORDERS.UserDefine07,       ORDERS.UserDefine08,       ORDERS.UserDefine09,       ORDERS.UserDefine10,
             ORDERS.Issued,               ORDERS.DeliveryNote,       ORDERS.PODCust,            ORDERS.PODArrive,          ORDERS.PODReject,
             ORDERS.PODUser,              ORDERS.xdockpokey,         ORDERS.SpecialHandling,    ORDERS.RoutingTool,        ORDERS.M_Contact1,
             ORDERS.M_Contact2
      FROM   ORDERS WITH (NOLOCK)
      WHERE  ORDERS.OrderKey = @c_OrderKey
      -- Insert ORD HD End

      -- DETAIL LOOP
      SET @n_LineNo = 1
      DECLARE C_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   ORDERDETAIL.ExternOrderKey,   ORDERDETAIL.ExternLineNo,     ORDERDETAIL.Sku,           ORDERDETAIL.ManufacturerSku,  ORDERDETAIL.RetailSku,
               ORDERDETAIL.AltSku,           ORDERDETAIL.UOM,              ORDERDETAIL.PackKey,       ORDERDETAIL.PickCode,         ORDERDETAIL.CartonGroup,
               ORDERDETAIL.Lot,              ORDERDETAIL.ID,               ORDERDETAIL.Facility,      ORDERDETAIL.UnitPrice,        ORDERDETAIL.Tax01,
               ORDERDETAIL.Tax02,            ORDERDETAIL.ExtendedPrice,    ORDERDETAIL.UpdateSource,  ORDERDETAIL.EffectiveDate,    ORDERDETAIL.TariffKey,
               ORDERDETAIL.Lottable01,       ORDERDETAIL.Lottable02,       ORDERDETAIL.Lottable03,    ORDERDETAIL.Lottable04,       ORDERDETAIL.Lottable05,
               ORDERDETAIL.Lottable06,       ORDERDETAIL.Lottable07,       ORDERDETAIL.Lottable08,    ORDERDETAIL.Lottable09,       ORDERDETAIL.Lottable10, 
               ORDERDETAIL.Lottable11,       ORDERDETAIL.Lottable12,       ORDERDETAIL.Lottable13,    ORDERDETAIL.Lottable14,       ORDERDETAIL.Lottable15,
               ORDERDETAIL.MinShelfLife,     ORDERDETAIL.FreeGoodQty,      ORDERDETAIL.GrossWeight,   ORDERDETAIL.Capacity,         ORDERDETAIL.QtyToProcess,
               ORDERDETAIL.UserDefine01,     ORDERDETAIL.UserDefine02,     ORDERDETAIL.UserDefine03,  ORDERDETAIL.UserDefine04,     ORDERDETAIL.UserDefine05,
               ORDERDETAIL.UserDefine06,     ORDERDETAIL.UserDefine07,     ORDERDETAIL.UserDefine08,  ORDERDETAIL.UserDefine09,     ORDERDETAIL.UserDefine10,
               ORDERDETAIL.POKey,            ORDERDETAIL.ExternPOKey,      ORDERDETAIL.ORIGINALQTY,   ORDERDETAIL.Storerkey,        ORDERDETAIL.OrderLineNumber
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE ORDERDETAIL.OrderKey = @c_OrderKey

      OPEN C_ORDERDETAIL

      FETCH NEXT FROM C_ORDERDETAIL INTO @c_ExternOrderKey  ,@c_ExternLineNo     ,@c_Sku              ,@c_ManufacturerSku  ,@c_RetailSku
                                        ,@c_AltSku          ,@c_UOM              ,@c_PackKey          ,@c_PickCode         ,@c_CartonGroup
                                        ,@c_Lot             ,@c_ID               ,@c_Facility         ,@n_UnitPrice        ,@n_Tax01
                                        ,@n_Tax02           ,@n_ExtendedPrice    ,@c_ODUpdateSource   ,@c_ODEffectiveDate  ,@c_TariffKey
                                        ,@c_Lottable01      ,@c_Lottable02       ,@c_Lottable03       ,@c_Lottable04       ,@c_Lottable05
                                        ,@c_Lottable06      ,@c_Lottable07       ,@c_Lottable08       ,@c_Lottable09       ,@c_Lottable10
                                        ,@c_Lottable11      ,@c_Lottable12       ,@d_Lottable13       ,@d_Lottable14       ,@d_Lottable15
                                        ,@n_MinShelfLife    ,@n_FreeGoodQty      ,@n_ODGrossWeight    ,@n_ODCapacity       ,@n_QtyToProcess
                                        ,@c_ODUserDefine01  ,@c_ODUserDefine02   ,@c_ODUserDefine03   ,@c_ODUserDefine04   ,@c_ODUserDefine05
                                        ,@c_ODUserDefine06  ,@c_ODUserDefine07   ,@c_ODUserDefine08   ,@c_ODUserDefine09   ,@c_ODUserDefine10
                                        ,@c_ODPOKey         ,@c_ODExternPOKey    ,@n_OriginalQty      ,@c_StorerKey        ,@c_CurrentODLineNo

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN -- while cursor

         SET @n_PickQty = 0

         SELECT @n_PickQty = ISNULL(SUM(PICKDETAIL.QTY),0)   --(KC01) - Add ISNULL checking
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE ORDERKEY =  ISNULL(RTRIM(@c_OrderKey), '') AND PICKDETAIL.OrderLineNumber = @c_CurrentODLineNo

         IF @n_debug = 1
         BEGIN
            SELECT 'ispPopulateTOSO : @n_OriginalQty',@n_OriginalQty
            SELECT 'ispPopulateTOSO : @n_PickQty',@n_PickQty
         END

         IF @n_OrderCnt = 1
         BEGIN
            SET @c_ODUserDefine01 = CAST(@n_OriginalQty AS NVARCHAR(18))

            UPDATE ORDERDETAIL SET UserDefine01 = @c_ODUserDefine01
            WHERE ORDERKEY =  @c_OrderKey   AND STORERKEY = @c_StorerKey
            AND ORDERLINENUMBER = @c_CurrentODLineNo
         END

         SET @n_OriginalQty = @n_OriginalQty -    @n_PickQty

         SET @c_OrderLine = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NVARCHAR(5))), 5)

         -- Insert ORD DT Start
         IF @n_OriginalQty > 0
         BEGIN

            INSERT INTO ORDERDETAIL (OrderKey,        OrderLineNumber,     ExternOrderKey,      ExternLineNo,        StorerKey,
                                     SKU,             ManufacturerSku,     RetailSku,           AltSku,              UOM,
                                     PackKey,         PickCode,            CartonGroup,         OriginalQty,         OpenQty,
                                     Lot,             ID,                  Facility,            UnitPrice,           Tax01,
                                     Tax02,           ExtendedPrice,       UpdateSource,        EffectiveDate,       TariffKey,
                                     Lottable01,      Lottable02,          Lottable03,          Lottable04,          Lottable05,      
                                     Lottable06,      Lottable07,          Lottable08,          Lottable09,          Lottable10, 
                                     Lottable11,      Lottable12,          Lottable13,          Lottable14,          Lottable15,
                                     MinShelfLife,    FreeGoodQty,         GrossWeight,         Capacity,            QtyToProcess,
                                     UserDefine01,    UserDefine02,        UserDefine03,        UserDefine04,        UserDefine05,
                                     UserDefine06,    UserDefine07,        UserDefine08,        UserDefine09,        UserDefine10,
                                     POKey,           ExternPOKey)

                     VALUES        (@c_NewOrderKey    ,@c_OrderLine        ,@c_ExternOrderKey   ,@c_ExternLineNo     ,@c_StorerKey,
                                    @c_SKU            ,@c_ManufacturerSku  ,@c_RetailSku        ,@c_AltSku           ,@c_UOM,
                                    @c_PackKey        ,@c_PickCode         ,@c_CartonGroup      ,@n_OriginalQty      ,@n_OriginalQty,
                                    @c_Lot            ,@c_ID               ,@c_Facility         ,@n_UnitPrice        ,@n_Tax01,
                                    @n_Tax02          ,@n_ExtendedPrice    ,@c_ODUpdateSource   ,@c_ODEffectiveDate  ,@c_TariffKey,
                                    @c_Lottable01     ,@c_Lottable02       ,@c_Lottable03       ,@c_Lottable04       ,@c_Lottable05,     
                                    @c_Lottable06     ,@c_Lottable07       ,@c_Lottable08       ,@c_Lottable09       ,@c_Lottable10, 
                                    @c_Lottable11     ,@c_Lottable12       ,@d_Lottable13       ,@d_Lottable14       ,@d_Lottable15,
                                    @n_MinShelfLife   ,@n_FreeGoodQty      ,@n_ODGrossWeight    ,@n_ODCapacity       ,@n_QtyToProcess,
                                    @c_ODUserDefine01 ,@c_ODUserDefine02   ,@c_ODUserDefine03   ,@c_ODUserDefine04   ,@c_ODUserDefine05,
                                    @c_ODUserDefine06 ,@c_ODUserDefine07   ,@c_ODUserDefine08   ,@c_ODUserDefine09   ,@c_ODUserDefine10,
                                    @c_ODPOKey        ,@c_ODExternPOKey )


            --Update old ORD DT originalqty and openqty
            UPDATE ORDERDETAIL SET OriginalQty = @n_PickQty , OpenQty = @n_PickQty
            WHERE ORDERKEY =  @c_OrderKey   AND STORERKEY = @c_StorerKey
            AND ORDERLINENUMBER = @c_CurrentODLineNo

            SET @n_LineNo = @n_LineNo + 1
         END
         -- Insert ORD DT End

         FETCH NEXT FROM C_ORDERDETAIL INTO @c_ExternOrderKey  ,@c_ExternLineNo     ,@c_Sku              ,@c_ManufacturerSku  ,@c_RetailSku
                                           ,@c_AltSku          ,@c_UOM              ,@c_PackKey          ,@c_PickCode         ,@c_CartonGroup
                                           ,@c_Lot             ,@c_ID               ,@c_Facility         ,@n_UnitPrice        ,@n_Tax01
                                           ,@n_Tax02           ,@n_ExtendedPrice    ,@c_ODUpdateSource   ,@c_ODEffectiveDate  ,@c_TariffKey
                                           ,@c_Lottable01      ,@c_Lottable02       ,@c_Lottable03       ,@c_Lottable04       ,@c_Lottable05
                                           ,@c_Lottable06      ,@c_Lottable07       ,@c_Lottable08       ,@c_Lottable09       ,@c_Lottable10
                                           ,@c_Lottable11      ,@c_Lottable12       ,@d_Lottable13       ,@d_Lottable14       ,@d_Lottable15
                                           ,@n_MinShelfLife    ,@n_FreeGoodQty      ,@n_ODGrossWeight    ,@n_ODCapacity       ,@n_QtyToProcess
                                           ,@c_ODUserDefine01  ,@c_ODUserDefine02   ,@c_ODUserDefine03   ,@c_ODUserDefine04   ,@c_ODUserDefine05
                                           ,@c_ODUserDefine06  ,@c_ODUserDefine07   ,@c_ODUserDefine08   ,@c_ODUserDefine09   ,@c_ODUserDefine10
                                           ,@c_ODPOKey         ,@c_ODExternPOKey    ,@n_OriginalQty      ,@c_StorerKey        ,@c_CurrentODLineNo


      END -- WHILE (@@FETCH_STATUS <> -1)

      QUIT_SP:

      IF @n_continue = 3  -- Error Occured - Process And Return
      BEGIN

         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPopulateTOSO'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
      ELSE
      BEGIN
         SELECT @b_success = 1
         RETURN
      END
   END-- end procedure

GO