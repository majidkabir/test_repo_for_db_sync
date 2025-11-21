SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrOrderDetailPreAdd                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records INSERTED                                     */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  ver  Purposes                                   */
/* 27-Jan-2021  TLTING01 1.1 Add new column                             */
/* 25-Mar-2021  LZG      1.2 Included new columns while insert (ZG01)   */
/* 17-Aug-2024  PPA371   1.3 New column CancelReasonCode added          */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrOrderDetailPreAdd]
ON  [dbo].[ORDERDETAIL]
INSTEAD OF INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
          @b_Success    INT       -- Populated by calls to stored procedures - was the proc successful?
,         @n_err        INT       -- Error number returned by stored procedure or this trigger
,         @n_err2       INT       -- For Additional Error Detection
,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
,         @n_Continue   INT
,         @n_starttcnt  INT                -- Holds the current transaction count@n_StorerMinShelfLife_Per
,         @c_preprocess NVARCHAR(250)     -- preprocess
,         @c_pstprocess NVARCHAR(250)     -- post process
,         @n_cnt        int
,         @n_OrderDetailSysId INT

   DECLARE @c_OrderKey        NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @c_Sku             NVARCHAR(20),
           @c_StorerKey       NVARCHAR(15),
           @c_Facility        NVARCHAR(5)

   DECLARE @c_Authority_ShelfLife NVARCHAR(1),
           @n_StorerMinShelfLife_Per Int,
           @c_SKUOutGoingShelfLife NVARCHAR(18),
           @n_MinShelfLife Int


   SELECT @n_Continue=1, @n_starttcnt=@@TRANCOUNT

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SELECT @n_Continue = 4

   DECLARE @t_OrderDetail TABLE (
	   [OrderKey] [nvarchar](10) NOT NULL,
	   [OrderLineNumber] [nvarchar](5) NOT NULL,
	   [ExternOrderKey] [nvarchar](50) NULL,
	   [ExternLineNo] [nvarchar](20) NULL,
	   [Sku] [nvarchar](20) NOT NULL,
	   [StorerKey] [nvarchar](15) NOT NULL,
	   [ManufacturerSku] [nvarchar](20) NOT NULL,
	   [RetailSku] [nvarchar](20) NOT NULL DEFAULT '',
	   [AltSku] [nvarchar](20) NOT NULL DEFAULT '',
	   [OriginalQty] [int] NOT NULL DEFAULT 0,
	   [OpenQty] [int] NOT NULL DEFAULT 0,
	   [ShippedQty] [int] NOT NULL DEFAULT 0,
	   [AdjustedQty] [int] NOT NULL DEFAULT 0,
	   [QtyPreAllocated] [int] NOT NULL DEFAULT 0,
	   [QtyAllocated] [int] NOT NULL DEFAULT 0,
	   [QtyPicked] [int] NOT NULL DEFAULT 0,
	   [UOM] [nvarchar](10) NOT NULL DEFAULT 'EA',
	   [PackKey] [nvarchar](10) NOT NULL DEFAULT '',
	   [PickCode] [nvarchar](10) NOT NULL DEFAULT '',
	   [CartonGroup] [nvarchar](10) NULL DEFAULT '',
	   [Lot] [nvarchar](10) NOT NULL DEFAULT '',
	   [ID] [nvarchar](18) NOT NULL DEFAULT '',
	   [Facility] [nvarchar](5) NOT NULL DEFAULT '',
	   [Status] [nvarchar](10) NOT NULL DEFAULT '0',
	   [UnitPrice] [float] NULL DEFAULT 0,
	   [Tax01] [float] NULL DEFAULT 0,
	   [Tax02] [float] NULL DEFAULT 0,
	   [ExtendedPrice] [float] NULL DEFAULT 0,
	   [UpdateSource] [nvarchar](10) NOT NULL DEFAULT '',
	   [Lottable01] [nvarchar](18) NOT NULL DEFAULT '',
	   [Lottable02] [nvarchar](18) NOT NULL DEFAULT '',
	   [Lottable03] [nvarchar](18) NOT NULL DEFAULT '',
	   [Lottable04] [datetime] NULL,
	   [Lottable05] [datetime] NULL,
	   [EffectiveDate] [datetime] NOT NULL DEFAULT GETDATE(),
	   [TariffKey] [nvarchar](10) NULL DEFAULT '',
	   [FreeGoodQty] [int] NULL DEFAULT 0,
	   [GrossWeight] [float] NULL DEFAULT 0,
	   [Capacity] [float] NULL DEFAULT 0,
	   [LoadKey] [nvarchar](10) NULL DEFAULT '',
	   [MBOLKey] [nvarchar](10) NULL DEFAULT '',
	   [QtyToProcess] [int] NULL DEFAULT 0,
	   [MinShelfLife] [int] NULL DEFAULT 0,
	   [UserDefine01] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine02] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine03] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine04] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine05] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine06] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine07] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine08] [nvarchar](18) NULL DEFAULT '',
	   [UserDefine09] [nvarchar](18) NULL DEFAULT '',
	   [POkey] [nvarchar](20) NULL DEFAULT '',
	   [ExternPOKey] [nvarchar](20) NULL DEFAULT '',
	   [UserDefine10] [nvarchar](18) NULL DEFAULT '',
	   [EnteredQTY] [int] NULL DEFAULT 0,
	   [ConsoOrderKey] [nvarchar](30) NULL DEFAULT '',
	   [ExternConsoOrderKey] [nvarchar](30) NULL DEFAULT '',
	   [ConsoOrderLineNo] [nvarchar](5) NULL DEFAULT '',
	   [Lottable06] [nvarchar](30) NULL DEFAULT '',
	   [Lottable07] [nvarchar](30) NULL DEFAULT '',
	   [Lottable08] [nvarchar](30) NULL DEFAULT '',
	   [Lottable09] [nvarchar](30) NULL DEFAULT '',
	   [Lottable10] [nvarchar](30) NULL DEFAULT '',
	   [Lottable11] [nvarchar](30) NULL DEFAULT '',
	   [Lottable12] [nvarchar](30) NULL DEFAULT '',
	   [Lottable13] [datetime] NULL,
	   [Lottable14] [datetime] NULL,
	   [Lottable15] [datetime] NULL,
	   [Notes] [nvarchar](500)  NULL DEFAULT '',
	   [Notes2] [nvarchar](500) NULL DEFAULT '',
	   [Channel] [nvarchar](20) NULL DEFAULT '',
	   [HashValue] [TinyInt] NULL DEFAULT 0,
	   [SalesChannel]  	[nvarchar](100) DEFAULT '',
	   [AddDate] [datetime] NULL,      -- ZG01
    [AddWho] [nvarchar](128),       -- ZG01
    [EditDate] [datetime] NULL,     -- ZG01
    [EditWho] [nvarchar](128),      -- ZG01
    [ArchiveCop][nvarchar](1),      -- ZG01
    [TrafficCop][nvarchar](1),       -- ZG01
    [CancelReasonCode] [nvarchar](60) NULL
      )

   INSERT INTO @t_OrderDetail
       (OrderKey, OrderLineNumber, ExternOrderKey,
        ExternLineNo, Sku, StorerKey, ManufacturerSku, RetailSku, AltSku,
        OriginalQty, OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated,
        QtyAllocated, QtyPicked, UOM, PackKey, PickCode, CartonGroup, Lot,
        ID, Facility, [Status], UnitPrice, Tax01, Tax02, ExtendedPrice,
        UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04,
        Lottable05, EffectiveDate, TariffKey, FreeGoodQty, GrossWeight,
        Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife,
        UserDefine01, UserDefine02, UserDefine03, UserDefine04,
        UserDefine05, UserDefine06, UserDefine07, UserDefine08,
        UserDefine09, POkey, ExternPOKey, UserDefine10, EnteredQTY,
        ConsoOrderKey, ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,
        Lottable07, Lottable08, Lottable09, Lottable10, Lottable11,
        Lottable12, Lottable13, Lottable14, Lottable15, Notes, Notes2,
        Channel, HashValue, SalesChannel,
        AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop , CancelReasonCode)    -- ZG01
   SELECT OrderKey, OrderLineNumber, ExternOrderKey,
        ExternLineNo, Sku, StorerKey, ManufacturerSku, RetailSku, AltSku,
        OriginalQty, OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated,
        QtyAllocated, QtyPicked, UOM, PackKey, PickCode, CartonGroup, Lot,
        ID, Facility, [Status], UnitPrice, Tax01, Tax02, ExtendedPrice,
        UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04,
        Lottable05, EffectiveDate, TariffKey, FreeGoodQty, GrossWeight,
        Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife,
        UserDefine01, UserDefine02, UserDefine03, UserDefine04,
        UserDefine05, UserDefine06, UserDefine07, UserDefine08,
        UserDefine09, POkey, ExternPOKey, UserDefine10, EnteredQTY,
        ConsoOrderKey, ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,
        Lottable07, Lottable08, Lottable09, Lottable10, Lottable11,
        Lottable12, Lottable13, Lottable14, Lottable15, Notes, Notes2,
        Channel, HashValue, SalesChannel,
        AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop, CancelReasonCode      -- ZG01
   FROM INSERTED

   SELECT TOP 1
      @c_Facility = ORDERS.Facility,
      @c_StorerKey = ORDERS.StorerKey
   FROM @t_OrderDetail ORDDET
   JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey =  ORDDET.OrderKey


   -- Added By SHONG on 09-Jun-2004
   -- Reported by Carl (IDSHK), Delete from DEL_ORDERDETAIL IF the previous records was INSERTED
   IF @n_Continue=1 or @n_Continue=2
   BEGIN
      IF EXISTS(SELECT 1 FROM DEL_ORDERDETAIL (NOLOCK)
                  JOIN @t_OrderDetail ORDDET
                  ON DEL_ORDERDETAIL.OrderKey = ORDDET.OrderKey AND
                     DEL_ORDERDETAIL.OrderLineNumber = ORDDET.OrderLineNumber )
      BEGIN
         DELETE DEL_ORDERDETAIL
         FROM   DEL_ORDERDETAIL
         JOIN @t_OrderDetail ORDDET ON DEL_ORDERDETAIL.OrderKey = ORDDET.OrderKey
                              AND DEL_ORDERDETAIL.OrderLineNumber = ORDDET.OrderLineNumber
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
           SELECT @n_Continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE DEL_ORDERDETAIL Failed. (ntrOrderDetailPreAdd)' + ' ( '
           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
         END
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
       IF EXISTS(
              SELECT 1
              FROM   @t_OrderDetail ORDDET
              WHERE  (ORDDET.ExternOrderKey = '' OR ORDDET.ExternOrderKey IS NULL) AND
                     (ORDDET.ExternLineNo = '' OR ORDDET.ExternLineNo IS NULL)
          )
       BEGIN
           UPDATE ORDDET
           SET    ORDDET.ExternOrderKey = ORDERS.ExternOrderKey
                 ,ORDDET.ExternLineNo = CONVERT(INT, ORDDET.OrderLineNumber)
           FROM   @t_OrderDetail AS ORDDET
           JOIN   ORDERS WITH (NOLOCK) ON ORDDET.OrderKey = ORDERS.OrderKey
           WHERE  (ORDDET.ExternOrderKey = '' OR ORDDET.ExternOrderKey IS NULL) AND
                  (ORDDET.ExternLineNo = '' OR ORDDET.ExternLineNo IS NULL)
       END

       SELECT @n_err = @@ERROR,
              @n_cnt = @@ROWCOUNT
       IF @n_err<>0
       BEGIN
           SELECT @n_Continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err),
                  @n_err = 62904
           SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5), @n_err)+
                  ': Updating ExternOrderKey On ORDERDETAIL Failed. (ntrOrderDetailPreAdd)'
                 +'  ( '+' SQLSvr   MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '')
                 +' ) '
       END
   END


   IF @n_Continue = 1 or @n_Continue=2
   BEGIN
       UPDATE ORDDET
       SET [Status] = CASE
                        WHEN OriginalQty + AdjustedQty = ShippedQty AND ShippedQty <> 0
                            THEN '9'
                        WHEN OriginalQty + AdjustedQty <> ShippedQty
                            THEN '0'
                        ELSE [Status]
                     END,
           [OriginalQty] = OpenQty,
           [EnteredQty] = OpenQty
       FROM @t_OrderDetail ORDDET

       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
       IF @n_err <> 0
       BEGIN
           SELECT @n_Continue = 3
           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Of STATUS & OriginalQty On ORDERDETAIL Failed. (ntrOrderDetailPreAdd)'
           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
       END
   END

   --NJOW01 Start
   IF @n_Continue=1 or @n_Continue=2
   BEGIN
      Select @b_success = 0

      Execute nspGetRight
              @c_Facility,
              @c_StorerKey,   -- Storer
              '',             -- Sku
              'CopySKUShelfLifeToOrdByCons',  -- ConfigKey
              @b_success          output,
              @c_Authority_ShelfLife    output,
              @n_err              output,
              @c_errmsg           output

      IF @b_success <> 1
      BEGIN
         Select @n_Continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62908   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Retrieve of Right (PopulateSKUShelfLifeToOrd) Failed (ntrOrderDetailPreAdd)"
         + " ( " + " SQLSvr MESSAGE=" + ISNULL(RTRIM(@c_errmsg), '') + " ) "
      END
   END


   IF (@n_Continue=1 or @n_Continue=2) AND @c_Authority_ShelfLife = '1'
   BEGIN
      DECLARE CUR_ORDDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, OrderLineNumber, Sku, StorerKey
      FROM @t_OrderDetail
      ORDER BY OrderKey, OrderLineNumber

      OPEN CUR_ORDDET

      FETCH FROM CUR_ORDDET INTO @c_OrderKey, @c_OrderLineNumber, @c_Sku, @c_StorerKey

      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @n_StorerMinShelfLife_Per = 0

         SELECT @n_StorerMinShelfLife_Per = STORER.MinShelfLife
         FROM ORDERS WITH (NOLOCK)
         JOIN STORER WITH (NOLOCK) ON (ORDERS.Consigneekey = STORER.Storerkey)
         WHERE OrderKey = @c_OrderKey

         SET @c_SKUOutGoingShelfLife = '0'

         SELECT @c_SKUOutGoingShelfLife = CASE WHEN ISNUMERIC(SKU.SUSR2) = 1 THEN SKU.SUSR2 ELSE '0' END
         FROM SKU WITH (NOLOCK)
         WHERE SKU.Storerkey = @c_StorerKey
         AND SKU.Sku = @c_Sku

         IF ISNULL(@n_StorerMinShelfLife_Per,0) <> 0
         BEGIN
           IF ISNUMERIC(@c_SKUOutGoingShelfLife) = 1
               SELECT @n_MinShelfLife = CAST(@c_SKUOutGoingShelfLife AS INT) * (@n_StorerMinShelfLife_Per / 100.00 )
           ELSE
               SELECT @n_MinShelfLife = 0
         END


         IF @n_MinShelfLife <> 0
         BEGIN
            UPDATE ORDDET
            SET MinShelfLife = @n_MinShelfLife
            FROM @t_OrderDetail ORDDET
            WHERE ORDDET.OrderKey = @c_OrderKey
              AND ORDDET.OrderLineNumber = @c_OrderLineNumber

            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
                SELECT @n_Continue = 3
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Of MinShelfLife Failed. (ntrOrderDetailPreAdd)" + " ( "
                + " SQLSvr MESSAGE=" + ISNULL(RTRIM(@c_errmsg), '') + " ) "
            END
         END


         FETCH FROM CUR_ORDDET INTO @c_OrderKey, @c_OrderLineNumber, @c_Sku, @c_StorerKey
      END

      CLOSE CUR_ORDDET
      DEALLOCATE CUR_ORDDET
   END

   INSERT INTO OrderDetail
       (OrderKey, OrderLineNumber, ExternOrderKey,
        ExternLineNo, Sku, StorerKey, ManufacturerSku, RetailSku, AltSku,
        OriginalQty, OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated,
        QtyAllocated, QtyPicked, UOM, PackKey, PickCode, CartonGroup, Lot,
        ID, Facility, [Status], UnitPrice, Tax01, Tax02, ExtendedPrice,
        UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04,
        Lottable05, EffectiveDate, TariffKey, FreeGoodQty, GrossWeight,
        Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife,
        UserDefine01, UserDefine02, UserDefine03, UserDefine04,
        UserDefine05, UserDefine06, UserDefine07, UserDefine08,
        UserDefine09, POkey, ExternPOKey, UserDefine10, EnteredQTY,
        ConsoOrderKey, ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,
        Lottable07, Lottable08, Lottable09, Lottable10, Lottable11,
        Lottable12, Lottable13, Lottable14, Lottable15, Notes, Notes2,
        Channel, HashValue, SalesChannel,
        AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop, CancelReasonCode)     -- ZG01
   SELECT OrderKey, OrderLineNumber, ExternOrderKey,
        ExternLineNo, Sku, StorerKey, ManufacturerSku, RetailSku, AltSku,
        OriginalQty, OpenQty, ShippedQty, AdjustedQty, QtyPreAllocated,
        QtyAllocated, QtyPicked, UOM, PackKey, PickCode, CartonGroup, Lot,
        ID, Facility, [Status], UnitPrice, Tax01, Tax02, ExtendedPrice,
        UpdateSource, Lottable01, Lottable02, Lottable03, Lottable04,
        Lottable05, EffectiveDate, TariffKey, FreeGoodQty, GrossWeight,
        Capacity, LoadKey, MBOLKey, QtyToProcess, MinShelfLife,
        UserDefine01, UserDefine02, UserDefine03, UserDefine04,
        UserDefine05, UserDefine06, UserDefine07, UserDefine08,
        UserDefine09, POkey, ExternPOKey, UserDefine10, EnteredQTY,
        ConsoOrderKey, ExternConsoOrderKey, ConsoOrderLineNo, Lottable06,
        Lottable07, Lottable08, Lottable09, Lottable10, Lottable11,
        Lottable12, Lottable13, Lottable14, Lottable15, Notes, Notes2,
        Channel, HashValue, SalesChannel,
        AddDate, AddWho, EditDate, EditWho, ArchiveCop, TrafficCop , CancelReasonCode     -- ZG01
   FROM @t_OrderDetail

END -- Trigger
GO