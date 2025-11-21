SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_delivery_receipt                               */
/* Creation Date:  18-Apr-2006                                          */
/* Copyright: IDS                                                       */
/* Written by:  ONGGB                                                   */
/*                                                                      */
/* Purpose: Delivery Receipt with Logo (refer to Storer setting)        */
/*                                                                      */
/* Input Parameters:  @cMBOLkey  - (MBOLkey)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/* 2006-04-18  ONG     1.0   Initial (SOS46116)                         */
/* 2013-07-08  NJOW01  1.1   282838-user define company name            */
/* 2014-06-27  NJOW02  1.2   314240-Sort by sku,lottable02              */
/* 2015-06-01  Leong   1.3   SOS# 343524 - Join with StorerKey.         */
/* 28-Jan-2019 TLTING_ext 1.4  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROC [dbo].[isp_delivery_receipt] (@cMBOLkey NVARCHAR(10) )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE   @cOrderKey     NVARCHAR(10)
            ,@cStorerkey    NVARCHAR(15)
            ,@c_CounterKey  NVARCHAR(10)
            ,@cLot          NVARCHAR(18)
            ,@cUserdefine10 NVARCHAR(10)
            ,@PrevUserdefine10 NVARCHAR(10)
            ,@cSKU          NVARCHAR(20)
            ,@PrevSKU       NVARCHAR(20)
            ,@cSeqNum         int
            ,@PrevOrderKey  NVARCHAR(10)

   DECLARE   @c_PrintedFlag   NVARCHAR(1)
            ,@n_err           int
            ,@n_continue      int
            ,@b_success       int
            ,@c_errmsg        NVARCHAR(255)
            ,@n_starttcnt     int
            ,@b_debug         int
            ,@n_count         int
            ,@cExecStatements NVARCHAR(max)

   IF OBJECT_ID('tempdb..#Temptb')     IS NOT NULL    DROP TABLE #Temptb

   CREATE TABLE [#Temp_Flag] (
      Orderkey          [NVARCHAR] (10) NULL,
      PrintFlag         [NVARCHAR] (1)    NULL)

   IF OBJECT_ID('tempdb..#Temptb')     IS NOT NULL    DROP TABLE #Temptb
   CREATE TABLE [#Temptb] (
      Orderkey          [NVARCHAR] (10) NULL,
      UserDefine10      [NVARCHAR] (10) NULL,
      ExternOrderKey    [NVARCHAR] (50) NULL,   --tlting_ext
      PrintFlag         [NVARCHAR] (1)    NULL,
      Consigneekey      [NVARCHAR] (15) NULL,
      C_Company         [NVARCHAR] (45) NULL,
      C_Address1        [NVARCHAR] (45) NULL,
      C_Address2        [NVARCHAR] (45) NULL,
      C_Address3        [NVARCHAR] (45) NULL,
      C_Address4        [NVARCHAR] (45) NULL,
      BuyerPO           [NVARCHAR] (20) NULL,
      OrderDate         [datetime]  NULL,
      DeliveryDate      [datetime]  NULL,
      DepartureDate     [datetime]  NULL,
      CarrierAgent      [NVARCHAR] (30) NULL,
      VesselQualifier   [NVARCHAR] (10) NULL,
      DriverName        [NVARCHAR] (30) NULL,
      Vessel            [NVARCHAR] (30) NULL,
      OtherReference    [NVARCHAR] (30) NULL,
      SKU               [NVARCHAR] (20) NULL,
      SkuDescr          [NVARCHAR] (60) NULL,
      Logo              [NVARCHAR] (60) NULL,
      Lot               [NVARCHAR] (18) NULL,
      OrderQty          [float]     NULL,
      ShippedQty        [float]     NULL,
      CompanyName   [NVARCHAR] (45) NULL)  --NJOW01

      SELECT @n_starttcnt=@@TRANCOUNT, @n_continue = 1, @b_debug = 0, @n_err = 0, @c_PrintedFlag = 'N'

      SELECT @n_count = count(*) FROM ORDERS (NOLOCK)
      WHERE ORDERS.MBOLKey = @cMBOLkey

      IF @n_count <= 0
      begin
         SELECT @n_continue = 4
         IF @b_debug = 1
            PRINT 'No Data Found'
      END
      ELSE
         IF @b_debug = 1
            PRINT 'Start Processing...  MBOLKey=' + @cMBOLkey

      -- Assign DR Number to all order under this MBOLKey! Exclude those already got
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         DECLARE CurOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         -- Filter all orderkey which UserDefine10 = ''
         SELECT   ORDERS.Orderkey,
                  ORDERS.Storerkey,
                  ORDERS.UserDefine10
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.MBOLKey = @cMBOLkey
         AND UserDefine10 = ''
         ORDER BY ORDERS.ORDERKEY

         OPEN CurOrder
         FETCH NEXT FROM CurOrder INTO @cOrderKey, @cStorerkey, @cUserDefine10

         WHILE @@FETCH_STATUS <> -1 -- CurOrder Loop
         BEGIN
            if @b_debug = 1
               PRINT 'Storerkey=' + @cStorerkey +' ;Orderkey=' + @cOrderKey

            IF @cUserDefine10 = ''
            BEGIN
               SELECT @c_PrintedFlag = 'N'
               SET @c_CounterKey = ''

               SELECT @c_CounterKey = Code
               FROM CodeLkUp (NOLOCK)
               WHERE ListName = 'DR_NCOUNT'
               AND SHORT = @cStorerkey

               IF @c_CounterKey = ''
               begin
                  SELECT @n_continue = 3
                  SELECT @n_err = 63500      -- should assign new error code
                  SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": No Setup for CodeLkUp.ListName = DR_NCOUNT. (isp_delivery_receipt)"
               END

               IF @b_debug = 1
               begin
                  PRINT 'Check this: SELECT Code FROM CodeLkUp (NOLOCK) WHERE ListName = ''DR_NCOUNT'' AND SHORT =N''' + dbo.fnc_RTrim(@cStorerkey) + ''''
               end

               IF @n_continue = 1 or @n_continue = 2
               BEGIN
                  SELECT @b_success = 0

                  EXECUTE nspg_GetKey  @c_CounterKey, 10,
                        @cUserDefine10 OUTPUT,
                        @b_success     OUTPUT,
                        @n_err         OUTPUT,
                        @c_errmsg      OUTPUT

                  IF @b_debug = 1
                     PRINT 'Orderkey = ' + @cOrderKey + ' GET UserDefine10 (DR)= ' + @cUserDefine10 + master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(13)

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63500      -- should assign new error code
                     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": Fail to Generate Userdeine10 . (isp_delivery_receipt)"
                  END
               END

               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  UPDATE ORDERS SET UserDefine10 = @cUserDefine10
                  WHERE ORDERKEY = @cOrderkey

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63501      -- should assign new error code
                     SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": UPDATE ORDERS Failed. (isp_delivery_receipt)"
                  END
               END -- @n_continue = 1 or @n_continue = 2
            END
--             Else     -- IF @c_UserDefine10 <> ''
--             BEGIN
--                SELECT @c_PrintedFlag = 'Y'      -- All Order under same MBOLKey should have same status for this @c_PrintedFlag
--             END

            INSERT INTO #Temp_Flag(PrintFlag, OrderKey)
            VALUES(@c_PrintedFlag, @cOrderKey)

            FETCH NEXT FROM CurOrder INTO @cOrderKey, @cStorerkey, @cUserDefine10
         END

         CLOSE CurOrder
         DEALLOCATE CurOrder
      END -- @n_count > 0

      -- Retrieve SELECT LIST
      If @n_continue = 1 or @n_continue = 2
      BEGIN
            INSERT INTO #Temptb
            SELECT
               ORDERS.orderkey,
               ORDERS.UserDefine10,
               ORDERS.ExternOrderKey,
               ISNULL(#Temp_Flag.PrintFlag, 'Y'),     -- ISNULL mean existing UserDefine10 <> '' ==> Printed before
               ORDERS.Consigneekey,
               ORDERS.C_Company,
               ISNULL(ORDERS.C_Address1,''),
               ISNULL(ORDERS.C_Address2,''),
               ISNULL(ORDERS.C_Address3,''),
               ISNULL(ORDERS.C_Address4,''),
               ORDERS.BuyerPO,
               ORDERS.OrderDate,
               ORDERS.DeliveryDate,
               MBOL.DepartureDate,
               MBOL.CarrierAgent,
               MBOL.VesselQualifier,
               MBOL.DriverName,
               MBOL.Vessel,
               MBOL.OtherReference,
               ORDERDETAIL.SKU,
               SKU.Descr SkuDescr,
               Storer.Logo,
               Lotattribute.Lottable02 Lot,
               OrderDetail.OriginalQty / PACK.CaseCnt ,
               SUM(Pickdetail.Qty) / PACK.CaseCnt As ShippedQty ,
               Storer.Company --NJOW01
            FROM ORDERS (NOLOCK)
            JOIN ORDERDETAIL (NOLOCK) ON ORDERS.Orderkey = OrderDetail.Orderkey
            JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey
            JOIN Storer (NOLOCK) ON ORDERS.Storerkey = Storer.Storerkey
            JOIN SKU (NOLOCK) ON SKU.SKU = OrderDetail.SKU AND SKU.StorerKey = Storer.StorerKey -- SOS# 343524
            JOIN MBOL (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey
            JOIN Pickdetail (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey
                                    AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
            JOIN Lotattribute (NOLOCK) ON Pickdetail.lot = Lotattribute.Lot
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.PackKey
            JOIN CODELKUP (NOLOCK) ON Orders.Storerkey = CODELKUP.Short AND CODELKUP.Listname = 'DR_NCOUNT' --NJOW01
            LEFT OUTER JOIN #Temp_Flag ON #Temp_Flag.Orderkey = ORDERS.Orderkey
            WHERE ORDERS.MBOLKEY = @cMBOLKey
            GROUP BY ORDERS.orderkey,
                     ORDERS.UserDefine10,
                     ORDERS.ExternOrderKey,
                     ISNULL(#Temp_Flag.PrintFlag, 'Y'),     -- ISNULL mean existing UserDefine10 <> '' ==> Printed before
                     ORDERS.Consigneekey,
                     ORDERS.C_Company,
                     ISNULL(ORDERS.C_Address1,''),
                     ISNULL(ORDERS.C_Address2,''),
                     ISNULL(ORDERS.C_Address3,''),
                     ISNULL(ORDERS.C_Address4,''),
                     ORDERS.BuyerPO,
                     ORDERS.OrderDate,
                     ORDERS.DeliveryDate,
                     MBOL.DepartureDate,
                     MBOL.CarrierAgent,
                     MBOL.VesselQualifier,
                     MBOL.DriverName,
                     MBOL.Vessel,
                     MBOL.OtherReference,
                     ORDERDETAIL.SKU,
                     SKU.Descr ,
                     Storer.Logo,
                     Lotattribute.Lottable02 ,
                     OrderDetail.OriginalQty,
                     PACK.CaseCnt,
                     Storer.Company --NJOW01
      END

      -- SORT ORDER
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SELECT * , IDENTITY(INT, 1, 1) AS SeqNum
         INTO #Temptb1
         FROM #Temptb
         ORDER BY Consigneekey, ExternOrderKey, Sku, Lot --NJOW02
         --ORDER BY Consigneekey, ExternOrderKey, BuyerPO, Orderkey, SkuDescr, Lot

         IF @@ROWCOUNT = 0
         Begin
            SELECT @n_continue = 3
            SELECT @n_err = 63500      -- should assign new error code
            SELECT @c_errmsg="NSQL"+CONVERT(NVARCHAR(5),@n_err)+": No Data Found. (isp_delivery_receipt)"
         END

         -- Show the OrderQty only on the first line per sku in same order (same DR number)
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN

            SELECT @cUserdefine10 = '', @PrevUserdefine10 = '', @cSKU= '', @PrevSKU = '', @cSeqNum = 0
            DECLARE CurSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Userdefine10, SKU, SeqNum
            FROM #Temptb1 (NOLOCK)
            Order by SeqNum

            OPEN CurSKU
            FETCH NEXT FROM CurSKU INTO @cUserdefine10, @cSKU, @cSeqNum

            WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2) -- CurOrder Loop
            BEGIN
               IF @PrevUserdefine10 <> @cUserdefine10
               BEGIN
                  SELECT @PrevUserdefine10 = @cUserdefine10
                  SELECT @PrevSKU = @cSKU
               END
               ELSE
               BEGIN
                  IF @PrevSKU <> @cSKU
                     SELECT @PrevSKU = @cSKU
                  ELSE
                     UPDATE #Temptb1 SET OrderQty = NULL
                     WHERE SeqNum = @cSeqNum
               END

               FETCH NEXT FROM CurSKU INTO @cOrderKey, @cSKU, @cSeqNum
            END
            CLOSE CurSKU
            DEALLOCATE CurSKU
         END -- Show the OrderQty only on the first line per sku in same order (same DR number)
   END -- If @n_continue = 1 or @n_continue = 2 FOR Retrieve SELECT LIST


   IF @n_continue = 1 OR @n_continue = 2
      SELECT * FROM #Temptb1
      ORDER BY SeqNum

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_delivery_receipt"
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

   DROP TABLE #Temp_Flag
   DROP TABLE #Temptb
   IF OBJECT_ID('tempdb..#Temptb1') IS NOT NULL
      DROP TABLE #Temptb1

END /* main procedure */

GO