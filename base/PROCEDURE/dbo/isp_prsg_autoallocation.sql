SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_PRSG_AutoAllocation                               */
/* Creation Date: 04-Nov-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21132 - SG PRSG - Auto Allocation                          */
/*                                                                         */
/* Called By: SQL Backend Job run hourly                                   */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04-Nov-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_PRSG_AutoAllocation]
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success        INT
         , @n_Err            INT
         , @c_ErrMsg         NVARCHAR(255)
         , @n_Continue       INT
         , @n_StartTranCount INT

   DECLARE @c_Storerkey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_BatchNo            NVARCHAR(10)
         , @c_Loadkey            NVARCHAR(10)
         , @c_Orderkey           NVARCHAR(10)
         , @d_OrderDate          DATETIME
         , @d_Delivery_Date      DATETIME
         , @c_OrderType          NVARCHAR(10)
         , @c_Door               NVARCHAR(10)
         , @c_Route              NVARCHAR(10)
         , @c_DeliveryPlace      NVARCHAR(30)
         , @c_OrderStatus        NVARCHAR(10)
         , @c_Priority           NVARCHAR(10)
         , @n_TotWeight          FLOAT
         , @n_TotCube            FLOAT
         , @n_TotOrdLine         INT
         , @c_C_Company          NVARCHAR(45)
         , @c_ExternOrderKey     NVARCHAR(50)
         , @c_ConsigneeKey       NVARCHAR(15)
         , @c_pickslip_DW        NVARCHAR(50)
         , @c_AllocateFull_DW    NVARCHAR(50)
         , @c_AllocatePartial_DW NVARCHAR(50)
         , @c_UserName           NVARCHAR(128)
         , @d_MaxDelivery_Date   DATETIME 
         , @n_NoOfDeliveryDay    INT = 0 
         , @n_DayCnt             INT = 0
         , @c_Lottable06         NVARCHAR(20) = N'7SGDP'

   SELECT @b_Success = 1
        , @n_Err = 0
        , @c_ErrMsg = N''
        , @n_Continue = 1
        , @n_StartTranCount = @@TRANCOUNT

   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM HolidayHeader H (NOLOCK)
                   JOIN HolidayDetail HD (NOLOCK) ON H.HolidayKey = HD.HolidayKey
                   WHERE H.UserDefine01 = 'PRSG_AUTOALLOCATE' AND DATEDIFF(DAY, HD.HolidayDate, GETDATE()) = 0)         	          
      BEGIN
         GOTO QUIT_SP
      END

      SELECT TOP 1 @n_NoOfDeliveryDay = CASE WHEN ISNUMERIC(H.UserDefine02) = 1 THEN CAST(H.UserDefine02 AS INT)
                                             ELSE 0 END
      FROM HolidayHeader H (NOLOCK)
      WHERE H.UserDefine01 = 'PRSG_AUTOALLOCATE'
      ORDER BY H.HolidayKey

      IF ISNULL(@n_NoOfDeliveryDay, 0) = 0
         SET @n_NoOfDeliveryDay = 2
   END

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      SET @c_Storerkey = N'PRSG'
      SET @c_UserName = N'PRSGALPRN'
      SET @c_AllocateFull_DW = N'r_dw_autoalloc_full'
      SET @c_AllocatePartial_DW = N'r_dw_autoalloc_partial'

      SELECT TOP 1 @c_pickslip_DW = PB_Datawindow
      FROM RCMReport (NOLOCK)
      WHERE StorerKey = @c_Storerkey AND ReportType = 'PLISTN'
      ORDER BY EditDate DESC

      IF ISNULL(@c_pickslip_DW, '') = ''
         SET @c_pickslip_DW = N'r_dw_print_pickorder03j'

      CREATE TABLE #TMP_ORD
      (
         Rowid    INT IDENTITY(1, 1)
       , Orderkey NVARCHAR(10)
       , Status   NVARCHAR(10)
      )

      WHILE @n_NoOfDeliveryDay > 0
      BEGIN
         IF  DATEPART(WEEKDAY, GETDATE() + @n_DayCnt) IN ( 2, 3, 4, 5, 6 )
         AND NOT EXISTS (  SELECT 1
                           FROM HolidayHeader H (NOLOCK)
                           JOIN HolidayDetail HD (NOLOCK) ON H.HolidayKey = HD.HolidayKey
                           WHERE H.UserDefine01 = 'PRSG_AUTOALLOCATE'
                           AND   DATEDIFF(DAY, HD.HolidayDate, GETDATE() + @n_DayCnt) = 0) --workday
         BEGIN
            SET @d_MaxDelivery_Date = GETDATE() + @n_DayCnt
            SET @n_NoOfDeliveryDay = @n_NoOfDeliveryDay - 1
         END

         SET @n_DayCnt = @n_DayCnt + 1
      END

      INSERT INTO #TMP_ORD (Orderkey, Status)
      SELECT O.OrderKey , '0'
      FROM ORDERS O (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON O.OrderKey = OD.OrderKey
      WHERE O.StorerKey = @c_Storerkey
      AND   O.Status = '0'
      AND   (O.UserDefine01 = '' OR O.UserDefine01 IS NULL)
      AND   DATEDIFF(DAY, O.DeliveryDate, @d_MaxDelivery_Date) >= 0
      AND   DATEPART(WEEKDAY, O.DeliveryDate) IN ( 2, 3, 4, 5, 6 ) --Must be weekday
      AND   NOT EXISTS (  SELECT 1
                          FROM HolidayHeader H (NOLOCK)
                          JOIN HolidayDetail HD (NOLOCK) ON H.HolidayKey = HD.HolidayKey
                          WHERE H.UserDefine01 = 'PRSG_AUTOALLOCATE' AND DATEDIFF(DAY, HD.HolidayDate, O.DeliveryDate) = 0) --Exclude public holiday
      AND   OD.Lottable06 = @c_Lottable06
      GROUP BY O.OrderKey, O.Priority
      ORDER BY O.Priority
             , O.OrderKey

      IF (  SELECT COUNT(1)
            FROM #TMP_ORD) > 0
      BEGIN
         SET @c_BatchNo = N''
         EXEC dbo.nspg_GetKey @KeyName = 'PRSGALBTH'
                            , @fieldlength = 10
                            , @keystring = @c_BatchNo OUTPUT
                            , @b_Success = @b_Success OUTPUT
                            , @n_err = @n_Err OUTPUT
                            , @c_errmsg = @c_ErrMsg OUTPUT
                            , @b_resultset = 0
                            , @n_batch = 1

         IF @b_Success <> 1
            SET @n_Continue = 3
      END
   END

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TM.Orderkey
           , O.Facility
           , O.LoadKey
      FROM #TMP_ORD TM
      JOIN ORDERS O (NOLOCK) ON TM.Orderkey = O.OrderKey
      ORDER BY TM.Rowid

      OPEN CUR_ORD

      FETCH NEXT FROM CUR_ORD
      INTO @c_Orderkey
         , @c_Facility
         , @c_Loadkey

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 )
      BEGIN
         --update batch no to order                   
         UPDATE ORDERS WITH (ROWLOCK)
         SET UserDefine01 = @c_BatchNo
           , TrafficCop = NULL
         WHERE OrderKey = @c_Orderkey

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err)
                 , @n_Err = 63200
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)
                               + ': Update Order Table Failed! (isp_PRSG_AutoAllocation)' + ' ( ' + ' SQLSvr MESSAGE='
                               + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
         END

         EXEC nsp_OrderProcessing_Wrapper @c_OrderKey = @c_Orderkey
                                        , @c_oskey = ''
                                        , @c_docarton = 'N'
                                        , @c_doroute = 'N'
                                        , @c_tblprefix = ''
                                        , @c_extendparms = ''
                                        , @c_StrategykeyParm = ''

         SET @c_OrderStatus = N'0'
         SELECT @c_OrderStatus = Status
         FROM ORDERS (NOLOCK)
         WHERE OrderKey = @c_Orderkey

         UPDATE #TMP_ORD
         SET Status = @c_OrderStatus
         WHERE Orderkey = @c_Orderkey

         --create load plan per order
         IF ISNULL(@c_Loadkey, '') = '' -- AND @c_OrderStatus = '2'
         BEGIN
            EXEC dbo.nspg_GetKey @KeyName = 'LOADKEY'
                               , @fieldlength = 10
                               , @keystring = @c_Loadkey OUTPUT
                               , @b_Success = @b_Success OUTPUT
                               , @n_err = @n_Err OUTPUT
                               , @c_errmsg = @c_ErrMsg OUTPUT
                               , @b_resultset = 0
                               , @n_batch = 1

            IF @b_Success <> 1
               SET @n_Continue = 3

            INSERT INTO LoadPlan (LoadKey, facility, UserDefine10)
            VALUES (@c_Loadkey, @c_Facility, @c_BatchNo)

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err)
                    , @n_Err = 63200
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)
                                  + ': Insert LoadPlan Table Failed! (isp_PRSG_AutoAllocation)' + ' ( '
                                  + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
            END

            SELECT @d_OrderDate = O.OrderDate
                 , @d_Delivery_Date = O.DeliveryDate
                 , @c_OrderType = O.Type
                 , @c_Door = O.Door
                 , @c_Route = O.Route
                 , @c_DeliveryPlace = O.DeliveryPlace
                 , @c_OrderStatus = O.Status
                 , @c_Priority = O.Priority
                 , @n_TotWeight = SUM(OD.OpenQty * SKU.STDGROSSWGT)
                 , @n_TotCube = SUM(OD.OpenQty * SKU.STDCUBE)
                 , @n_TotOrdLine = COUNT(DISTINCT OD.OrderLineNumber)
                 , @c_C_Company = O.C_Company
                 , @c_ExternOrderKey = O.ExternOrderKey
                 , @c_ConsigneeKey = O.ConsigneeKey
            FROM ORDERS O WITH (NOLOCK)
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey)
            JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
            WHERE O.OrderKey = @c_Orderkey
            GROUP BY O.OrderDate
                   , O.DeliveryDate
                   , O.Type
                   , O.Door
                   , O.Route
                   , O.DeliveryPlace
                   , O.Status
                   , O.Priority
                   , O.C_Company
                   , O.ExternOrderKey
                   , O.ConsigneeKey

            EXEC isp_InsertLoadplanDetail @cLoadKey = @c_Loadkey
                                        , @cFacility = @c_Facility
                                        , @cOrderKey = @c_Orderkey
                                        , @cConsigneeKey = @c_ConsigneeKey
                                        , @cPrioriry = @c_Priority
                                        , @dOrderDate = @d_OrderDate
                                        , @dDelivery_Date = @d_Delivery_Date
                                        , @cOrderType = @c_OrderType
                                        , @cDoor = @c_Door
                                        , @cRoute = @c_Route
                                        , @cDeliveryPlace = @c_DeliveryPlace
                                        , @nStdGrossWgt = @n_TotWeight
                                        , @nStdCube = @n_TotCube
                                        , @cExternOrderKey = @c_ExternOrderKey
                                        , @cCustomerName = @c_C_Company
                                        , @nTotOrderLines = @n_TotOrdLine
                                        , @nNoOfCartons = 0
                                        , @cOrderStatus = @c_OrderStatus
                                        , @b_Success = @b_Success OUTPUT
                                        , @n_Err = @n_Err OUTPUT
                                        , @c_ErrMsg = @c_ErrMsg OUTPUT

            IF @b_Success <> 1
               SET @n_Continue = 3
         END

         FETCH NEXT FROM CUR_ORD
         INTO @c_Orderkey
            , @c_Facility
            , @c_Loadkey
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   --Print fully allocate report
   IF EXISTS (  SELECT 1
                FROM #TMP_ORD
                WHERE Status = '2')
   BEGIN
      EXEC isp_PrintToRDTSpooler @c_ReportType = 'AUTOALRPT'
                               , @c_Storerkey = @c_Storerkey
                               , @b_success = @b_Success OUTPUT
                               , @n_err = @n_Err OUTPUT
                               , @c_errmsg = @c_ErrMsg OUTPUT
                               , @n_Noofparam = 2
                               , @c_Param01 = @c_Storerkey
                               , @c_Param02 = @c_BatchNo
                               , @c_UserName = @c_UserName
                               , @c_Facility = @c_Facility
                               , @c_PrinterID = ''
                               , @c_Datawindow = @c_AllocateFull_DW
                               , @c_IsPaperPrinter = 'Y'
                               , @c_JobType = 'TCPSPOOLER'
                               , @n_Function_ID = 999
   END

   IF EXISTS (  SELECT 1
                FROM #TMP_ORD
                WHERE Status < '2')
   BEGIN
      EXEC isp_PrintToRDTSpooler @c_ReportType = 'AUTOALRPT'
                               , @c_Storerkey = @c_Storerkey
                               , @b_success = @b_Success OUTPUT
                               , @n_err = @n_Err OUTPUT
                               , @c_errmsg = @c_ErrMsg OUTPUT
                               , @n_Noofparam = 2
                               , @c_Param01 = @c_Storerkey
                               , @c_Param02 = @c_BatchNo
                               , @c_UserName = @c_UserName
                               , @c_Facility = @c_Facility
                               , @c_PrinterID = ''
                               , @c_Datawindow = @c_AllocatePartial_DW
                               , @c_IsPaperPrinter = 'Y'
                               , @c_JobType = 'TCPSPOOLER'
                               , @n_Function_ID = 999
   END

   --Print pickslip   
   DECLARE CUR_PICKSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT O.LoadKey
                 , O.Facility
   FROM #TMP_ORD TM
   JOIN ORDERS O (NOLOCK) ON TM.Orderkey = O.OrderKey AND O.Status = '2'
   ORDER BY O.LoadKey

   OPEN CUR_PICKSLIP

   FETCH NEXT FROM CUR_PICKSLIP
   INTO @c_Loadkey
      , @c_Facility

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC isp_PrintToRDTSpooler @c_ReportType = 'PLISTN'
                               , @c_Storerkey = @c_Storerkey
                               , @b_success = @b_Success OUTPUT
                               , @n_err = @n_Err OUTPUT
                               , @c_errmsg = @c_ErrMsg OUTPUT
                               , @n_Noofparam = 1
                               , @c_Param01 = @c_Loadkey
                               , @c_UserName = @c_UserName
                               , @c_Facility = @c_Facility
                               , @c_PrinterID = ''
                               , @c_Datawindow = @c_pickslip_DW
                               , @c_IsPaperPrinter = 'Y'
                               , @c_JobType = 'TCPSPOOLER'
                               , @n_Function_ID = 999

      FETCH NEXT FROM CUR_PICKSLIP
      INTO @c_Loadkey
         , @c_Facility
   END
   CLOSE CUR_PICKSLIP
   DEALLOCATE CUR_PICKSLIP

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PRSG_AutoAllocation'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO