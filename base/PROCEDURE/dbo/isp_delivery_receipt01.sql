SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Delivery_Receipt01                             */
/* Creation Date: 16-FEB-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW (Modify from isp_Delivery_Receipt_kfp)              */
/*                                                                      */
/* Purpose: Shell Delivery Receipt (SOS127661)                          */
/*                                                                      */
/* Called By: r_dw_delivery_receipt01                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-Oct-2009  ChewKP        SOS#149425 Retrieve Facility.Descr        */
/*                            (ChewKP01)                                */
/* 04-MAR-2014  YTWan         SOS#303595 - PH - Update Loading Sheet RCM*/
/*                            (Wan01)                                   */
/* 03-NOV-2015  SPChin        SOS356337 - Add Filter By StorerKey       */
/* 25-JAN-2017  JayLim        SQL2012 compatibility modification (Jay01)*/  
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Receipt01] (@cMBOLkey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @cStorerkey       NVARCHAR(15)
      ,  @cUserdefine10    NVARCHAR(10)
      ,  @cDRCounterKey    NVARCHAR(10)
      ,  @cCurrExternKey   NVARCHAR(30)
      ,  @cPrevExternKey   NVARCHAR(30)
      ,  @cCurrSKU         NVARCHAR(20)
      ,  @cPrevSKU         NVARCHAR(20)
      ,  @nSeqNum          int
      ,  @nTotalOrderQty   int
      ,  @cPrintFlag       NVARCHAR(1)
      ,  @nRecCnt          int
      ,  @cOrderGroup      NVARCHAR(20)
      ,  @cC_company       NVARCHAR(45)

 DECLARE @n_err            int
      ,  @n_continue       int
      ,  @b_success        int
      ,  @c_errmsg         NVARCHAR(255)
      ,  @n_starttcnt      int
      ,  @b_debug          int
      ,  @c_IDS_Company    NVARCHAR(45)   --(Wan01)

  -- tlting01 - change Memory table to temp table
 CREATE TABLE #TempFlag (
  OrderGroup    [NVARCHAR] (20) NULL,
  PrintFlag     [NVARCHAR] (1)  NULL,
  c_Company     [NVARCHAR] (45) NULL )


  Create Clustered index [PK_tempFlag] on #TempFlag (OrderGroup)  -- tlting01

 CREATE TABLE #TempData (
  MBOLKey            [NVARCHAR] (10) NULL,
  UserDefine10       [NVARCHAR] (10) NULL,
  PrintFlag          [NVARCHAR] (1)  NULL,
  Consigneekey       [NVARCHAR] (15) NULL,
  C_Company          [NVARCHAR] (45) NULL,
  C_Address1         [NVARCHAR] (45) NULL,
  C_Address2         [NVARCHAR] (45) NULL,
  C_Address3         [NVARCHAR] (45) NULL,
  C_Address4         [NVARCHAR] (45) NULL,
  DepartureDate      [datetime]  NULL,
  CarrierAgent       [NVARCHAR] (30) NULL,
  VesselQualifier    [NVARCHAR] (10) NULL,
  DriverName         [NVARCHAR] (30) NULL,
  Vessel             [NVARCHAR] (30) NULL,
  OtherReference     [NVARCHAR] (30) NULL,
  SKU                [NVARCHAR] (20) NULL,
  SkuDescr           [NVARCHAR] (60) NULL,
  Company            [NVARCHAR] (45) NULL,
  Lot2               [NVARCHAR] (18) NULL,
  ShippedQty         [int]   NULL,
  DRDate             [datetime]  NULL,
  ordergroup         [NVARCHAR] (20) NULL,
  loadkey            [NVARCHAR] (10) NULL,
  Lot4               [datetime] NULL,
  grosswgt           decimal (12,2) NULL,
  liters             decimal (12,2) NULL,
  cbm                decimal (12,2) NULL,
  remakrs            [NVARCHAR] (500) NULL,
  facility           [NVARCHAR] (5) NULL,
  descr              [NVARCHAR] (50) NULL)  --  SOS#149425 ChewKP01

 SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_debug = 0, @n_err = 0
 SET @cPrintFlag = ''


 SELECT @nRecCnt = COUNT(1) FROM ORDERS (NOLOCK)
 WHERE MBOLKey = @cMBOLkey

 IF @nRecCnt <= 0
 BEGIN

  SELECT @n_continue = 4
  IF @b_debug = 1
   PRINT 'No Data Found'
 END
 ELSE
  IF @b_debug = 1
   PRINT 'Start Processing...  MBOLKey=' + @cMBOLkey



 -- Assign DR Number (at OrderGroup level) to all orders under this MBOLKey!
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
  DECLARE CurOrderGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT StorerKey, OrderGroup, UserDefine10, c_Company
  FROM ORDERS (NOLOCK)
  WHERE MBOLKey = @cMBOLkey
  GROUP BY StorerKey, OrderGroup, UserDefine10, c_Company
  ORDER BY OrderGroup,UserDefine10, c_Company

  OPEN CurOrderGroup
  FETCH NEXT FROM CurOrderGroup INTO @cStorerkey, @cOrderGroup, @cUserDefine10, @cC_Company

  WHILE @@FETCH_STATUS <> -1 -- CurOrderGroup Loop
  BEGIN
   IF @b_debug = 1
      PRINT 'Storerkey=' + @cStorerkey +' ;ExternOrderKey=' + @cOrderGroup  + ' ;UserDefine10' + @cUserDefine10

   IF @cUserDefine10 = ''
   BEGIN
    SET @cPrintFlag = 'N'
    SET @cDRCounterKey = ''

    SELECT @cDRCounterKey = Code
    FROM CodeLkUp (NOLOCK)
      WHERE ListName = 'DR_NCOUNT'
    AND SHORT = @cStorerkey

    IF @cDRCounterKey = ''
    BEGIN
     SELECT @n_continue = 3
     SELECT @n_err = 63500  -- should assign new error code
     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Setup for CodeLkUp.ListName = DR_NCOUNT. (isp_Delivery_Receipt01) "+@cstorerkey
    END

    IF @b_debug = 1
       PRINT 'Check this: SELECT Code FROM CodeLkUp (NOLOCK) WHERE ListName = ''DR_NCOUNT'' AND SHORT =N''' + dbo.fnc_RTrim(@cStorerkey) + ''''

    IF @n_continue = 1 or @n_continue = 2
    BEGIN
     SELECT @b_success = 0

     EXECUTE nspg_GetKey @cDRCounterKey, 10,
       @cUserDefine10 OUTPUT,
       @b_success    OUTPUT,
       @n_err     OUTPUT,
       @c_errmsg     OUTPUT

     IF @b_debug = 1
      PRINT ' GET UserDefine10 (DR)= ' + @cUserDefine10 + master.dbo.fnc_GetCharASCII(13)

     IF @b_success <> 1
     BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500  -- should assign new error code
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fail to Generate Userdeine10 . (isp_Delivery_Receipt01)"
     END
     ELSE
      BEGIN
      UPDATE ORDERS
      SET UserDefine10 = @cUserDefine10,
                      UserDefine07 = GetDate()   -- Update DR Print Date 'added by fklim 07032007
      WHERE MBOLKey = @cMBOLKey
      AND StorerKey = @cStorerKey
      AND  OrderGroup = @cOrderGroup
      AND C_Company = @cC_company

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 63501  -- should assign new error code
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE ORDERS Failed. (isp_Delivery_Receipt01)"
      END
     END
    END  -- @n_continue = 1 or @n_continue = 2
   END
   ELSE
   BEGIN
    SET @cPrintFlag = 'Y'
   END

   INSERT INTO #TempFlag(PrintFlag, OrderGroup, c_Company)    -- tlting01
   VALUES(@cPrintFlag, @cOrderGroup, @cC_Company)

   FETCH NEXT FROM CurOrderGroup INTO @cStorerkey, @cOrderGroup, @cUserDefine10, @cC_company
  END

  CLOSE CurOrderGroup
      DEALLOCATE CurOrderGroup
 END -- @nRecCnt > 0

 IF @b_debug = 1 SELECT * FROM #TempFlag

 -- Insert into @TempData table
 IF @n_continue = 1 OR @n_continue = 2
 BEGIN
      INSERT INTO #TempData
      SELECT
      ORDERS.MBOLKey,
      ORDERS.UserDefine10,
      T.PrintFlag,
      ORDERS.Consigneekey,
      ORDERS.C_Company,
      ISNULL(ORDERS.C_Address1,''),
      ISNULL(ORDERS.C_Address2,''),
      ISNULL(ORDERS.C_Address3,''),
      ISNULL(ORDERS.C_Address4,''),
      MBOL.DepartureDate,
      MBOL.CarrierAgent,
      MBOL.VesselQualifier,
      MBOL.DriverName,
      MBOL.Vessel,
      MBOL.OtherReference,
      ORDERDETAIL.SKU,
      SKU.Descr SkuDescr,
      STORER.Company,
      LOTATTRIBUTE.Lottable02 Lot2,
      SUM(Pickdetail.Qty) As ShippedQty,
      MBOL.EditDate,
      ORDERS.ordergroup,
      ORDERS.loadkey,
      LOTATTRIBUTE.Lottable04,
      ROUND(SUM(Pickdetail.Qty * SKU.stdgrosswgt),2) AS grosswgt,
      ROUND(SUM(Pickdetail.Qty * SKU.[cube]),2) AS liters,  --jaylim
      ROUND(SUM(Pickdetail.Qty * SKU.stdcube),2) AS cbm,
      CONVERT(NVARCHAR(500),MBOL.Remarks) as remarks,
      MBOL.Facility,  --  SOS#149425 ChewKP01
      FACILITY.Descr
       FROM ORDERS      WITH (NOLOCK)
       JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERS.OrderKey = OrderDetail.OrderKey
       JOIN MBOLDETAIL  WITH (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey
       JOIN STORER      WITH (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
       JOIN SKU         WITH (NOLOCK) ON (SKU.SKU = OrderDetail.SKU AND SKU.StorerKey = OrderDetail.StorerKey)	--SOS356337
       JOIN MBOL        WITH (NOLOCK) ON MBOL.MBOLKey = MBOLDETAIL.MBOLKey
       JOIN PICKDETAIL  WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
                                      AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
       JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.lot = LOTATTRIBUTE.LOT
       JOIN PACK         WITH (NOLOCK) ON SKU.Packkey = PACK.PackKey
       JOIN FACILITY     WITH (NOLOCK) ON MBOL.FACILITY = FACILITY.Facility  --  SOS#149425 ChewKP01
       LEFT OUTER JOIN #TempFlag T ON (T.OrderGroup = ORDERS.OrderGroup AND T.C_Company = ORDERS.C_Company) -- tlting01
       WHERE ORDERS.MBOLKEY = @cMBOLKey
       GROUP BY
	            ORDERS.MBOLKey,
	            ORDERS.UserDefine10,
	            T.PrintFlag,
	            ORDERS.Consigneekey,
	            ORDERS.C_Company,
	            ISNULL(ORDERS.C_Address1,''),
	            ISNULL(ORDERS.C_Address2,''),
	            ISNULL(ORDERS.C_Address3,''),
	            ISNULL(ORDERS.C_Address4,''),
	            MBOL.DepartureDate,
	            MBOL.CarrierAgent,
	            MBOL.VesselQualifier,
	            MBOL.DriverName,
	            MBOL.Vessel,
	            MBOL.OtherReference,
	            ORDERDETAIL.SKU,
	            SKU.Descr,
	            STORER.Company,
	            LOTATTRIBUTE.Lottable02,
            MBOL.EditDate ,
	            ORDERS.ordergroup,
	            ORDERS.loadkey,
	            LOTATTRIBUTE.Lottable04,
	            CONVERT(NVARCHAR(500),MBOL.Remarks),
	            MBOL.Facility,
	            FACILITY.Descr --  SOS#149425 ChewKP01
      ORDER BY
            ORDERS.OrderGroup,
            ORDERS.UserDefine10,
            ORDERDETAIL.SKU,
            LOTATTRIBUTE.Lottable02
   END


   --(Wan01) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN

      SET  @c_IDS_Company = ''

      SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')
      FROM STORER WITH (NOLOCK)
      WHERE Storerkey = 'IDS'

      IF @c_IDS_Company = ''
      BEGIN
         SET @c_IDS_Company = 'LF (Philippines), Inc.'
      END
   END

   SELECT MBOLKey
      ,  UserDefine10
      ,  PrintFlag
      ,  Consigneekey
      ,  C_Company
      ,  C_Address1
      ,  C_Address2
      ,  C_Address3
      ,  C_Address4
      ,  DepartureDate
      ,  CarrierAgent
      ,  VesselQualifier
      ,  DriverName
      ,  Vessel
      ,  OtherReference
      ,  SKU
      ,  SkuDescr
      ,  Company
      ,  Lot2
      ,  ShippedQty
      ,  DRDate
      ,  ordergroup
      ,  loadkey
      ,  Lot4
      ,  grosswgt
      ,  liters
      ,  cbm
      ,  remakrs
      ,  facility
      ,  descr
      ,  IDS_COMPANY = @c_IDS_Company
   FROM #TempData
   --(Wan01) - END

 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
  EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Delivery_Receipt01'
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

END /* main procedure */


GO