SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store Procedure: isp_ValidateMBOL                                         */
/* Creation Date:                                                            */
/* Copyright: IDS                                                            */
/* Written by:                                                               */
/*                                                                           */
/* Purpose: MBOL Validation                                                  */
/*                                                                           */
/* Called By: PowerBuilder Upon Mark Ship                                    */
/*                                                                           */
/* PVCS Version: 1.33                                                        */
/*             : Last @n_err=73029                                           */
/*                                                                           */
/* Version: 5.4                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author    Ver.  Purposes                                     */
/* 22-Mar-2005  Shong           Tuning SQL select                            */
/* 06-May-2005  Shong           Validation to ensure that an order must      */
/*                              undergo the packing process before MBOL      */
/* 13-Jul-2005  YokeBeen        Scripts Tuning - (YokeBeen01)                */
/* 25-Jul-2005  Shong           Take ALLOWOVERALLOCATIONS into consideration */
/* 19-Aug-2005  June            SOS39592 - bug fixed IDSPH ULP v54 upgrade   */
/*                              Add link MBOLDETAIL to OrderDetail by Loadkey*/
/* 10-Jan-2007  June            SOS#65533 - Pick / Pack Qty Validation for   */
/*                                          Timberland                       */
/* 07-Nov-2008  YTWAN     1.1   SOS#120983 - Validation Check for Invalid    */
/*                                           Storerkey and sku               */
/* 11-Mar-2009  SHONG     1.2   SOS#123359 - MBOL Userdefine Mandatory fields*/
/* 10-Jul-2009  SHONG     1.3   SOS#141354 - PackBeforeShip:                 */
/*                                           sValue: 1=Warning 2=Compulsory  */
/* 01-Dec-2008  KC        1.4   SOS#123329 - Do not allow to ship if found   */
/*                                           preallocatepickdetail record    */
/*                                           (KC01)                          */
/* 22-Jul-2009  Vicky     1.5   SOS#140791 - CMS Capture PackHeader Summary  */
/* 14-09-2009   TLTING    1.6   ID field length (tlting01)                   */
/* 22-Feb-2010  NJOW02    1.7   SOS#144067 - Split Partial and UnAllocated   */
/*                              Order in a Loadplan. Not allow to ship if    */
/*                              split orders not fully allocated             */
/* 14-Jan-2010  NJOW01    1.8   SOS#153916 - Remy validate serial no scan out*/
/* 30-Mar-2010  James     1.9   Change serial no scan out validation(james01)*/
/* 21-May-2010  TLTING    1.10  Deploy item 1.4                              */
/* 24-Jul-2010  Vicky     1.11  Check whether All Totes are being scanned    */
/*                              upon mark Ship if configkey CheckAllToteScan */
/*                              is being turned on (Vicky01)                 */
/* 29-Jul-2010  Vicky     1.11  Cannot ship MBOL if still have remaining     */
/*                              allocated QTY to be unallocated (Vicky02)    */
/* 18-Aug-2010  Vicky     1.11  TotalPackTote should count by LabelNo        */
/*                              (Vicky03)                                    */
/* 28-Aug-2010  James     1.11  Only store orders need to validate no of     */
/*                              carton scanned to van (james02)              */
/* 04-Mar-2010  NJOW03    1.12  SOS#175984 - Order type exception validate   */
/*                                           in PackBeforeShip.              */
/* 16-Feb-2011  Leong     1.12  SOS#202300 - Revise logic for MBOL Extended  */
/*                                           Validation.                     */
/* 09-Mar-2011  NJOW      1.12  SOS# - Revise logic for data retrieval       */
/* 25-Mar-2011  Leong     1.12  SOS# 209421 - Reset variables                */
/* 25-Mar-2011  SHONG     1.12  To take care of Order with Multiple PickSlip */
/* 27-Apr-2011  SHONG     1.13  SOS# 213415 - Check Extended Validation      */
/*                                           By StorerKey + Facility         */
/* 09-May-2011  NJOW04    1.16  SOS# 214494 - Extended validation call sp    */
/* 07-Jun-2011  Leong     1.17  SOS# 217791 - Bug Fix                        */
/* 29-Dec-2011  ChewKP    1.18  SKIPJACK Fixes , Validate by ConsoOrderKey   */
/*                              (ChewKP01)                                   */
/* 10-01-2012   ChewKP    1.18  Standardize ConsoOrderKey Mapping            */
/*                              (ChewKP02)                                   */
/* 14-04-2012   Shong     1.18  Bug Fixing                                   */
/* 16-04-2012   ChewKP    1.18  Exclude Pick&Pack Matching checking when     */
/*                              FluidLoad = 'Y' (ChewKP03)                   */
/* 19-04-2012   Ung       1.18  Check split order not yet completed (ung01)  */
/* 29-04-2012   Shong     1.19  Added New Validation for LCI Process         */
/* 15-05-2012   Shong     1.19  Change Fluid Load Lane Checking              */
/* 22-05-2012   Shong     1.19  Added FreightCharge Is Required Checking     */
/* 02-06-2012   ChewKP    1.20  Include OrderInfo07 = 'USA' checking         */
/*                              (ChewKP04)                                   */
/* 14-06-2012   Shong     1.21  Fixing OrderInfo07 Issues                    */
/* 26-JUN-2012  YTWan     1.22  SOS#245687: MBOLErrorReport (Wan01)          */
/* 26-JUN-2102  YTWan     1.23  SOS#247765: Validate MBOL DepartureDate-wan02*/
/* 25-06-2012   ChewKP    1.24  SOS#248249 - Only Check Order for current    */
/*                              MBOL (ChewKP05)                              */
/* 20-07-2012   ChewKP    1.25  SOS#251076 - MBOL Report Issues (ChewKP06)   */
/* 24-07-2012   ChewKP    1.26  SOS#251188-Include Non SplitOrders and cater */
/*                              Storer not using PickDetail.CaseID (CheWKP07)*/
/* 13-JUL-2102  YTWan     1.27  SOS#248597: IDSUS-LIZ Pallet Validation.     */
/*                              (Wan04)                                      */
/* 14-Aug-2012  James     1.28  SOS#253285 - Change @TempPickTable to        */
/*                              #TempPickTable for perf tuning (james03)     */
/* 15-Aug-2012  TLTING02  1.28  Perfromance tune                             */
/* 06-JUL-2102  YTWan     1.28  SOS#249041: Validate 100% short pick order   */
/*                              (Wan03)                                      */
/* 13-Sep-2012 YTWan     1.29  SOS#255779:MBOL Preaudit Check to return all  */
/*                              errors. (Wan05)                              */
/* 27-Aug-2012  ChewKP    1.30  SOS#252415 - CBOL Validation (ChewKP08)      */
/* 28-Aug-2012  ChewKP    1.31  SOS#251852 - Validate Tracking# for          */
/*                              International (ChewKP09)                     */
/* 19-Sep-2012  YTWan     1.32  SOS#249041 -Enhancement. To use MBOLDETAIL   */
/*                              instead of #MBOLCheck as loadplan deleted    */
/*                              after  to MBOL. (Wan06)                      */
/* 14-May-2013 NJOW05    1.33   278062-Scan to truck validation enhancements.*/
/*                              CheckAllToteScan='2' for URNNo=LabelNo       */
/* 15-SEp-2014  Leong    1.34  SOS# 320856 - Change Left Join PickDetail.    */
/* 08-SEP-2104  YTWan    1.6   SOS#319760 - TW - Project Echo Finalize MBOL  */
/*                             (Wan07)                                       */
/* 11-Aug-2016  NJOW06   1.7   374687-Allowoverallocations storerconfig      */
/*                             control by facility                           */
/* 20-Sep-2016  TLTING   1.8   remove SET ROWCOUNT                           */
/* 11-Nov-2017  ChewKP   1.9   Temp Fix ByPass Replen No done error(ChewKP10)*/
/* 11-Nov-2017  TLTING03 1.9   Remark filtering                              */
/* 13-Dec-2017  TLTING04 1.10  Performance tune                              */
/* 08-Jun-2018  TLTING05 1.11  Performance tune -add primary key #P          */
/* 13-Sep-2018  NJOW07   1.12  WMS-5961 add call From                        */
/* 29-Aug-2019  WLChooi  1.13  WMS-10388 - PackBeforeShip exclude Order Type */
/*                                         (WL01)                            */
/* 11-Jun-2019  TLTING06 1.14  Performance tune - optimized                  */
/* 25-Sep-2019  TLTING07 1.15  Performance tune - optimized                  */
/* 12-May-2020  NJOW08   1.16  WMS-13265 Conditional Skip CheckAllToteScan   */
/* 30-Oct-2020  TLTING08 1.17  Tuning - Remark optimized                     */
/* 02-Nov-2020  SHONG    1.18  WMS-15634 WT01 - Filder Ecom Ordes            */
/* 20-Nov-2020  TLTING09 1.19  Performance Tuning                            */
/* 06-Nov-2020  NJOW09   1.20  WMS-15620 loadplan must be complete populated */
/*                             into one MBOL validation.                     */
/* 02-Dec-2020  BeeTin   1.21  INC1363640 - Add ISNULL check.                */
/* 02-Nov-2021  Shong    1.22  Initialize Variable (SWT01)                   */
/* 30-Nov-2022  LZG      1.23  Added ISNULL check for pick & pack Qty (ZG01) */
/*****************************************************************************/

CREATE PROCEDURE [dbo].[isp_ValidateMBOL]
   @c_MBOLKey    NVARCHAR(10),
   @b_ReturnCode Int = 0        OUTPUT, -- 0 = OK, -1 = Error, 1 = Warning
   @n_err        Int = 0        OUTPUT,
   @c_errmsg     NVARCHAR(255) = '' OUTPUT,
   @n_CBOLKey    BigInt = 0,
   @c_CallFrom   NVARCHAR(30) = ''  --NJOW07
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- (YokeBeen01) - Start
-- TraceInfo


 -- TraceInfo (tlting01) - Start
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)

   SET @c_col1 = @c_MBOLKey
   SET @d_starttime = getdate()

   SET @c_TraceName = 'isp_ValidateMBOL'
-- TraceInfo (tlting01) - End


DECLARE    @n_TraceFlag    Int,
           @c_SQL             NVARCHAR(MAX), --NJOW04
           @cConsoOrderKey    NVARCHAR(30),   -- (ChewKP02)
           @cFluidLoadEXPickAPackMatchCheck NVARCHAR(1), -- (ChewKP03)
           @cFluidLoad        NVARCHAR(1), -- (ChewKP03)
           @cOriginalOrderKey NVARCHAR(10)
         , @c_Type            NVARCHAR(10) --(Wan01)
         , @c_MBOLSCACCodeValidation NVARCHAR(1) -- (ChewKP08)
         , @c_ShipByCBOL      NVARCHAR(1)        -- (ChewKP08)
         , @n_CBOLKeyCheck    BigInt            -- (ChewKP08)
         , @c_MBOLNotAllowPartialLoad NVARCHAR(30)  --NJOW09
         , @c_MbolNotAllowPartialLoad_opt5 NVARCHAR(500) --NJOW09
         , @c_DocType         NCHAR(1) --NJOW09

SET @c_Type = ''                          --(Wan01)
SET @n_TraceFlag = 0 -- SOS#202300
-- (YokeBeen01) - End

DECLARE @n_Continue Int
SELECT @n_Continue = 1, @b_ReturnCode = 0

DECLARE @c_CartonGroup NVARCHAR(10), -- SOS140791
        @c_Loadkey     NVARCHAR(10)  -- SOS140791

-- (Vicky01)- Start
DECLARE @cCheckAllToteScan NVARCHAR(1),
        @c_CheckAllToteScan_Opt5 NVARCHAR(1000),  --NJOW08
        @c_ExcludeOrderGroupShort NVARCHAR(1000), --NJOW08
        @nTotalPackTote    Int,
        @nTotalScanTote    Int,
        @cCheckShortPick   NVARCHAR(1) -- (Vicky02)
-- (Vicky01) - End

--(Wan07) - START
DECLARE @b_success      INT
      , @c_facility        NVARCHAR(5)
      , @c_Storerkey       NVARCHAR(15)
      , @c_FinalizeMBOL    NVARCHAR(10)
--(Wan07) - END

CREATE Table #MBOLCheck
   (StorerKey        NVARCHAR(15) NULL,
    OrderKey         NVARCHAR(10) NULL,
    OrderLineNumber  NVARCHAR(5)  NULL,
    Type             NVARCHAR(10) NULL,
    QtyAllocated     Int      NULL,
    QtyPicked        Int      NULL,
    LoadKey          NVARCHAR(10) NULL,
    Facility         NVARCHAR(5)  NULL,
    UserDefine08     NVARCHAR(10) NULL,
    Status           NVARCHAR(10) NULL,
    OriginalQty      Int      NULL,
    ShippedQty       Int      NULL,
    PickSlipNo       NVARCHAR(10) NULL,
    PickSlipStatus   NVARCHAR(10) NULL)

-- SOS#207293 (Start)
CREATE TABLE #ConsoPick
   (Refkey     Int IDENTITY(1,1) Primary key,
    PickSlipNo NVARCHAR(10) NULL,
    LoadKey    NVARCHAR(20) NULL,
    Status     NVARCHAR(10) NULL)

CREATE TABLE #OrderPick
   (Refkey     Int IDENTITY(1,1) Primary key,
    PickSlipNo NVARCHAR(10) NULL,
    OrderKey   NVARCHAR(10) NULL,
    Status     NVARCHAR(10) NULL,
    FluidLoad  NVARCHAR(1)  NULL ) -- (ChewKP03)

CREATE TABLE #ErrorLogDetail
   (RowNo      Int IDENTITY(1,1) Primary key,
    Key1       NVARCHAR(30) NULL,
    Key2       NVARCHAR(30) NULL,
    Key3       NVARCHAR(30) NULL,
    LineText   NVARCHAR(MAX) )

-- (ChewKP01)
   --DECLARE @TempPickTable TABLE
   CREATE TABLE #TempPickTable   -- (james03)
   (
     RowRef          Int IDENTITY(1,1) Primary key,
     PickSlipNo      NVARCHAR(10),
     SKU             NVARCHAR(20) NULL,
     PickQty         INT  NULL ,
     PackQty         INT NULL      )

   CREATE INDEX IX_TempPickTable_PickSlipNo on #TempPickTable ( PickSlipNo )

   DECLARE @nTTPackQty INT,
           @nTTPickQty INT,
           @cTTSKU     NVARCHAR(20)

   SET @d_step1 = GETDATE()  -- (tlting01)

   DELETE FROM MBOLErrorReport WHERE MBOLKey = @c_MBOLKey               --(Wan01)

   INSERT INTO #ConsoPick (PickSlipNo, LoadKey, Status)
   SELECT  PickHeaderKey AS PickSlipNo, PickHeader.ExternOrderKey AS LoadKey,
           PackHeader.Status
   FROM PickHeader WITH (NOLOCK)
   JOIN MBOLDetail WITH (NOLOCK) ON MBOLDetail.LoadKey = PickHeader.ExternOrderKey
   JOIN PackHeader WITH (NOLOCK) ON (PackHeader.PickSlipNo = PickHeader.PickHeaderKey)
   WHERE (PickHeader.OrderKey IS NULL OR PickHeader.OrderKey = '')
   AND   (PickHeader.ExternOrderKey IS NOT NULL AND PickHeader.ExternOrderKey <> '')
   AND   MBOLDETAIL.MBOLKey =  @c_MBOLKey
   AND   (PickHeader.Zone Not IN ('XD','LP','LB'))
   GROUP BY PickHeaderKey, PickHeader.ExternOrderKey, PackHeader.Status

   INSERT INTO #OrderPick (PickSlipNo, OrderKey, STATUS, FluidLoad)
   SELECT PickHeaderKey AS PickSlipNo, PickHeader.OrderKey, PackHeader.Status,'N'
   FROM PickHeader WITH (NOLOCK)
   JOIN MBOLDetail WITH (NOLOCK) ON MBOLDetail.OrderKey = PickHeader.OrderKey
   JOIN PackHeader WITH (NOLOCK) ON (PackHeader.PickSlipNo = PickHeader.PickHeaderKey)
   WHERE PickHeader.OrderKey IS NOT NULL AND PickHeader.OrderKey <> ''
   AND   (PickHeader.Zone Not IN ('XD','LP','LB'))
   AND   MBOLDETAIL.MBOLKey = @c_MBOLKey

-- 25-Mar-2011  SHONG     1.12
-- Cater Other Type of Pick Slip
-- Only insert 1 pickslip for 1 order
   DECLARE @c_OrderKey   NVARCHAR(10),
           @c_PickSlipNo NVARCHAR(10),
           @c_PickStatus NVARCHAR(10)
   -- TLTING02 Start
   CREATE TABLE #Orders
   ( ROWREF       INT NOT NULL Identity(1,1) Primary Key,
     OrderKey     NVARCHAR(10),
     ConsoOrderKey NVARCHAR(30)  )

   INSERT INTO #Orders (OrderKey, ConsoOrderKey )
   SELECT DISTINCT rkl.OrderKey, ISNULL(RTRIM(ph.ConsoOrderKey),'')
   FROM RefKeyLookUp rkl (NOLOCK)
   JOIN MBOLDETAIL m (NOLOCK) ON m.OrderKey = rkl.OrderKey
   JOIN PackHeader ph (NOLOCK) ON ph.PickSlipNo = rkl.Pickslipno
   WHERE m.MbolKey = @c_MBOLKey

   IF EXISTS ( Select 1 from #Orders WHERE ConsoOrderKey = '')
   BEGIN
      INSERT INTO #OrderPick (PickSlipNo, OrderKey, Status, FluidLoad)
      SELECT
             Pickslipno = ( SELECT TOP 1 rkl.Pickslipno
                              FROM RefKeyLookUp rkl (NOLOCK)
                              JOIN PackHeader ph (NOLOCK) ON ph.Pickslipno = rkl.Pickslipno
                              WHERE ph.OrderKey  = O.OrderKey
                              Order by Status    ),
             O.OrderKey,
             PickStatus = ( SELECT TOP 1 Status
                              FROM RefKeyLookUp rkl (NOLOCK)
                              JOIN PackHeader ph (NOLOCK) ON ph.Pickslipno = rkl.Pickslipno
                              WHERE ph.OrderKey  = O.OrderKey
                              Order by Status    ),
             'N'
      FROM #Orders O
      WHERE O.ConsoOrderKey = ''

   END

   IF EXISTS ( Select 1 from #Orders WHERE ConsoOrderKey <> '')
   BEGIN
      INSERT INTO #OrderPick ( PickSlipNo, OrderKey, Status, FluidLoad )
      SELECT  Pickslipno = ( SELECT TOP 1 ph.Pickslipno
                              FROM PackHeader ph WITH (NOLOCK)
                              WHERE ph.ConsoOrderKey = O.ConsoOrderKey  ),
             O.OrderKey,
             PickStatus = CASE WHEN  OD.UserDefine10 IS NULL THEN
                              ( SELECT TOP 1 ph.[Status]
                              FROM PackHeader ph WITH (NOLOCK)
                              WHERE ph.ConsoOrderKey = O.ConsoOrderKey ) ELSE 'Y' END   ,
             FluidLoad = CASE WHEN  OD.UserDefine10 IS NULL THEN 'N' ELSE 'Y' END
      FROM #Orders O
         LEFT JOIN  ORDERDETAIL OD WITH (NOLOCK)  ON OD.OrderKey = O.OrderKey AND   ISNULL(RTRIM(OD.UserDefine10),'') <> ''
      WHERE O.ConsoOrderKey <> ''

   END

   DELETE #OrderPick WHERE  ISNULL(RTRIM(Pickslipno), '') = ''
   DROP TABLE  #Orders

   -- TLTING02 END
/*
   DECLARE CUR_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT rkl.OrderKey, ph.ConsoOrderKey  -- (ChewKP02)
   FROM RefKeyLookUp rkl (NOLOCK)
   JOIN MBOLDETAIL m (NOLOCK) ON m.OrderKey = rkl.OrderKey
   JOIN PackHeader ph (NOLOCK) ON ph.PickSlipNo = rkl.Pickslipno
   WHERE m.MbolKey = @c_MBOLKey

   OPEN CUR_PickSlip

   FETCH NEXT FROM CUR_PickSlip INTO @c_OrderKey, @cConsoOrderKey  -- (ChewKP01) -- (ChewKP02)
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_PickSlipNo = ''
      SET @cFluidLoad = '' -- (ChewKP03)

      -- (ChewKP01)
      IF @cConsoOrderKey = ''  -- (ChewKP02)
      BEGIN
         SELECT TOP 1
            @c_PickSlipNo = rkl.Pickslipno,
            @c_PickStatus = ph.[Status]
         FROM RefKeyLookUp rkl (NOLOCK)
         JOIN PackHeader ph (NOLOCK) ON ph.Pickslipno = rkl.Pickslipno
         WHERE ph.OrderKey = @c_OrderKey
         ORDER BY ph.[Status] ASC
      END
      ELSE
      BEGIN

         SELECT TOP 1
            @c_PickSlipNo = ph.Pickslipno,
            @c_PickStatus = ph.[Status]
         FROM PackHeader ph WITH (NOLOCK)
         WHERE ph.ConsoOrderKey = @cConsoOrderKey

         SET @cFluidLoad = 'N'
         SET @cOriginalOrderKey = ''

         -- If Orders = Fluid Load Lane Order and this is not the last order
   --      IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey and SectionKey ='N')
   --      BEGIN
   --       SET @cFluidLoad = 'Y'
   --       SET @c_PickStatus = '9'
   --      END

--         SELECT TOP 1
--             @cOriginalOrderKey = ISNULL(OD.UserDefine10,'')
--         FROM ORDERDETAIL OD WITH (NOLOCK)
--         WHERE OD.OrderKey = @c_OrderKey
--
--         IF ISNULL(RTRIM(@cOriginalOrderKey),'') <> ''

         -- tlting02
         IF EXISTS ( SELECT 1 FROM ORDERDETAIL OD WITH (NOLOCK)
                     WHERE OD.OrderKey = @c_OrderKey
                     AND   ISNULL(OD.UserDefine10,'') <> ''  )
         BEGIN
           SET @cFluidLoad = 'Y'
           SET @c_PickStatus = '9'
         END
      END

      IF ISNULL(RTRIM(@c_PickSlipNo),'') <> ''
      BEGIN
         INSERT INTO #OrderPick (PickSlipNo, OrderKey, Status, FluidLoad)    -- (ChewKP03)
         VALUES (@c_PickSlipNo, @c_OrderKey, @c_PickStatus, ISNULL(@cFluidLoad,'N'))    -- (CheWKP03)
      END
      FETCH NEXT FROM CUR_PickSlip INTO @c_OrderKey, @cConsoOrderKey   -- (ChewKP01) -- (ChewKP02)
   END
   CLOSE CUR_PickSlip
   DEALLOCATE CUR_PickSlip
   -- End
  */
   SET @d_step1 = GETDATE() - @d_step1 -- (tlting01)
   SET @d_step2 = GETDATE()  -- (tlting01)

   INSERT INTO #MBOLCheck
   SELECT DISTINCT ORDERS.StorerKey,
          ORDERDETAIL.OrderKey,
          ORDERDETAIL.OrderLineNumber,
          ORDERS.Type,
          ORDERDETAIL.QtyAllocated,
          ORDERDETAIL.QtyPicked,
          ORDERDETAIL.LoadKey,
          ORDERS.Facility,
          ORDERS.UserDefine08,
          ORDERDETAIL.Status,
          ORDERDETAIL.OriginalQty,
          ORDERDETAIL.ShippedQty,
          PickSlipNo = CASE WHEN OrderPick.PickSlipNo IS NULL THEN ISNULL(ConsoPick.PickSlipNo, '')
               Else ISNULL(OrderPick.PickSlipNo, '') END,
          PickSlipStatus = CASE WHEN OrderPick.PickSlipNo IS NULL THEN ISNULL(ConsoPick.Status, '')
               Else ISNULL(OrderPick.Status, '') END
   FROM MBOLDETAIL WITH (NOLOCK)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey AND MBOLDETAIL.MBOLKey = OrderDetail.MBOLKey
            AND MBOLDETAIL.Loadkey = ORDERDETAIL.Loadkey) -- SOS39592
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = OrderDetail.OrderKey)
   LEFT OUTER JOIN #OrderPick OrderPick ON (OrderPick.OrderKey = ORDERS.OrderKey)
   LEFT OUTER JOIN #ConsoPick ConsoPick ON (ConsoPick.LoadKey = ORDERDETAIL.LoadKey)
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey

   DECLARE @cOrderKey   NVARCHAR(10)
         , @cPickSlipNo NVARCHAR(10)

   -- (ChewKP03)
   SET @cFluidLoadEXPickAPackMatchCheck = '0'
   SELECT TOP 1
         @cFluidLoadEXPickAPackMatchCheck =
         CASE
            WHEN RTRIM(StorerConfig.sValue) = '1' THEN '1'
             ELSE '0'
         END
   FROM dbo.StorerConfig WITH (NOLOCK)
   JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
   WHERE ConfigKey = 'FluidLoadEXPickAPackMatchCheck'

   IF @cFluidLoadEXPickAPackMatchCheck = '1'
   BEGIN
      IF EXISTS(SELECT 1 FROM RDT.rdtScanToTruck rstt WITH (NOLOCK)
               WHERE rstt.MBOLKey = @c_MBOLKey)
      BEGIN
         --(Wan01) - START
         TRUNCATE TABLE #ErrorLogDetail

         INSERT INTO #ErrorLogDetail (Key1, LineText)
         SELECT DISTINCT rstt.MBOLKey
              , CONVERT(NCHAR(10), rstt.MBOLKey) + ' '
              + CONVERT(NCHAR(40), rstt.RefNo) + ' '
              + CONVERT(NCHAR(40), rstt.URNNo) + ' '
              + CONVERT(NCHAR(10), rstt.Status)
         FROM RDT.rdtScanToTruck rstt WITH (NOLOCK)
         WHERE rstt.MBOLKey = @c_MBOLKey
         AND   rstt.Status < '9'

         --IF EXISTS(SELECT 1 FROM RDT.rdtScanToTruck rstt WITH (NOLOCK)
         --       WHERE rstt.MBOLKey = @c_MBOLKey
         --       AND rstt.Status < '9') --(ung01)
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
         --(Wan01) - END
         BEGIN
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73001
            SELECT @c_errmsg='Scan To Truck in Progress.'

            --(Wan01) - START
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                   'Scan To Truck in Progress.')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'MBOLKey') + ' '
                                       + CONVERT(NCHAR(40), 'Start CartonNo') + ' '
                                       + CONVERT(NCHAR(40), 'End CartonNo') + ' '
                                       + CONVERT(NCHAR(10), 'Status')
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         REPLICATE('-', 10) + ' '
                                       + CONVERT(NCHAR(40), REPLICATE('-', 40)) + ' '
     + CONVERT(NCHAR(40), REPLICATE('-', 40)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10))
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
            FROM #ErrorLogDetail
            --(Wan01) - END
         END
      END
      ELSE
      BEGIN
         SET @cFluidLoadEXPickAPackMatchCheck = '0'
      END
   END

   --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SET @cPickSlipNo = '' -- SOS#209421
      SET @cOrderKey = ''   -- SOS#209421

      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, Key2, LineText)
      SELECT DISTINCT PickSlipNo
            ,Orderkey
            ,CONVERT(NCHAR(10),PickSlipNo)      + ' '
            +CONVERT(NCHAR(10),OrderKey)        + ' '
            +CONVERT(NCHAR( 5),OrderLineNumber) + ' '
            +CONVERT(NCHAR( 6),[Status])        + ' '
            +CONVERT(NCHAR(10),QtyAllocated)    + ' '
            +CONVERT(NCHAR(10),QtyPicked)
      FROM   #MBOLCheck
      WHERE Type NOT IN ('I', 'M')
      AND UserDefine08 <> '2'
      AND STATUS IN ('0', '1','2','3','4')
      AND ( QtyPicked + QtyAllocated ) > 0

      --SELECT @cPickSlipNo = PickSlipNo,
      --       @cOrderKey   = OrderKey
      --FROM   #MBOLCheck
      --WHERE Type NOT IN ('I', 'M')
      --AND UserDefine08 <> '2'
      --AND STATUS IN ('0', '1','2','3','4')
      --AND ( QtyPicked + QtyAllocated ) > 0

      --IF ISNULL(RTRIM(@cPickSlipNo),'') <> '' OR ISNULL(RTRIM(@cOrderKey),'') <> ''
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         --(Wan01) - START
         SELECT TOP 1 @cPickSlipNo = Key1
                     ,@cOrderKey   = Key2
         FROM #ErrorLogDetail
         --(Wan01) - END

         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 3
         SELECT @n_err=73002

         IF ISNULL(RTRIM(@cPickSlipNo),'') <> ''
         BEGIN
            SELECT @c_errmsg='Pick Confirmed not done yet. Pickslip No is ' + @cPickSlipNo + ', Hints: OrderDetail.Status < 5'
         END
         ELSE
         BEGIN
            SELECT @c_errmsg='Pick Confirmed not done yet. Order# ' + @cOrderKey + ', Hints: OrderDetail.Status < 5'
         END

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                @c_errmsg)
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                       + CONVERT(NCHAR(10), 'OrderKey')   + ' '
      + CONVERT(NCHAR(5),  'Line')       + ' '
                                       + CONVERT(NCHAR(6),  'Status')     + ' '
                                       + CONVERT(NCHAR(10), 'Qty Alloc')  + ' '
                                       + CONVERT(NCHAR(10), 'Qty Picked') + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(5),  REPLICATE('-',  5)) + ' '
                                       + CONVERT(NCHAR(6),  REPLICATE('-',  6)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END
   END

   --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      --(Wan01) - START
      -- (Vicky02) - Start
      --SELECT @cCheckShortPick = CASE WHEN RTRIM(StorerConfig.sValue) = '1' THEN '1' ELSE '0' END
      --FROM dbo.StorerConfig WITH (NOLOCK)
      --JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      --WHERE ConfigKey = 'CheckShortPickUponShip'

      --IF @cCheckShortPick = '1'
      --BEGIN

         TRUNCATE TABLE #ErrorLogDetail

         INSERT INTO #ErrorLogDetail (Key1, LineText)
         SELECT DISTINCT PD.Orderkey
               ,CONVERT(NCHAR(10),PD.PickDetailKey)   + ' '
               +CONVERT(NCHAR(10),PD.OrderKey)        + ' '
               +CONVERT(NCHAR( 5),PD.OrderLineNumber) + ' '
               +CONVERT(NCHAR( 6),PD.[Status])        + ' '
               +CONVERT(NCHAR(10),PD.Qty)             + ' '
         FROM PickDetail PD WITH (NOLOCK)
         JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON (PD.Orderkey = ORDET.Orderkey AND PD.OrderLineNumber = ORDET.OrderLineNumber)
         JOIN ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = ORDET.Orderkey)
         JOIN STORERCONFIG SC WITH (NOLOCK) ON (ORD.Storerkey = SC.Storerkey AND SC.ConfigKey = N'CheckShortPickUponShip' AND SC.SValue = '1')
         JOIN MBOLDETAIL MBOLDET WITH (NOLOCK) ON (MBOLDET.Orderkey = ORD.Orderkey)
         WHERE MBOLDET.MBOLKEY = @c_MBOLKey
         AND   PD.Status < '5'
         AND   PD.QTY > 0

         --IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)
         --         JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON (PD.Orderkey = ORDET.Orderkey AND PD.OrderLineNumber = ORDET.OrderLineNumber)
         --         JOIN ORDERS ORD WITH (NOLOCK) ON (ORD.Orderkey = ORDET.Orderkey)
         --         JOIN MBOLDETAIL MBOLDET WITH (NOLOCK) ON (MBOLDET.Orderkey = ORD.Orderkey)
         --         WHERE MBOLDET.MBOLKEY = @c_MBOLKey
         --         AND   PD.Status < '5'
         --         AND   PD.QTY > 0)
         --(Wan01) - END
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
         BEGIN
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73003
            SELECT @c_errmsg='Some Orders are not fully Picked for MBOL#' + ISNULL(RTRIM(@c_MBOLKey),'') + ' Not Allowed to Ship.'

            --(Wan01) - START
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                   'Some Orders are not fully Picked for MBOL.')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'PickDetKey')  + ' '
                                       + CONVERT(NCHAR(10), 'OrderKey')   + ' '
                                      + CONVERT(NCHAR(5),  'Line')       + ' '
                                       + CONVERT(NCHAR(6),  'Status')     + ' '
                                       + CONVERT(NCHAR(10), 'Qty')        + ' '
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(5),  REPLICATE('-',  5))   + ' '
                                       + CONVERT(NCHAR(6),  REPLICATE('-',  6)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
            FROM #ErrorLogDetail
            --(Wan01) - END
        END
      --END --(Wan01)
      -- (Vicky02) - End
      -- (Vicky01) - Start
      SET @c_CheckAllToteScan_Opt5 = '' --NJOW08
      SELECT @cCheckAllToteScan = CASE WHEN RTRIM(StorerConfig.sValue) IN ('1','2') THEN RTRIM(StorerConfig.sValue) ELSE '0' END --NJOW05
            ,@c_CheckAllToteScan_Opt5 = Storerconfig.Option5 --NJOW08
      FROM dbo.StorerConfig WITH (NOLOCK)
      JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      WHERE ConfigKey = N'CheckAllToteScan'

      IF @cCheckAllToteScan IN ('1','2') --NJOW05
      BEGIN
   --      Comment by james because all the label will be stamped in packinfo.refno as well
   --      So only have to count the packinfo.refno

         SELECT @c_ExcludeOrderGroupShort = dbo.fnc_GetParamValueFromString('@c_ExcludeOrderGroupShort', @c_CheckAllToteScan_Opt5, @c_ExcludeOrderGroupShort)  --NJOW08

         IF ISNULL(@c_ExcludeOrderGroupShort,'') = '' OR
            NOT EXISTS(SELECT TOP 1 1 FROM MBOLDETAIL MD (NOLOCK)
                       JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
                       JOIN CODELKUP CL (NOLOCK) ON O.OrderGroup = CL.Code AND CL.ListName = 'ORDERGROUP'
                       WHERE MD.Mbolkey = @c_Mbolkey
                       AND CL.Short IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ExcludeOrderGroupShort))) --NJOW08
         BEGIN
            IF @cCheckAllToteScan = '1'  --NJOW05
            BEGIN
               IF EXISTS(SELECT 1 FROM MbolDetail MD WITH (NOLOCK)
                  JOIN Orders O WITH (NOLOCK) ON MD.OrderKey = O.OrderKey
                  WHERE MD.MBOLKEY = @c_MBOLKey
                     AND O.Userdefine01 = '')
               BEGIN
                  -- Store Orders
                  --(Wan01) - START
--                  SET @nTotalPackTote = 0 -- SOS#209421
--                  SELECT @nTotalPackTote = COUNT(DISTINCT PD.DropID) -- (Vicky03)
--                  FROM dbo.PackDetail PD WITH (NOLOCK)
--                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
--                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
--                  WHERE MD.MbolKey = @c_MBOLKey
                  TRUNCATE TABLE #ErrorLogDetail

                  INSERT INTO #ErrorLogDetail (Key1, LineText)
                  SELECT DISTINCT PD.DropID
                        ,CONVERT(NCHAR(10),MD.Orderkey) + ' '
                        +CONVERT(NCHAR(10),PH.PickSlipNo) + ' '
                        +CONVERT(NCHAR(20),PD.DropID)
                  FROM dbo.PackDetail PD WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
                  WHERE MD.MbolKey = @c_MBOLKey
                  AND NOT EXISTS (SELECT 1
                                  FROM rdt.rdtScanToTruck STT WITH (NOLOCK)
                                  WHERE STT.MBOLKey = MD.MbolKey
                                  AND ISNULL(RTRIM(STT.RefNo),'') = ISNULL(RTRIM(PD.DropID),'')) -- INC1363640
                  --(Wan01) - END
               END
               ELSE
               BEGIN
                  -- ECOMM Orders
                  --(Wan01) - START
--                  SET @nTotalPackTote = 0 -- SOS#209421
--                  SELECT @nTotalPackTote = COUNT(DISTINCT PIF.RefNo) -- (Vicky03)
--                  FROM dbo.PackInfo PIF WITH (NOLOCK)
--                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PIF.PickSlipNo)
--                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
--                  WHERE MD.MbolKey = @c_MBOLKey
                  TRUNCATE TABLE #ErrorLogDetail

                  INSERT INTO #ErrorLogDetail (Key1, LineText)
                  SELECT DISTINCT PIF.RefNo
                        ,CONVERT(NCHAR(10),MD.Orderkey) + ' '
                        +CONVERT(NCHAR(10),PH.PickSlipNo) + ' '
                        +CONVERT(NCHAR(20),PIF.RefNo)
                  FROM dbo.PackInfo PIF WITH (NOLOCK)
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PIF.PickSlipNo)
                  JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
                  WHERE MD.MbolKey = @c_MBOLKey
                  AND NOT EXISTS (SELECT 1
                                  FROM rdt.rdtScanToTruck STT WITH (NOLOCK)
                                  WHERE STT.MBOLKey = MD.MbolKey
                                  AND ISNULL(RTRIM(STT.RefNo),'') = ISNULL(RTRIM(PIF.RefNo),'')) -- INC1363640
                  --(Wan01) - END
               END
            END
            ELSE
            BEGIN  --@cCheckAllToteScan = '2'
                 --NJOW05
               TRUNCATE TABLE #ErrorLogDetail

               INSERT INTO #ErrorLogDetail (Key1, LineText)
               SELECT DISTINCT PD.LabelNo
                     ,CONVERT(NCHAR(10),MD.Orderkey) + ' '
                     +CONVERT(NCHAR(10),PH.PickSlipNo) + ' '
                     +CONVERT(NCHAR(20),PD.LabelNo)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON (MD.Orderkey = PH.Orderkey)
               WHERE MD.MbolKey = @c_MBOLKey
               AND NOT EXISTS (SELECT 1
                               FROM rdt.rdtScanToTruck STT WITH (NOLOCK)
                               WHERE STT.MbolKey = MD.MbolKey
                               AND ISNULL(RTRIM(STT.URNNo),'') = ISNULL(RTRIM(PD.LabelNo),'')) -- INC1363640
            END
         END

         --(Wan01) - START
         --SET @nTotalScanTote = 0 -- SOS#209421
         --SELECT @nTotalScanTote = COUNT(DISTINCT RefNo)
         --FROM rdt.rdtScanToTruck WITH (NOLOCK)
         --WHERE Mbolkey = @c_MBOLKey


         --IF ISNULL(@nTotalPackTote, 0) > ISNULL(@nTotalScanTote, 0)
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
         --(Wan01) - END
         BEGIN

            -- Check if DPD Dummy report type setup. If setup then skip checking on no of tote scanned
            -- because DPD Dummy do not have any barcode to scan. (james02)
            IF NOT EXISTS (SELECT 1 FROM RDT.RDTReport RPT WITH (NOLOCK)
               JOIN #MBOLCheck M ON (M.StorerKey = RPT.StorerKey)
               WHERE RPT.ReportType = N'DPDLABEL')
            BEGIN

               SELECT @b_ReturnCode = -1
               SELECT @n_Continue = 4
               SELECT @n_err=73004
               SELECT @c_errmsg='Not All Totes Are Scanned for MBOL#' + ISNULL(RTRIM(@c_MBOLKey),'') + ' Not Allowed to Ship.'

               --(Wan01) - START
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                      '-----------------------------------------------------')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                      'Not All Totes Are Scanned.')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                      '-----------------------------------------------------')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), 'OrderKey') + ' '
                                          + CONVERT(NCHAR(10), 'PickSlip#') + ' '
                                          + CONVERT(NCHAR(20), 'Tote#')
                                            )
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                          + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                          + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                            )

               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
               SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
               FROM #ErrorLogDetail
               --(Wan01) - END
            END
         END
      END
      -- (Vicky01) - End
   END

   --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- SOS#141354
      DECLARE @cPackBeforeShipOption NVARCHAR(10)

   --   IF @cFluidLoadEXPickAPackMatchCheck = '1'
   --      GOTO SKIP_PACKHEADER_STATUS_CHECK

      SET @cPackBeforeShipOption = '0'
      SET @cOrderKey = '' -- SOS#209421
      --(Wan01) - START
      --SET ROWCOUNT 1
      --SELECT @cOrderKey = ORDERKEY,
      --       @cPackBeforeShipOption = StorerConfig.sValue
      --FROM StorerConfig WITH (NOLOCK)
      --JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      --WHERE ConfigKey = 'PackBeforeShip'
      --AND   PickSlipStatus Between '0' and '8'
      --AND   sValue IN ('1' ,'2')

      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, Key2, LineText)
      SELECT DISTINCT M.Orderkey, SC.sValue
            ,CONVERT(NCHAR(10),M.PickSlipNo)       + ' '
            +CONVERT(NCHAR(10),M.OrderKey)         + ' '
            +CONVERT(NCHAR( 6),M.[PickSlipStatus]) + ' '
      FROM StorerConfig SC WITH (NOLOCK)
      JOIN #MBOLCheck M ON (M.StorerKey = SC.StorerKey)
      WHERE SC.ConfigKey = N'PackBeforeShip'
      AND   M.PickSlipStatus Between '0' and '8'
      AND   SC.sValue IN ('1' ,'2')
      AND (ISNULL(SC.OPTION1,'') = '' OR M.[Type] NOT IN (SELECT COLVALUE FROM dbo.fnc_DelimSplit(',',SC.OPTION1) ) ) --IF OPTION1 is blank, include all type (WL01)
      --(Wan01) - END

      --(Wan01) - START
      --IF ISNULL(RTRIM(@cOrderKey),'') <> ''
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         --(Wan01) - START
         SELECT TOP 1 @cOrderKey = Key1
                     ,@cPackBeforeShipOption = Key2
         FROM #ErrorLogDetail
         --(Wan01) - END
         IF @cPackBeforeShipOption = '1'
         BEGIN
            SELECT @b_ReturnCode = 1
            SELECT @n_Continue = 4
            SELECT @n_err=73005
            SELECT @c_errmsg='Order# ' + ISNULL(RTRIM(@cOrderKey),'') + ', is Pack in Progress. You should Confirmed Pack Before Ship this MBOL.'
         END
         ELSE IF @cPackBeforeShipOption = '2'
         BEGIN
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73006
            SELECT @c_errmsg='Packing not Complete! Order# ' + ISNULL(RTRIM(@cOrderKey),'') + ' Not Allowed to Ship.'
         END

         --(Wan01) - START
         IF @b_ReturnCode = 1 SET @c_Type = 'WARNING' ELSE SET @c_Type = 'ERROR'

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type + 'MSG',
                                                                                @c_errmsg)
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                      CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                    + CONVERT(NCHAR(10), 'OrderKey')   + ' '
                                    + CONVERT(NCHAR(6),  'Status')     + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(6),  REPLICATE('-',  6)) + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type, LineText
         FROM #ErrorLogDetail
         --(Wan01) - END

      END
   SKIP_PACKHEADER_STATUS_CHECK:

      --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         DECLARE @cPickSlipStatus NVARCHAR(10)

         -- SELECT  PickSlipStatus,
         --         ORDERKEY
         -- FROM StorerConfig (NOLOCK)
         -- JOIN #MBOLCheck M On (M.StorerKey = StorerConfig.StorerKey)
         -- WHERE ConfigKey = 'PackBeforeShip'
         -- AND   sValue = '1'

         SET @cPickSlipStatus = ''
         SET @cPackBeforeShipOption = '0'
         SET @cOrderKey = '' -- SOS#209421

         --(Wan01) - START
         --SET ROWCOUNT 1

         --SELECT @cPickSlipStatus = PickSlipStatus,
         --       @cOrderKey = ORDERKEY,
         --       @cPackBeforeShipOption = StorerConfig.sValue
         --FROM StorerConfig WITH (NOLOCK)
         --JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
         --LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (M.TYPE = CL.Code AND CL.LISTNAME = 'ExPKB4SHP' AND CL.Short = 'ORDERS')  --NJOW03
         --WHERE ConfigKey = 'PackBeforeShip'
         --AND   sValue IN ('1' ,'2')
         --AND   (PickSlipStatus = '' OR PickSlipStatus IS NULL)
         --AND CL.Code IS NULL --NJOW03

         TRUNCATE TABLE #ErrorLogDetail

         INSERT INTO #ErrorLogDetail (Key1, Key2, LineText)
         SELECT DISTINCT M.Orderkey, SC.sValue
               ,CONVERT(NCHAR(10), ISNULL(RTRIM(PD.PickDetailKey), SPACE(10)))           + ' ' -- SOS# 320856
               +CONVERT(NCHAR(10), ISNULL(RTRIM(PD.OrderKey), M.Orderkey))               + ' ' -- SOS# 320856
               +CONVERT(NCHAR( 5), ISNULL(RTRIM(PD.OrderLineNumber), M.OrderLineNumber)) + ' ' -- SOS# 320856
               +CONVERT(NCHAR( 6), ISNULL(RTRIM(PD.[Status]), M.[Status]))               + ' ' -- SOS# 320856
         FROM StorerConfig SC WITH (NOLOCK)
         JOIN #MBOLCheck M                ON (M.StorerKey = SC.StorerKey)
         LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (M.Orderkey = PD.Orderkey) -- SOS# 320856
         LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (M.TYPE = CL.Code AND CL.LISTNAME = N'ExPKB4SHP' AND CL.Short = 'ORDERS')
         WHERE SC.ConfigKey = N'PackBeforeShip'
         AND   SC.sValue IN ('1' ,'2')
         AND  (M.PickSlipStatus = '' OR M.PickSlipStatus IS NULL)
         AND   CL.Code IS NULL
         AND (ISNULL(SC.OPTION1,'') = '' OR M.[Type] NOT IN (SELECT COLVALUE FROM dbo.fnc_DelimSplit(',',SC.OPTION1) ) ) --IF OPTION1 is blank, include all type (WL01)


         --IF @@ROWCOUNT > 0 AND ISNULL(RTRIM(@cPickSlipStatus),'') = ''
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
         --(Wan01) - END
         BEGIN
            --(Wan01) - START
            SELECT TOP 1 @cOrderKey = Key1
                        ,@cPackBeforeShipOption = Key2
            FROM #ErrorLogDetail
            --(Wan01) - END
            IF @cPackBeforeShipOption = '1'
            BEGIN
               SELECT @b_ReturnCode = 1
               SELECT @n_Continue = 4
               SELECT @n_err=73007
               SELECT @c_errmsg='Cannot find any Packing information for Order# ' + RTRIM(@cOrderKey) +
                                '. Packing not done yet. Do you still want to ship?'
            END
            ELSE IF @cPackBeforeShipOption = '2'
            BEGIN
               SELECT @b_ReturnCode = -1
               SELECT @n_Continue = 4
               SELECT @n_err=73008
               SELECT @c_errmsg='Packing not started yet! Order# ' + ISNULL(RTRIM(@cOrderKey),'') + ' Not Allowed to Ship.'
            END

            --(Wan01) - START
            IF @b_ReturnCode = 1 SET @c_Type = 'WARNING' ELSE SET @c_Type = 'ERROR'

            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type + 'MSG',
                                                                                   @c_errmsg)
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                         CONVERT(NCHAR(10), 'PickDetKey')  + ' '
                                       + CONVERT(NCHAR(10), 'OrderKey')   + ' '
                                       + CONVERT(NCHAR(5),  'Line')       + ' '
                                       + CONVERT(NCHAR(6),  'Status')     + ' '
                                       + CONVERT(NCHAR(10), 'Qty')        + ' '
   )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type,
                                         CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(5),  REPLICATE('-',  5)) + ' '
                                       + CONVERT(NCHAR(6),  REPLICATE('-',  6)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type, LineText
            FROM #ErrorLogDetail
            --(Wan01) - END
         END
      END
   END

   --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT M.Orderkey
            ,CONVERT(NCHAR(10),M.Orderkey)         + ' '
            +CONVERT(NCHAR(15),ISNULL(SUM(M.OriginalQty),0)) + ' '
            +CONVERT(NCHAR(18),ISNULL(SUM(M.QtyPicked + M.QtyAllocated),0)) + ' '
      FROM StorerConfig SC WITH (NOLOCK)
      JOIN #MBOLCheck M ON (M.StorerKey = SC.StorerKey)
      WHERE SC.ConfigKey = N'OWNoPartialMBOL'
      AND   SC.sValue = '1'
      AND   M.ShippedQty = 0
      GROUP BY M.Orderkey
      HAVING SUM(M.OriginalQty) <> SUM(M.QtyPicked + M.QtyAllocated)

      --IF EXISTS(SELECT ORDERKEY
      --     FROM StorerConfig WITH (NOLOCK)
      --          JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      --          WHERE ConfigKey = 'OWNoPartialMBOL'
      --          AND   ShippedQty = 0
      --          AND   sValue = '1'
      --          GROUP BY ORDERKEY
      --          HAVING SUM(OriginalQty) <> SUM(QtyPicked + QtyAllocated))
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         SELECT @b_ReturnCode = 1
         SELECT @n_Continue = 4
         SELECT @n_err=73009
         SELECT @c_errmsg='You have partially allocated orders. Do you still want to ship?'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNING',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNINGMSG',
                                                                                @c_errmsg)
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNING',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNING',
                                      CONVERT(NCHAR(10), 'Orderkey')    + ' '
                                     +CONVERT(NCHAR(15), 'Original Qty')+ ' '
                                     +CONVERT(NCHAR(18), 'QtyAlloc+QtyPicked')+ ' '
                                     )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNING',
    CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                     +CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                     +CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                     )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'WARNING', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END
   END

   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT M.Loadkey
            ,CONVERT(NCHAR(10),M.Loadkey)
      FROM #MBOLCheck M WITH (NOLOCK)
      JOIN Loadplan LP  WITH (NOLOCK) on M.LoadKey = LP.LoadKey and LP.finalizeflag = 'N'
      JOIN StorerConfig SC  WITH (NOLOCK) on M.StorerKey = SC.StorerKey and SC.configkey = N'OWITF' AND SC.sValue = '1'
      JOIN StorerConfig SC1 WITH (NOLOCK) on M.StorerKey = SC1.StorerKey and SC1.Configkey = N'FinalizeLP' AND SC1.sValue = '1'

      --IF EXISTS ( SELECT 1
      --            FROM #MBOLCheck M WITH (NOLOCK)
      --   JOIN Loadplan LP WITH (NOLOCK) on M.LoadKey = LP.LoadKey and LP.finalizeflag = 'N'
      --            JOIN StorerConfig SC WITH (NOLOCK) on M.StorerKey = SC.StorerKey and SC.configkey = 'OWITF' AND SC.sValue = '1'
      --            JOIN StorerConfig SC1 WITH (NOLOCK) on M.StorerKey = SC1.StorerKey and SC1.Configkey = 'FinalizeLP' AND SC1.sValue = '1')
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         SELECT @b_ReturnCode = -1
     SELECT @n_Continue = 4
         SELECT @n_err=73010
         SELECT @c_errmsg='Cannot Ship MBOL. LoadPlan Not Finalized.'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                @c_errmsg)
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'LoadKey')  + ' '
                                     )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                     )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), @c_Type, LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END
   END -- @n_continue = 1 OR @n_continue = 2

-- Start : SOS65533
-- 25-Mar-2011  SHONG     1.12
-- 1. Must Print Label (labelno=20)
-- 2. Must with Tracking# (UPS / Fedex)
-- 3. When to Packconfirm?
-- 4. Mboldetail.ttlcnt <= if NON-POCC should be update accordingly.  if POCC, need to get equation from Peggy
   DECLARE @cPickSlipWithoutLabel NVARCHAR(10)
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @cPickSlipWithoutLabel = ''

      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT OP.PickSlipNo
            ,CONVERT(NCHAR(10),OP.PickSlipNo)
      FROM #OrderPick OP
      JOIN ORDERS       OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
      JOIN PackDetail   PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo
      JOIN StorerConfig SC WITH (NOLOCK) ON SC.StorerKey = OH.StorerKey
                                         AND SC.ConfigKey = N'SSCCLabelRequired'
                                         AND SC.SValue = '1'
      WHERE LEN(PD.LabelNo) <> 20
      AND   ISNUMERIC(PD.LabelNo) <> 1
      AND   PD.Qty > 0

      --SELECT TOP 1
      --      @cPickSlipWithoutLabel = OP.PickSlipNo
      --FROM #OrderPick OP
      --JOIN ORDERS OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
      --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo
      --JOIN StorerConfig SC WITH (NOLOCK) ON SC.StorerKey = OH.StorerKey
      --                    AND SC.ConfigKey = 'SSCCLabelRequired' AND SC.SValue = '1'
      --WHERE LEN(PD.LabelNo) <> 20
      --AND   ISNUMERIC(PD.LabelNo) <> 1
      --AND   PD.Qty > 0

      --IF ISNULL(RTRIM(@cPickSlipWithoutLabel),'') <> ''
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         SELECT TOP 1 @cPickSlipWithoutLabel = Key1
         FROM #ErrorLogDetail

         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 4
         SELECT @n_err=73011
         SELECT @c_errmsg='NOT ALL GS1 LABEL PRINTED, Pick Slip: ' + @cPickSlipWithoutLabel

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'NOT ALL GS1 LABEL PRINTED.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Pickslip#')  + ' ' )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' ' )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END
   END

   DECLARE @cCheckCarrierRequirement NVARCHAR(1)
          ,@cCarrierKey              NVARCHAR(20)
          ,@cPickSlipWithoutTrackNo  NVARCHAR(10)
          ,@cLabelNo                 NVARCHAR(20)

   SET @cCheckCarrierRequirement = '0'
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, Key2, Key3, LineText)
      SELECT DISTINCT M.Orderkey
           , ISNULL(RTRIM(O.SpecialHandling),'')
           , CASE WHEN ISNULL(RTRIM(O.M_Fax1),'') = '' OR ISNULL(RTRIM(O.M_Phone2),'') = '' THEN '' ELSE 'ACNO' END
           , CONVERT(NCHAR(10), M.Orderkey) + ' '
           + CONVERT(NCHAR(10), O.SpecialHandling) + ' '
           + CONVERT(NCHAR(18), O.M_Fax1)   + ' '
           + CONVERT(NCHAR(18), O.M_Phone2) + ' '
      FROM #MBOLCheck M
      JOIN ORDERS O WITH (NOLOCK) ON (M.Orderkey = O.Orderkey)
      JOIN MBOL MB WITH (NOLOCK) ON (O.MBOLKey = MB.MBOLKey)
      JOIN STORERCONFIG SC WITH (NOLOCK) ON (M.StorerKey = SC.StorerKey)
      WHERE SC.ConfigKey = N'CheckCarrierRequirement'
      AND   SC.SVAlue = '1'
      AND   MB.CarrierKey IN ('UPSN','FDEG')

      --SELECT TOP 1
      --   @cCheckCarrierRequirement = CASE WHEN RTRIM(StorerConfig.sValue) = '1' THEN '1' ELSE '0' END
      --FROM dbo.StorerConfig WITH (NOLOCK)
      --JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      --WHERE ConfigKey = 'CheckCarrierRequirement'

      --SET @cCarrierKey = ''
      --SELECT @cCarrierKey = MBOL.CarrierKey
      --FROM MBOL WITH (NOLOCK)
      --WHERE MbolKey = @c_MBOLKey

      --IF @cCheckCarrierRequirement = '1' AND @cCarrierKey IN ('UPSN','FDEG')
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN

         --(Wan01) - START
         --IF EXISTS(SELECT 1 FROM #MBOLCheck MC
         --          JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = MC.OrderKey
         --          WHERE (O.SpecialHandling NOT IN ('X','U','D')))
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail
                    WHERE Key2 NOT IN ('X','U','D'))
         --(Wan01) - END
         BEGIN
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73012
            SELECT @c_errmsg='Found Non UPS/FedEx Orders In this MBOL.'

            --(Wan01) - START
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                   @c_errmsg)
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'Orderkey')     + ' '
                                       + CONVERT(NCHAR(10), 'Carrier')      + ' '
                                       + CONVERT(NCHAR(18), 'Sender ACC#')  + ' '
                                       + CONVERT(NCHAR(18), 'Service Type') + ' '
                                        )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                       + CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                        )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
            FROM #ErrorLogDetail
            WHERE Key2 NOT IN ('X','U','D')
            --(Wan01) - END
         END
         --(Wan01) - START
         --IF EXISTS(SELECT 1 FROM #MBOLCheck MC
         --          JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = MC.OrderKey
         --          WHERE (O.M_Fax1 = '' OR O.M_Fax1 IS NULL)
         --          OR    (O.M_Phone2 = '' OR O.M_Phone2 IS NULL))
         IF EXISTS (SELECT 1 FROM #ErrorLogDetail WHERE Key3 = '')
         --(Wan01) - END
         BEGIN
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73013
            SELECT @c_errmsg='Cannot Ship Via UPS/FedEx With Blank AccountNo (M_FAX1, M_Phone2).'

            --(Wan01) - START
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                               '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                   @c_errmsg)
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                           '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'Orderkey')     + ' '
                                       + CONVERT(NCHAR(10), 'Carrier')      + ' '
                                       + CONVERT(NCHAR(18), 'Sender ACC#')  + ' '
                                       + CONVERT(NCHAR(18), 'Service Type') + ' '
                                        )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                       + CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                       + CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                        )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT DISTINCT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
            FROM #ErrorLogDetail
            WHERE Key3 = ''
            --(Wan01) - END
         END
         --(Wan05) IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SET @cPickSlipWithoutTrackNo = ''
            --(Wan01) - START
            TRUNCATE TABLE #ErrorLogDetail

            INSERT INTO #ErrorLogDetail (Key1, LineText)
            SELECT DISTINCT OP.PickSlipNo
                  ,CONVERT(NCHAR(10),PD.PickSlipNo) + ' '
                  +CONVERT(NCHAR(20),PD.LabelNo)    + ' '
                  +CONVERT(NCHAR(10),ISNULL(PIF.Weight,0)) + ' '
                  +CONVERT(NCHAR(20),ISNULL(PD.UPC,''))    + ' '
                  +CONVERT(NCHAR(20),ISNULL(OH.UserDefine02,'')) + ' '
            FROM #OrderPick OP
            JOIN ORDERS OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKEy = OH.ORDERKEY
            --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo AND Qty > 0     -- (ChewKP06)
            JOIN PICKDETAIL PickD WITH (NOLOCK) ON PickD.OrderKey = OH.OrderKey -- (ChewKP06)
            JOIN PackDetail PD WITH (NOLOCK) ON PD.DropID = PickD.DropID AND PD.PickSlipNo = PickD.PickSlipNo AND PD.Qty > 0 -- (ChewKP07)
            LEFT OUTER JOIN OrderInfo OI WITH (NOLOCK) ON  OI.OrderKey = OH.OrderKey
            LEFT OUTER JOIN PackInfo PIF WITH (NOLOCK) ON  PIF.PickSlipNo = PD.PickSlipNo
                                                       AND PIF.CartonNo = PD.CartonNo
            WHERE ((PD.UPC IS NULL OR PD.UPC = '') OR (PIF.[Weight] = 0 OR PIF.[Weight] IS NULL))
            --AND   (OI.OrderInfo07 = '' OR OI.OrderInfo07 IS NULL OR OI.OrderInfo07 = 'USA')   -- (ChewKP09)
            --AND    OD.UserDefine10 <> '' -- (ChewKP07)


            --SELECT TOP 1
            --      @cPickSlipWithoutTrackNo = OP.PickSlipNo
            --FROM #OrderPick OP
            --JOIN ORDERS OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
            --JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKEy = OH.ORDERKEY -- (ChewKP05)
            --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo AND Qty > 0
            --LEFT OUTER JOIN OrderInfo OI WITH (NOLOCK) ON OI.OrderKey = OH.OrderKey  -- (ChewKP04)
            --LEFT OUTER JOIN PackInfo PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo
            --                AND PIF.CartonNo = PD.CartonNo
            --WHERE ((PD.UPC IS NULL OR PD.UPC = '') OR (PIF.[Weight] = 0 OR PIF.[Weight] IS NULL))
            --AND   (OI.OrderInfo07 = '' OR OI.OrderInfo07 IS NULL OR OI.OrderInfo07 = 'USA')
            --AND OD.UserDefine10 <> '' -- (ChewKP05)
            --AND OI.OrderInfo07 = 'USA' -- (ChewKP04)

            --IF ISNULL(RTRIM(@cPickSlipWithoutTrackNo),'') <> ''
            IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
            BEGIN
               --(Wan01) - START
               SELECT TOP 1 @cPickSlipWithoutTrackNo = Key1
               FROM #ErrorLogDetail
               --(Wan01) - END
               SELECT @b_ReturnCode = -1
               SELECT @n_Continue = 4
               SELECT @n_err=73014
               SELECT @c_errmsg='Tracking Number and Weight Required for Pick Slip: ' + @cPickSlipWithoutTrackNo

               --(Wan01) - START
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                      '-----------------------------------------------------')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                      'Tracking Number and Weight Required.')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                      '-----------------------------------------------------')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                          + CONVERT(NCHAR(20), 'Label#')     + ' '
                                          + CONVERT(NCHAR(10), 'Weight')     + ' '
                                          + CONVERT(NCHAR(20), 'Tracking#')  + ' '
                                          + CONVERT(NCHAR(20), 'CarrierKey')  + ' '
                                          )
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                          + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                          + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                          + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                          + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                          )
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
               SELECT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
               FROM #ErrorLogDetail
               --(Wan01) - END
            END

            --(Wan05) IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SET @cLabelNo = ''
               SET @cPickSlipWithoutTrackNo = ''
               --(Wan01) - START
               TRUNCATE TABLE #ErrorLogDetail

               INSERT INTO #ErrorLogDetail (Key1, Key2, LineText)
               SELECT DISTINCT OP.PickSlipNo
                   ,  PD.LabelNo
                   ,  CONVERT(NCHAR(10), OP.PickSlipNo) + ' '
                   +  CONVERT(NCHAR(20), PD.LabelNo)    + ' '
            FROM #OrderPick OP
               JOIN ORDERS OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
               --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo AND Qty > 0 -- (ChewKP06)
               JOIN PICKDETAIL PickD WITH (NOLOCK) ON PickD.OrderKey = OH.OrderKey -- (ChewKP06)
               JOIN PackDetail PD WITH (NOLOCK) ON PD.DropID = PickD.DropID AND PD.PickSlipNo = PickD.PickSlipNo AND PD.Qty > 0 -- (ChewKP07)
               LEFT OUTER JOIN CartonShipmentDetail CSD WITH (NOLOCK) ON CSD.UCCLabelNo = PD.LabelNo
               WHERE OH.PmtTerm IN ('PC','PP')
               AND  (CSD.FreightCharge = 0 OR CSD.FreightCharge IS NULL)

               --SELECT TOP 1
               --      @cPickSlipWithoutTrackNo = OP.PickSlipNo,
               --      @cLabelNo = PD.LabelNo
               --FROM #OrderPick OP
               --JOIN ORDERS OH WITH (NOLOCK) ON OP.OrderKey = OH.OrderKey
               --JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = OP.PickSlipNo AND Qty > 0
   --            JOIN CartonShipmentDetail CSD WITH (NOLOCK) ON CSD.Orderkey= OP.OrderKey
   --                            AND CSD.UCCLabelNo = PD.LabelNo
               --LEFT OUTER JOIN CartonShipmentDetail CSD WITH (NOLOCK) ON CSD.UCCLabelNo = PD.LabelNo
               --WHERE OH.PmtTerm IN ('PC','PP')
               --AND  (CSD.FreightCharge = 0 OR CSD.FreightCharge IS NULL)

               --IF ISNULL(RTRIM(@cPickSlipWithoutTrackNo),'') <> ''
               IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
               BEGIN
                  --(Wan01) - START
                  SELECT TOP 1 @cPickSlipWithoutTrackNo = Key1
                              ,@cLabelNo = Key2
                  FROM #ErrorLogDetail
                  --(Wan01) - END

                  SELECT @b_ReturnCode = -1
                  SELECT @n_Continue = 4
                  SELECT @n_err=73015
     SELECT @c_errmsg='Freight Charge Required for Pick Slip: ' + @cPickSlipWithoutTrackNo + '. Label# :' + @cLabelNo

                  --(Wan01) - START
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                         '-----------------------------------------------------')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                         'Freight Charge Required.')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                         '-----------------------------------------------------')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                               CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                             + CONVERT(NCHAR(20), 'Label#')     + ' ' )
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                               CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                             + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' ' )

                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
                  SELECT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
                  FROM #ErrorLogDetail
                  --(Wan01) - END
               END
            END
         END
      END
   END

   SET @d_step2 = GETDATE() - @d_step2 -- (tlting01)
   SET @d_step3 = GETDATE()  -- (tlting01)

   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_PickOrderkey NVARCHAR(10), @c_PickSKU NVARCHAR(20)

      IF EXISTS ( SELECT DISTINCT 1
                  FROM #MBOLCheck M WITH (NOLOCK)
                  JOIN StorerConfig SC WITH (NOLOCK)
                  ON   M.StorerKey = SC.StorerKey and SC.configkey = N'CheckPickPackQtyWhenMBOL'
                       AND (SC.sValue = '1' OR SC.sValue = '2'))
      BEGIN
         SET @c_PickOrderkey = ''   -- SOS#209421
         SET @c_PickSlipNo = ''     -- SOS#209421

         DECLARE Cursor_CheckPickPackQtyWhenMBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT M.PickSlipNo, M.OrderKey
         FROM #MBOLCheck M WITH (NOLOCK)
         JOIN StorerConfig SC WITH (NOLOCK)
               ON M.StorerKey = SC.StorerKey and SC.configkey = N'CheckPickPackQtyWhenMBOL' AND
                 (SC.sValue = '1' OR SC.sValue = '2')
         GROUP BY M.OrderKey, M.PickSlipNo

         OPEN Cursor_CheckPickPackQtyWhenMBOL

         FETCH NEXT FROM Cursor_CheckPickPackQtyWhenMBOL INTO @c_PickSlipNo, @c_PickOrderkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_PickSKU = ''

            IF EXISTS(SELECT 1 FROM PICKHEADER p (NOLOCK) WHERE p.PickHeaderKey = @c_PickSlipNo
                      AND p.Zone IN ('XD','LP','LB') )
            BEGIN

               IF EXISTS ( SELECT 1 FROM #OrderPick WITH (NOLOCK)
   WHERE PickslipNo = @c_PickSlipNo
                           AND   OrderKey = @c_PickOrderkey
                           AND   FluidLoad = 'Y')
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM #TempPickTable WHERE PickSlipNo = @c_PickSlipNo)
    BEGIN
                    INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                    SELECT @c_PickSlipNo, P.SKU, ISNULL(SUM(P.Qty), 0) As PickedQty , ISNULL(PK.PackedQty, 0)  -- ZG01 
                    FROM  PickDetail P WITH (NOLOCK)
                    JOIN  MBOLDETAIL M WITH (NOLOCK) ON P.OrderKey = M.OrderKey
                    LEFT JOIN  (SELECT PD.PickSlipNo, PD.SKU, SUM(PD.QTY) AS PackedQty
                          FROM PACKDETAIL PD WITH (NOLOCK)
                          WHERE PD.PickSlipNo = @c_PickSlipNo
                          AND   EXISTS(SELECT 1 FROM PICKDETAIL p WITH (NOLOCK)
                                       JOIN  MBOLDETAIL M WITH (NOLOCK) ON P.OrderKey = M.OrderKey
                                       WHERE P.PickSlipNo = PD.PickSlipNo AND P.SKU = PD.SKU
                                       AND P.CaseID = PD.LabelNo
                                       AND P.PickSlipNo = @c_PickSlipNo
                                       AND M.MbolKey = @c_MBOLKey )
                          GROUP BY PD.PickSlipNo, PD.SKU
                          ) AS PK ON PK.PickSlipNo = @c_PickSlipNo AND PK.SKU = P.SKU
                    WHERE P.PickSlipNo = @c_PickSlipNo
                    AND   M.MbolKey = @c_MBOLKey
                    AND   P.STATUS IN ('5','6','7','8','9')
                    Group By P.SKU , PK.PackedQty
/*
                    UPDATE TP
                       SET PackQty = PK.PackedQty
       FROM #TempPickTable TP
                    JOIN (SELECT PD.PickSlipNo, PD.SKU, SUM(PD.QTY) AS PackedQty
                          FROM PACKDETAIL PD WITH (NOLOCK)
                          WHERE PD.PickSlipNo = @c_PickSlipNo
                          AND   EXISTS(SELECT 1 FROM PICKDETAIL p WITH (NOLOCK)
                                       JOIN  MBOLDETAIL M WITH (NOLOCK) ON P.OrderKey = M.OrderKey
                                       WHERE P.PickSlipNo = PD.PickSlipNo AND P.SKU = PD.SKU
                                       AND P.CaseID = PD.LabelNo
                                       AND P.PickSlipNo = @c_PickSlipNo
                                       AND M.MbolKey = @c_MBOLKey )
                          GROUP BY PD.PickSlipNo, PD.SKU
                          ) AS PK ON PK.PickSlipNo = TP.PickSlipNo AND PK.SKU = TP.SKU

*/
                 END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM #TempPickTable WHERE PickSlipNo = @c_PickSlipNo)
                  BEGIN
                     INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                     SELECT @c_PickSlipNo, PickDetail.SKU, ISNULL(SUM(PickDetail.Qty), 0) As PickedQty , ISNULL(PK.PackedQty, 0)    -- ZG01
                     FROM PickDetail WITH (NOLOCK)
                     JOIN RefKeyLookup rkl WITH (NOLOCK) ON rkl.PickDetailKey = PickDetail.PickDetailKey
                     LEFT JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                           FROM PACKDETAIL WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.SKU ) AS PK
                           ON PK.PickSlipNo = @c_PickSlipNo AND PK.SKU = PickDetail.SKU
                     WHERE rkl.PickSlipNo = @c_PickSlipNo
                     AND   STATUS IN ('5','6','7','8','9')
                     Group By PickDetail.SKU, PK.PackedQty

  /*                   UPDATE TP
                        SET PackQty = PK.PackedQty
                     FROM #TempPickTable TP
           JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                           FROM PACKDETAIL WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.SKU ) AS PK
                           ON PK.PickSlipNo = TP.PickSlipNo AND PK.SKU = TP.SKU

                     INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                     SELECT PickSlipNo, SKU, 0, SUM(QTY) AS PackedQty
                     FROM   PACKDETAIL WITH (NOLOCK)
                     WHERE  PickSlipNo = @c_PickSlipNo
                     AND NOT EXISTS(SELECT 1 FROM #TempPickTable TP2
                                    WHERE TP2.PickSlipNo = PACKDETAIL.PickSlipNo
                                    AND TP2.SKU = PACKDETAIL.SKU)
                     GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.SKU
               */
                  END
               END


               IF EXISTS (SELECT 1 FROM #TempPickTable
                          WHERE PickSlipNo = @c_PickSlipNo
                          Having SUM(PickQty) <> SUM(PackQty)
                           )
               BEGIN
                  --SELECT * FROM #TempPickTable
                  --WHERE PickSlipNo = @c_PickSlipNo

                  SELECT @b_ReturnCode = -1
                  SELECT @n_Continue = 4
                  SELECT @n_err=73016
                  SELECT @c_errmsg='Cannot Ship MBOL. Found Unmatched Pick / Pack Qty in Orderkey ' + ISNULL(RTRIM(@c_PickSlipNo),'') + ', Sku ' + ISNULL(RTRIM(@c_PickSKU),'') + '.'

                  --(Wan01) - START
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                         '-----------------------------------------------------')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                         'Cannot Ship MBOL. Found Unmatched Pick / Pack Qty.')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                         '-----------------------------------------------------')
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                  CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                                + CONVERT(NCHAR(20), 'SKU')        + ' '
                                                + CONVERT(NCHAR(20), 'Picked')     + ' '
                                                + CONVERT(NCHAR(20), 'Packed')     + ' ' )
                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                  CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                                + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                                + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                                + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' ' )

                  INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
                  SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                         CONVERT(NCHAR(10),PickSlipNo) + ' ' +
                         CONVERT(NCHAR(20),SKU)        + ' ' +
                         CONVERT(NCHAR(20),ISNULL(SUM(PickQty),'0')) + ' ' +
                         CONVERT(NCHAR(20),ISNULL(SUM(PackQty),'0')) + ' '
                  FROM #TempPickTable
                  WHERE PickSlipNo = @c_PickSlipNo
                  GROUP BY PickSlipNo, SKU
                  Having SUM(PickQty) <> SUM(PackQty)

                  --(Wan01) - END
                  BREAK

               END
            END
            ELSE
            BEGIN
               IF EXISTS(SELECT 1 FROM PICKHEADER p WITH (NOLOCK) WHERE OrderKey = @c_PickOrderkey AND p.PickHeaderKey = @c_PickSlipNo)
               BEGIN

                   INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                   SELECT @c_PickSlipNo, PickDetail.SKU, ISNULL(SUM(Qty), 0) As PickedQty , ISNULL(PK.PackedQty, 0)  -- ZG01
                   FROM PickDetail WITH (NOLOCK)
                   LEFT JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                         FROM PACKDETAIL WITH (NOLOCK)
                         WHERE PickSlipNo = @c_PickSlipNo
                         GROUP BY PickSlipNo, SKU) AS PK
                         ON PK.PickSlipNo = @c_PickSlipNo AND PK.SKU = PickDetail.SKU
                WHERE OrderKey = @c_PickOrderKey
                   AND   STATUS IN ('5','6','7','8','9')
                   Group By PickDetail.SKU, PK.PackedQty
  /*
                   UPDATE TP
                      SET PackQty = PK.PackedQty
                   FROM #TempPickTable TP
                   JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                         FROM PACKDETAIL WITH (NOLOCK)
                         WHERE PickSlipNo = @c_PickSlipNo
                         GROUP BY PickSlipNo, SKU) AS PK
                         ON PK.PickSlipNo = TP.PickSlipNo AND PK.SKU = TP.SKU
   */
                   INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                   SELECT PickSlipNo, SKU, 0, SUM(QTY) AS PackedQty
                   FROM   PACKDETAIL WITH (NOLOCK)
                   WHERE  PickSlipNo = @c_PickSlipNo
                   AND NOT EXISTS(SELECT 1 FROM #TempPickTable TP2 WHERE TP2.PickSlipNo = PACKDETAIL.PickSlipNo
                                  AND TP2.SKU = PACKDETAIL.SKU)
                   GROUP BY PickSlipNo, SKU

               END
               ELSE
               IF EXISTS(SELECT 1 FROM PACKHEADER p WITH (NOLOCK)
                         WHERE OrderKey = '' AND p.PickSlipNo = @c_PickSlipNo
                         AND LoadKey <> '')
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM #TempPickTable WHERE PickSlipNo = @c_PickSlipNo)
                  BEGIN
                     INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                     SELECT @c_PickSlipNo, PD.SKU, ISNULL(SUM(PD.Qty), 0) As PickedQty , ISNULL(PK.PackedQty, 0)  -- ZG01
                     FROM PickDetail PD WITH (NOLOCK)
                     JOIN LoadPlanDetail lpd WITH (NOLOCK) ON lpd.OrderKey = PD.OrderKey
                     JOIN PICKHEADER PH WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey AND PH.PickHeaderKey = @c_PickSlipNo
                     LEFT JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                           FROM PACKDETAIL WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           GROUP BY PickSlipNo, SKU) AS PK
                           ON PK.PickSlipNo = @c_PickSlipNo AND PK.SKU = PD.SKU
                     AND  PD.STATUS IN ('5','6','6','8','9')
                     Group By PD.SKU, PK.PackedQty
/*
                     UPDATE TP
                        SET PackQty = PK.PackedQty
                     FROM #TempPickTable TP
                     JOIN (SELECT PickSlipNo, SKU, SUM(QTY) AS PackedQty
                           FROM PACKDETAIL WITH (NOLOCK)
                           WHERE PickSlipNo = @c_PickSlipNo
                           GROUP BY PickSlipNo, SKU) AS PK
                           ON PK.PickSlipNo = TP.PickSlipNo AND PK.SKU = TP.SKU
  */
                     INSERT INTO #TempPickTable (PickSlipNo, SKU, PickQty, PackQty)
                     SELECT PickSlipNo, SKU, 0, SUM(QTY) AS PackedQty
                     FROM   PACKDETAIL WITH (NOLOCK)
                     WHERE  PickSlipNo = @c_PickSlipNo
                     AND NOT EXISTS(SELECT 1 FROM #TempPickTable TP2
                                    WHERE TP2.PickSlipNo = PACKDETAIL.PickSlipNo
                                    AND TP2.SKU = PACKDETAIL.SKU)
                     GROUP BY PickSlipNo, SKU

                  END
               END -- 27-JUN-2012 (Wan) Move up here from below

                  IF EXISTS (SELECT 1 FROM #TempPickTable
            WHERE PickSlipNo = @c_PickSlipNo
                             Having SUM(PickQty) <> SUM(PackQty)
                              )
                  BEGIN
                     SELECT @b_ReturnCode = -1
                     SELECT @n_Continue = 4
                     SELECT @n_err=73017
                     SELECT @c_errmsg='Cannot Ship MBOL. Found Unmatched Pick / Pack Qty in Orderkey ' + ISNULL(RTRIM(@c_PickSlipNo),'') + ', Sku ' + ISNULL(RTRIM(@c_PickSKU),'') + '.'

                     --(Wan01) - START
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                            '-----------------------------------------------------')
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                            'Cannot Ship MBOL. Found Unmatched Pick / Pack Qty.')
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                            '-----------------------------------------------------')
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                     CONVERT(NCHAR(10), 'PickSlip#')  + ' '
                                                   + CONVERT(NCHAR(20), 'SKU')     + ' '
                                                   + CONVERT(NCHAR(20), 'Picked')     + ' '
                                                   + CONVERT(NCHAR(20), 'Packed')     + ' ' )
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                     CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                                   + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                                   + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                                   + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' ' )

                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
                     SELECT DISTINCT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                            CONVERT(NCHAR(10),PickSlipNo) + ' ' +
                            CONVERT(NCHAR(20),SKU)        + ' ' +
                            CONVERT(NCHAR(20),ISNULL(SUM(PickQty),'0')) + ' ' +
                            CONVERT(NCHAR(20),ISNULL(SUM(PackQty),'0')) + ' '
                     FROM #TempPickTable
                     WHERE PickSlipNo = @c_PickSlipNo
                     GROUP BY PickSlipNo, SKU
                     Having SUM(PickQty) <> SUM(PackQty)

                     --(Wan01) - END
                     BREAK
                  END
               --END -- 27-JUN-2012 (Wan) Move up here from below
            END
            FETCH NEXT FROM Cursor_CheckPickPackQtyWhenMBOL INTO @c_PickSlipNo, @c_PickOrderkey
         END
         CLOSE Cursor_CheckPickPackQtyWhenMBOL
         DEALLOCATE Cursor_CheckPickPackQtyWhenMBOL
      END
   END -- @n_continue = 1 OR @n_continue = 2
   -- End : SOS65533


   SET @d_step3 = GETDATE() - @d_step3 -- (tlting01)
   SET @d_step4 = GETDATE()  -- (tlting01)


   -- Added By SHONG on 24-Jan-2005
   -- Not Allow to ship is Replenishment Not done yet.
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Modify by ricky (Feb,2005) to prevent the Ship by modify Having Sum(P.Qty) > Sum(L.Qty)
      -- (YokeBeen01) - Start

      DECLARE @c_OverAllocationFlag NVARCHAR(30)

      SET @c_OverAllocationFlag = '0'

      SELECT  @c_OverAllocationFlag = ISNULL(NSQLValue, '0')
      FROM    NSQLCONFIG WITH (NOLOCK)
      WHERE   ConfigKey = N'ALLOWOVERALLOCATIONS'

      CREATE TABLE #P (
            rowref INT NOT NULL IDENTITY(1, 1) PRIMARY KEY    ,  --TLTING05
            LOT       NVARCHAR(10) NULL,
            LOC       NVARCHAR(10) NULL,
            ID        NVARCHAR(18) NULL,
            StorerKey NVARCHAR(15) NULL,
            SKU       NVARCHAR(20) NULL,
            Qty       Int NULL )

          -- TLTING05
        CREATE INDEX IDX_P_lli ON #P (lot, loc, id)
      -- Check on the Valid records within the specific MBOLKey.
      IF @c_OverAllocationFlag = '1'
      BEGIN
         -- Check on the Valid records within the specific MBOLKey.
         INSERT INTO #P   (lot, loc, id, StorerKey, SKU, Qty )     -- TLTING05
         SELECT P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku, SUM(P.Qty) AS Qty
         FROM  ORDERDETAIL O WITH (NOLOCK)
         JOIN  PickDetail P WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON P.OrderKey =  O.OrderKey AND
                                  P.OrderLineNumber = O.OrderLineNumber AND P.Status < '9'
         WHERE O.MBOLKEY = @c_MBOLKey
         GROUP BY P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku
      END
      ELSE
      BEGIN
         -- TLTING02
         INSERT INTO #P  (lot, loc, id, StorerKey, SKU, Qty )    -- TLTING05
         SELECT P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku, SUM(P.Qty) AS Qty
         FROM PickDetail P WITH (NOLOCK)
         WHERE  P.Status < '9'
         AND exists ( select 1 FROM ORDERDETAIL OD WITH (NOLOCK)
         JOIN ORDERS o (nolock) on O.OrderKey =  OD.OrderKey
         --JOIN  STORERCONFIG S WITH (NOLOCK) ON (O.Storerkey = S.Storerkey AND S.ConfigKey = 'ALLOWOVERALLOCATIONS' AND S.sValue = '1' )
         JOIN  STORERCONFIG S WITH (NOLOCK) ON (O.Storerkey = S.Storerkey AND S.ConfigKey = N'ALLOWOVERALLOCATIONS' AND S.sValue = '1' AND (S.Facility = o.Facility OR ISNULL(S.facility,'')='') )   --NJOW06
         WHERE OD.MBOLKEY = @c_MBOLKey
            AND   P.OrderKey =  O.OrderKey
            AND   P.OrderKey =  OD.OrderKey AND P.OrderLineNumber = OD.OrderLineNumber    )
         GROUP BY P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku

/*
         SELECT P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku, SUM(P.Qty) AS Qty
         FROM  ORDERDETAIL O WITH (NOLOCK)
         JOIN  PickDetail P WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON P.OrderKey =  O.OrderKey AND
                                  P.OrderLineNumber = O.OrderLineNumber AND P.Status < '9'
         JOIN  STORERCONFIG S WITH (NOLOCK) ON (O.Storerkey = S.Storerkey AND S.ConfigKey = 'ALLOWOVERALLOCATIONS' AND S.sValue = '1' )
         WHERE O.MBOLKEY = @c_MBOLKey
         GROUP BY P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku */
      END

      -- Check on the Valid records against LOTxLOCxID.

      SELECT L.LOT, L.LOC, L.ID, L.Storerkey, L.Sku, L.Qty AS Qty INTO #L
      FROM LOTxLOCxID L WITH (NOLOCK)
      JOIN #P P ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID )  --TLTING04 -- AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku

      -- Check on the records not within the specific MBOLKey.

      -- TLTING09
      SELECT P1.LOT, P1.LOC, P1.ID, P1.Storerkey, P1.Sku, SUM(P1.Qty) as Qty INTO #P1
      FROM PickDetail P1 WITH (NOLOCK)
      JOIN #P P ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID )
                    AND P1.SHIPFLAG = 'Y' and P1.Status < '9'
      WHERE NOT EXISTS (SELECT 1
                        FROM MBOLDETAIL MBD WITH (NOLOCK)
                        WHERE MBD.MBOLKEY = @c_MBOLKey
                        AND P1.OrderKey = MBD.OrderKey )
      GROUP BY P1.LOT, P1.LOC, P1.ID, P1.Storerkey, P1.Sku
      -- OPTION (OPTIMIZE FOR UNKNOWN)    --TLTING06


      -- Overall check based on the specific MBOLKey.

      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, Key2, Key3, LineText)
      SELECT DISTINCT P.Lot, P.Loc, P.ID
            , CONVERT(NCHAR(10),L.LOT) + ' '
            + CONVERT(NCHAR(10),L.LOC) + ' '
            + CONVERT(NCHAR(18),L.ID)  + ' '
            + CONVERT(NCHAR(10),(ISNULL(L.Qty,0) - ISNULL(P1.Qty,0))) + ' '
            + CONVERT(NCHAR(15),ISNULL(P.Qty,0)) + ' '
      FROM #P P
      JOIN #L L ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku)
      LEFT OUTER JOIN #P1 P1 ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
      WHERE P.Qty > (L.Qty - ISNULL(P1.Qty,0))

      -- P.Qty > L.Qty
      -- --- tlting remark(L.Qty - ISNULL(P1.Qty,0))  -- only check Own Qty enough to ship
      --
      --IF EXISTS ( SELECT 1
      --            FROM #P P
      --            JOIN #L L ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku)
      --            LEFT OUTER JOIN #P1 P1 ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
      --            WHERE P.Qty > (L.Qty - ISNULL(P1.Qty,0)) )
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         SELECT @b_ReturnCode = -1       ---1  -- (ChewKP10)
         SELECT @n_Continue = 4
         SELECT @n_err=73018
         SELECT @c_errmsg='Replenishment Not Done Yet.'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                       '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Replenishment Not Done Yet.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'LOT#')         + ' '
                                    + CONVERT(NCHAR(10), 'Location')     + ' '
                                    + CONVERT(NCHAR(18), 'ID')           + ' '
                                    + CONVERT(NCHAR(10), 'Qty')  + ' '
                                    + CONVERT(NCHAR(15), 'Qty To Ship')  + ' '
    )
     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(18), REPLICATE('-', 18)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END

      -- To turn this on only when need to trace on the performance.
      --  -- insert into table, TraceInfo for tracing purpose.
      --    BEGIN TRAN
      --   SET @c_endtime = GETDATE()
      --   INSERT INTO TraceInfo VALUES
      --    ('isp_ValidateMBOL ' + @c_MBOLKey, @c_starttime, @c_endtime
      --    ,CONVERT(NCHAR(12),@c_endtime-@c_starttime ,114)
      --    ,CONVERT(NCHAR(12),@c_step1,114)
      --    ,CONVERT(NCHAR(12),@c_step2,114)
      -- ,CONVERT(NCHAR(12),@c_step3,114)
      --    ,CONVERT(NCHAR(12),@c_step4,114)
      --    ,CONVERT(NCHAR(12),@c_step5,114))
      --    COMMIT TRAN
       -- (YokeBeen01) - End
   END
   -- 24-Jan-2005-End

   --SOS#120983 2008-11-07 YTWAN - START
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, Key2, Key3, LineText)
      SELECT DISTINCT OD.Orderkey, OD.Storerkey, OD.Sku
            ,CONVERT(NCHAR(10), OD.Orderkey) + ' '
            +CONVERT(NCHAR(5),  OD.OrderLineNumber) + ' '
            +CONVERT(NCHAR(15), OD.Storerkey) + ' '
            +CONVERT(NCHAR(20), OD.Sku) + ' '
      FROM #MBOLCheck M WITH (NOLOCK)
      INNER JOIN ORDERS O       WITH (NOLOCK) ON (M.Orderkey = O.Orderkey)
      INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (O.Orderkey = OD.Orderkey)
      INNER JOIN Codelkup CL    WITH (NOLOCK) ON (CL.LISTNAME = N'ORDTYP2ASN' And CL.Code = M.Type And Long = 'ispPopulateToASN_VMITF')
      WHERE SUBSTRING(ISNULL(O.Notes,''),1,3) = 'VMI'
      AND (
         NOT EXISTS ( SELECT 1 FROM STORER ST WITH (NOLOCK)
                        WHERE ST.Storerkey = SUBSTRING(SUBSTRING(O.NOTES ,CHARINDEX(' ', O.NOTES)+ 1, DATALENGTH(O.NOTES)), 1,
                                                 CASE WHEN CHARINDEX(' ', SUBSTRING(O.NOTES, CHARINDEX(' ', O.NOTES) + 1, DATALENGTH(O.NOTES))) = 0
                                                      THEN DATALENGTH(O.NOTES)
                                                 ELSE CHARINDEX(' ', SUBSTRING(O.NOTES, CHARINDEX(' ', O.NOTES) + 1, DATALENGTH(O.NOTES))) - 1
                                                 END) )
      OR NOT EXISTS  ( SELECT 1 FROM SKU SKU WITH (NOLOCK)
                       WHERE SKU.Storerkey = SUBSTRING(SUBSTRING(O.NOTES ,CHARINDEX(' ', O.NOTES)+ 1, DATALENGTH(O.NOTES)), 1,
                                                 CASE WHEN CHARINDEX(' ', SUBSTRING(O.NOTES, CHARINDEX(' ', O.NOTES) + 1, DATALENGTH(O.NOTES))) = 0
                                                      THEN DATALENGTH(O.NOTES)
                                                 ELSE CHARINDEX(' ', SUBSTRING(O.NOTES, CHARINDEX(' ', O.NOTES) + 1, DATALENGTH(O.NOTES))) - 1
                                                 END)
                   AND SKU.Sku = OD.Sku )
)

      --IF EXISTS ( SELECT 1
      --            FROM #MBOLCheck M    WITH (NOLOCK)
      --            JOIN StorerConfig SC WITH (NOLOCK)
      --            ON   M.StorerKey = SC.StorerKey and SC.configkey = 'AutoCreateASN' AND SC.sValue = '1'
      --            JOIN Codelkup CL     WITH (NOLOCK)
      --            ON   (CL.LISTNAME = 'ORDTYP2ASN' And CL.Code = M.Type And Long = 'ispPopulateToASN_VMITF') )
      --BEGIN
      --   IF EXISTS ( SELECT 1
      --               FROM #MBOLCheck M WITH (NOLOCK)
      --               INNER JOIN ORDERDETAIL OD WITH (NOLOCK)
      --               ON (M.Orderkey = OD.Orderkey)
      --               INNER JOIN (
      --               SELECT ORDERKEY,
      --                      TYPE,
      --                      RSTORER = SUBSTRING(SUBSTRING(NOTES ,CHARINDEX(' ', NOTES)+ 1, DATALENGTH(NOTES)), 1,
      --                                          CASE WHEN CHARINDEX(' ', SUBSTRING(NOTES, CHARINDEX(' ', NOTES) + 1, DATALENGTH(NOTES))) = 0
      --                                               THEN DATALENGTH(NOTES)
      --                                          ELSE CHARINDEX(' ', SUBSTRING(NOTES, CHARINDEX(' ', NOTES) + 1, DATALENGTH(NOTES))) - 1
      --                                          END)
      --               FROM  ORDERS WITH (NOLOCK)
      --               WHERE SUBSTRING(ISNULL(Notes,''),1,3) = 'VMI') O
      --               ON ( O.orderkey = OD.Orderkey )
      --               JOIN Codelkup CL WITH (NOLOCK)
      --               ON (CL.LISTNAME = 'ORDTYP2ASN' And CL.Code = O.Type And CL.Long = 'ispPopulateToASN_VMITF')
      --               WHERE (O.RSTORER NOT IN ( SELECT Storerkey FROM STORER WITH (NOLOCK))
      --               OR OD.SKU NOT IN ( SELECT SKU FROM SKU WITH (NOLOCK) WHERE Storerkey = O.RSTORER)) )
  IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
         BEGIN
      --(Wan01) - END
            SELECT @b_ReturnCode = -1
            SELECT @n_Continue = 4
            SELECT @n_err=73019
            SELECT @c_errmsg='Invalid Storer Key OR SKU. '

            --(Wan01) - START
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                   'Invalid Storer Key OR SKU.')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                   '-----------------------------------------------------')
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                         CONVERT(NCHAR(10), 'Orderkey')  + ' '
                                       + CONVERT(NCHAR(5),  'Line')      + ' '
                                       + CONVERT(NCHAR(15), 'Storerkey') + ' '
                                       + CONVERT(NCHAR(20), 'Sku')       + ' '
                                       )
            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
     CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
   + CONVERT(NCHAR( 5), REPLICATE('-',  5)) + ' '
                                       + CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                       + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                       )

            INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
            SELECT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
            FROM #ErrorLogDetail
            --(Wan01) - END
         END
      --END  --(Wan01)
   END
   --SOS#120983 2008-11-07 YTWAN - END

   -- Commented by SHONG, Not go live yet
   -- (KC01) - Start
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @cOrderKey = '' -- SOS#209421
      --(Wan01) - START
      --SET ROWCOUNT 1

      --SELECT @cOrderKey = P.ORDERKEY
      --FROM #MBOLCheck M
      --JOIN PreAllocatePickDetail P WITH (NOLOCK)
      --On (M.StorerKey = P.StorerKey and M.Orderkey = P.Orderkey)
      --WHERE P.Qty > 0

      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT P.Orderkey
            ,CONVERT(NCHAR(10), P.Orderkey) + ' '
            +CONVERT(NCHAR( 5), P.OrderLineNumber) + ' '
            +CONVERT(NCHAR(10), P.lot) + ' '
            +CONVERT(NCHAR(15), P.Storerkey) + ' '
            +CONVERT(NCHAR(20), P.Sku) + ' '
            +CONVERT(NCHAR(15), ISNULL(P.Qty,0)) + ' '
      FROM #MBOLCheck M
      JOIN PreAllocatePickDetail P WITH (NOLOCK) ON (M.StorerKey = P.StorerKey and M.Orderkey = P.Orderkey)
      WHERE P.Qty > 0

      --IF ISNULL(RTRIM(@cOrderKey),'') <> ''
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - END
      BEGIN
         --(Wan01) - START
         SELECT TOP 1 @cOrderKey = Key1
         FROM #ErrorLogDetail
         --(Wan01) - END

         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 4
         SELECT @n_err=73020
         SELECT @c_errmsg='Cannot Ship MBOL. Order# ' + ISNULL(RTRIM(@cOrderKey),'') + ', has PreallocatePick in Progress.'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Some Orders have PreallocatePick in Progress.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Orderkey') + ' '
                                    + CONVERT(NCHAR(5),  'Line')     + ' '
                                    + CONVERT(NCHAR(10), 'Lot')      + ' '
                                    + CONVERT(NCHAR(15), 'Storerkey')+ ' '
                                    + CONVERT(NCHAR(20), 'Sku')      + ' '
                                    + CONVERT(NCHAR(15), 'Preallocate Qty')      + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR( 5), REPLICATE('-',  5)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                    + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                    + CONVERT(NCHAR(15), REPLICATE('-', 10)) + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END

   END -- @n_continue = 1 OR @n_continue = 2
   -- (KC01) - End

   SET @d_step4 = GETDATE() - @d_step4 -- (tlting01)
   SET @d_step5 = GETDATE()  -- (tlting01)


   -- SOS#123359 Extented Validation for MBOL using Codelkup
   --(Wan05) IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE @nSuccess             Int
            , @cMBOLValidationRules NVARCHAR(30)
            , @cStorerKey           NVARCHAR(15)

      SET @nSuccess = 0              -- SOS#202300
      SET @cMBOLValidationRules = '' -- SOS#202300
      SET @cStorerKey = ''           -- SOS#202300

      DECLARE CUR_ExtendedMBOLValidation CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      -- SOS#202300 (Start)
      -- SELECT DISTINCT M.StorerKey, SC.sValue
      -- FROM #MBOLCheck   M  WITH (NOLOCK)
      -- JOIN StorerConfig SC WITH (NOLOCK) ON M.StorerKey = SC.StorerKey AND SC.Configkey = 'MBOLExtendedValidation'

      SELECT DISTINCT ISNULL(RTRIM(SC.StorerKey),''), ISNULL(RTRIM(SC.SValue),'')
      FROM MBOLDetail MD WITH (NOLOCK)
      JOIN Orders O WITH (NOLOCK)
      ON (MD.OrderKey = O.OrderKey)
      JOIN StorerConfig SC WITH (NOLOCK) ON ( O.StorerKey = SC.StorerKey AND --SOS#213415
                                             (O.Facility = SC.Facility OR SC.Facility = '' OR SC.Facility IS NULL) AND
                                              SC.Configkey = N'MBOLExtendedValidation' )
      WHERE MD.MBOLKey = @c_MBOLKey
      -- SOS#202300 (End)

      OPEN CUR_ExtendedMBOLValidation

      FETCH NEXT FROM CUR_ExtendedMBOLValidation INTO @cStorerKey, @cMBOLValidationRules

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF EXISTS(SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE  ListName = @cMBOLValidationRules) --(Wan05) AND @n_Continue IN(1,2)
         BEGIN
            -- Initial Variable (SWT01)
            SET @c_ErrMsg=''
            SET @nSuccess= 1

            EXEC isp_MBOL_ExtendedValidation @cMBOLKey = @c_MBOLKey,
                                             @cStorerKey = @cStorerKey,
                                             @cMBOLValidationRules = @cMBOLValidationRules,
                                             @nSuccess = @nSuccess OUTPUT, @cErrorMsg = @c_errmsg OUTPUT
            --(Wan05) - START
            --IF @nSuccess <> 1
            --BEGIN

            --   SELECT @b_ReturnCode = -1
            --   SELECT @n_Continue = 4

               --(Wan04) - START
            --   IF @nSuccess = 2 -- RETRUN WARNING FROM SP
            --   BEGIN
            --      SET @b_ReturnCode = 1
            --      SET @n_Continue = 1
            --   END
               --(Wan04) - END

        --   SELECT @n_err=73021

               --(Wan04) - Move Insert MBOLErrorReport to isp_MBOL_ExtendedValidation SP, ErrorNo Must be unique (START)
               --(Wan01) - START
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       '-----------------------------------------------------')
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       @c_errmsg)
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       '-----------------------------------------------------')
               --(Wan01) - END
               --(Wan04) - Move Insert MBOLErrorReport to isp_MBOL_ExtendedValidation SP, ErrorNo Must be unique (END)
            --END
            --(Wan05) - END
         END


         --NJOW04 Start CALLING ispMBCHK??
         --Wan04  SP Must cater Insert Error Message to MBOLErrorReport table
         IF EXISTS (SELECT 1 FROM dbo.sysobjects with (NOLOCK)
                  WHERE name = RTRIM(@cMBOLValidationRules) AND type = 'P') --(Wan05) AND @n_Continue IN(1,2)
         BEGIN
            SET @c_SQL = 'EXEC ' + @cMBOLValidationRules + ' @c_MBOLKey, @cStorerKey, @nSuccess OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '

            -- Initial Variable (SWT01)
            SET @nSuccess = 1
            SET @n_Err = 0
            SET @c_ErrMsg = ''

            EXEC sp_executesql @c_SQL,
                 N'@c_MBOLKey NVARCHAR(10), @cStorerKey NVARCHAR(15), @nSuccess Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',
                 @c_MBOLKey,
                 @cStorerKey,
                 @nSuccess OUTPUT,
                 @n_Err OUTPUT,
                 @c_ErrMsg OUTPUT
            --(Wan05) - START
            --IF @nSuccess <> 1
            --BEGIN
            --   SELECT @b_ReturnCode = -1
            --   SELECT @n_Continue = 4

               --(Wan04) - START
            --   IF @nSuccess = 2 -- RETRUN WARNING FROM SP
            --   BEGIN
            --      SET @b_ReturnCode = 1
            --      SET @n_Continue = 1
            --   END
               --(Wan04) - END

               --(Wan04) - Move Insert MBOLErrorReport SP, ErrorNo Must be unique (START)
               --(Wan01) - START
               --SET @n_err=73022
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       '-----------------------------------------------------')
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       @c_errmsg)
               --INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
               --                                                                       '-----------------------------------------------------')
               --(Wan01) - END
               --(Wan04) - Move Insert MBOLErrorReport SP, , ErrorNo Must be unique (END)
            --END
            --(Wan05) - END
         END
         --NJOW04 End

         FETCH NEXT FROM CUR_ExtendedMBOLValidation INTO @cStorerKey, @cMBOLValidationRules
      END
      CLOSE CUR_ExtendedMBOLValidation
      DEALLOCATE CUR_ExtendedMBOLValidation
   END --    IF @n_Continue = 1 OR @n_Continue = 2

   --NJOW02 - Start
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --(Wan01) - START
      TRUNCATE TABLE #ErrorLogDetail

      IF EXISTS(SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK)
                JOIN ORDERS O WITH (NOLOCK) ON (MD.Orderkey = O.Orderkey)
                JOIN STORERCONFIG SC WITH (NOLOCK) ON (O.StorerKey = SC.StorerKey AND SC.configkey = N'SPLITLOADPLANORDER' AND SC.sValue = '1')
                WHERE MD.Mbolkey  = @c_MBOLKey)
      BEGIN
         INSERT INTO #ErrorLogDetail (Key1, LineText)
         SELECT DISTINCT MD.Orderkey
               ,CONVERT(NCHAR(10), O.Orderkey) + ' '
               +CONVERT(NCHAR(30), O.ExternOrderkey)
         FROM MBOLDETAIL MD WITH (NOLOCK)
         JOIN ORDERS O WITH (NOLOCK) ON (MD.Orderkey = O.Orderkey)
         JOIN STORERCONFIG SC WITH (NOLOCK) ON (O.StorerKey = SC.StorerKey AND SC.configkey = N'SPLITLOADPLANORDER' AND SC.sValue = '1')
         WHERE ISNULL(RTRIM(O.Ordergroup),'') <> ''
         AND MD.Mbolkey  = @c_MBOLKey
         AND EXISTS (SELECT 1
                     FROM ORDERS O2 WITH (NOLOCK)
                     WHERE O2.Status < '5'
                     AND   O2.Ordergroup = O.Ordergroup)
      END

      --IF ( SELECT COUNT(*) FROM MBOLDETAIL MD WITH (NOLOCK)
      --     JOIN ORDERS O WITH (NOLOCK) ON (MD.Orderkey = O.Orderkey)
      --     JOIN STORERCONFIG SC WITH (NOLOCK) ON (O.StorerKey = SC.StorerKey AND SC.configkey = 'SPLITLOADPLANORDER' AND SC.sValue = '1')
      --     WHERE ISNULL(RTRIM(O.Ordergroup),'') <> ''
      --     AND MD.Mbolkey  = @c_MBOLKey
      --     AND O.Ordergroup IN (SELECT O2.Ordergroup
      --                       FROM ORDERS O2 WITH (NOLOCK)
      --                          WHERE O2.Status < '5'
      --                          AND O.Ordergroup = O2.Ordergroup) ) > 0
      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      --(Wan01) - START
      BEGIN
         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 4
         SELECT @n_err=73023
         SELECT @c_errmsg='Split Orders Not Fully Picked. MBOL Ship Is Not Allowed'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Some Split Orders have not fully Picked.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Orderkey')       + ' '
                                    + CONVERT(NCHAR(30), 'ExternOrderKey') + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                              + CONVERT(NCHAR(30), REPLICATE('-', 30)) + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
         --(Wan01) - END
      END
   END
   --NJOW02 - End

   --SOS#153916 - Remy validate serial number scan out. NJOW01 13-Jan-2010 - Start
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT MBOLDETAIL.Orderkey, ORDERDETAIL.Storerkey, ORDERDETAIL.SKU,
             SUM(ORDERDETAIL.Qtyallocated+ORDERDETAIL.Qtypicked+ORDERDETAIL.shippedqty) AS Qty
      INTO #TMPSER
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
      WHERE SKU.susr4 = 'SSCC'
        AND MBOLDETAIL.Mbolkey = @c_mbolkey
      GROUP BY MBOLDETAIL.Orderkey, ORDERDETAIL.Storerkey, ORDERDETAIL.SKU

      SELECT T.OrderKey, T.StorerKey, T.SKU, T.Qty, SUM(SERIALNO.Qty) AS ScanQty
      INTO #TMPSER2 FROM #TMPSER T
      LEFT JOIN SERIALNO SERIALNO WITH (NOLOCK) ON (T.ORDERKEY = SERIALNO.ORDERKEY AND T.SKU = SERIALNO.SKU)
      GROUP BY T.OrderKey, T.StorerKey, T.SKU, T.Qty

      IF EXISTS (SELECT 1 FROM #TMPSER2 a WHERE a.ScanQty IS NULL)
      BEGIN
         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 4
         SELECT @n_err=73024
         SELECT @c_errmsg='Scan Serial Number'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Scan Serial Number.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Orderkey')  + ' '
                                    + CONVERT(NCHAR(15), 'Storerkey') + ' '
                                    + CONVERT(NCHAR(15), 'Sku')       + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                    + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT DISTINCT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR'
            , CONVERT(NCHAR(10), T.OrderKey) + ' '
            + CONVERT(NCHAR(15), T.StorerKey)+ ' '
            + CONVERT(NCHAR(20), T.SKU)
         FROM #TMPSER2 T
         WHERE T.ScanQty IS NULL
         --(Wan01) - END
      END
      ELSE IF EXISTS (SELECT 1 FROM #TMPSER2 a WHERE a.Qty <> a.ScanQty)
      BEGIN
         SELECT @b_ReturnCode = -1
         SELECT @n_Continue = 4
         SELECT @n_err=73025
         SELECT @c_errmsg='Not all Serial No are scanned'

         --(Wan01) - START
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Not all Serial No are scanned.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                       '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Orderkey')  + ' '
                                    + CONVERT(NCHAR(15), 'Storerkey') + ' '
                                    + CONVERT(NCHAR(15), 'Sku')       + ' '
                                    + CONVERT(NCHAR(10), 'Qty')       + ' '
                                    + CONVERT(NCHAR(10), 'Scaned Qty')+ ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
      + CONVERT(NCHAR(20), REPLICATE('-', 20)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT DISTINCT @c_MBOLKey,  CONVERT(NVARCHAR(10),@n_err), 'ERROR'
            , CONVERT(NCHAR(10), T.OrderKey) + ' '
            + CONVERT(NCHAR(15), T.StorerKey)+ ' '
            + CONVERT(NCHAR(20), T.SKU)      + ' '
            + CONVERT(NCHAR(10), T.Qty)      + ' '
            + CONVERT(NCHAR(10),ISNULL(T.ScanQty,0))
         FROM #TMPSER2 T
         WHERE T.Qty <> T.ScanQty
         --(Wan01) - END
      END
   END
   --SOS#153916 - Remy validate serial number scan out. NJOW01 13-Jan-2010 - End

   --(Wan02) - START
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT RTRIM(SC.Storerkey)
            ,CONVERT(NCHAR(15), SC.Storerkey) + ' '
            +CONVERT(NCHAR(10), SC.SValue)     + ' '
            +CONVERT(NCHAR(25),MH.DepartureDate,121) + ' '
            +CONVERT(NCHAR(25),CASE WHEN SC.sValue < 0 THEN DATEADD(minute, SC.sValue * 60, GETDATE()) ELSE GETDATE() END,121) + ' '
            +CONVERT(NCHAR(25),CASE WHEN SC.sValue < 0 THEN GETDATE() ELSE DATEADD(minute, SC.sValue * 60, GETDATE()) END,121) + ' '

      FROM #MBOLCheck M
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON (M.Orderkey = MD.Orderkey)
      JOIN MBOL MH WITH (NOLOCK) ON (MD.MBOLKey = MH.MBOLKey)
      JOIN STORERCONFIG SC WITH (NOLOCK) ON (M.StorerKey = SC.StorerKey AND SC.configkey = N'MBOLDepartureDateChk'
                                         AND ISNUMERIC(SC.sValue) = 1  )
      WHERE MD.Mbolkey  = @c_MBOLKey
      AND ( MH.DepartureDate <  CASE WHEN SC.sValue < 0 THEN DATEADD(minute, SC.sValue * 60, GETDATE()) ELSE GETDATE() END OR
            MH.DepartureDate >  CASE WHEN SC.sValue < 0 THEN GETDATE() ELSE DATEADD(minute, SC.sValue * 60, GETDATE()) END )
      AND  ( ( MH.Remarks <> 'ECOM' AND SC.OPTION5 = 'RemarksNoEqualToECOM' ) OR SC.OPTION5 = '' ) -- SWT01

      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      BEGIN
         SET @b_ReturnCode = -1
         SET @n_Continue = 4
         SET @n_err=73026
         SET @c_errmsg='MBOL Departure date is not within the set hour range. MBOL#: ' + @c_MBOLKey

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'MBOL Departure Date is out of set hour range.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(15), 'Storerkey')  + ' '
                                    + CONVERT(NCHAR(10), 'Set hour')   + ' '
                                    + CONVERT(NCHAR(25), 'Departure Datetime') + ' '
                                    + CONVERT(NCHAR(25), 'Ship From Datetime') + ' '
                                    + CONVERT(NCHAR(25), 'Ship To Datetime')   + ' '
                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(15), REPLICATE('-', 15)) + ' '
                                    + CONVERT(NCHAR(10),  REPLICATE('-',10)) + ' '
                                    + CONVERT(NCHAR(25), REPLICATE('-', 25)) + ' '
                                    + CONVERT(NCHAR(25), REPLICATE('-', 25)) + ' '
                                    + CONVERT(NCHAR(25), REPLICATE('-', 25)) + ' '
                         )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
      END
   END
   --(Wan02) - END

   --(Wan03) - START
   --(Wan05) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      TRUNCATE TABLE #ErrorLogDetail

      INSERT INTO #ErrorLogDetail (Key1, LineText)
      SELECT DISTINCT M.Orderkey
            ,CONVERT(NCHAR(10), M.Orderkey) + ' '
            +CONVERT(NCHAR(10), (SELECT ISNULL(SUM(OpenQty),0) FROM ORDERDETAIL WITH (NOLOCK) WHERE Orderkey = M.Orderkey)) + ' '
            +CONVERT(NCHAR(10), ISNULL(SUM(PD.Qty),0))
      --(Wan06) - START
      --FROM #MBOLCheck M
      FROM MBOLDETAIL      M  WITH (NOLOCK)
      --(Wan06) - END
      JOIN ORDERS          OH WITH (NOLOCK) ON (M.Orderkey = OH.Orderkey)
      LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey= PD.Orderkey)
      --(Wan06)
      --JOIN STORERCONFIG SC WITH (NOLOCK) ON (M.StorerKey = SC.StorerKey AND SC.configkey = 'CancORZeroPickSOChk'
      JOIN STORERCONFIG SC WITH (NOLOCK) ON (OH.StorerKey = SC.StorerKey AND SC.configkey = N'CancORZeroPickSOChk'
      --(Wan06) - END
                                         AND SC.sValue = '1'  )
      --(Wan06) - START
      --WHERE OH.Mbolkey  = @c_MBOLKey
      WHERE M.Mbolkey = @c_MBOLKey
      --(Wan06) - END
      GROUP BY M.Orderkey, RTRIM(OH.SOStatus)
      HAVING (ISNULL(SUM(PD.Qty),0) = 0 OR RTRIM(OH.SOStatus) = 'CANC')


      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      BEGIN
         SET @b_ReturnCode = -1
         SET @n_Continue = 4
         SET @n_err=73027
         SET @c_errmsg='There is cancel orders/unprocess order. Not allow to ship.'

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'There is cancel orders/unprocess order. Not allow to ship.')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Orderkey')  + ' '
                                    + CONVERT(NCHAR(10), 'Order qty')   + ' '
                                    + CONVERT(NCHAR(10), 'QtyAlloc Pick') + ' '

                                    )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(10),  REPLICATE('-',10)) + ' '
                                    + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                         )
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
      END
   END
   --(Wan03) - END

   -- SCAC Validation (ChewKP08) -- Start
   IF ISNULL(@n_CBOLKEy ,0) <> 0
   BEGIN
         --(Wan05) IF @n_continue = 1 OR @n_continue = 2
        BEGIN
            SET @c_MBOLSCACCodeValidation = ''
            SELECT @c_MBOLSCACCodeValidation = CASE WHEN RTRIM(StorerConfig.sValue) = '1' THEN '1' ELSE '0' END
            FROM dbo.StorerConfig WITH (NOLOCK)
            JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
            WHERE ConfigKey = N'MBOLSCACCodeValidation'

            IF ISNULL( @c_MBOLSCACCodeValidation, '') = '1'
            BEGIN
               TRUNCATE TABLE #ErrorLogDetail

               IF EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                          WHERE CBOLKey = @n_CBOLKey
                          HAVING COUNT(Distinct CarrierKey) > 1)
               BEGIN

                  INSERT INTO #ErrorLogDetail (Key1, LineText)
                  SELECT DISTINCT M.CBOLKEY,
                         CONVERT(NCHAR(10), M.CBOLKEY) + ' '
                        +CONVERT(NCHAR(10), M.MBOLKEY) + ' '
                        +CONVERT(NCHAR(10), M.CARRIERKEY) + ' '
                  FROM dbo.MBOL M WITH (NOLOCK)
                  WHERE M.CBOLKey = @n_CBOLKey



                  IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
                  BEGIN
                     SET @b_ReturnCode = -1
                     SET @n_Continue = 4
                     SET @n_err=73028
                     SET @c_errmsg='Different SCAC in CBOL, Not Allow to Ship'

                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                            '-----------------------------------------------------')
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                            'Different SCAC in CBOL, Not Allow to Ship')
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                            '-----------------------------------------------------')

                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                  CONVERT(NCHAR(10), 'CBOLKey')  + ' '
                                                + CONVERT(NCHAR(10), 'MBOLKey')   + ' '
                                                + CONVERT(NCHAR(10), 'SCAC') + ' '

                                                )
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                  CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                                + CONVERT(NCHAR(10),  REPLICATE('-',10)) + ' '
                                                + CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                                  )
                     INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
                     SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
                     FROM #ErrorLogDetail
                  END
               END
            END
         END


   END
   -- (ChewKP08) -- End

   --(ChewKP08) IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_ShipByCBOL = ''
      SELECT @c_ShipByCBOL = CASE WHEN RTRIM(StorerConfig.sValue) = '1' THEN '1' ELSE '0' END
      FROM dbo.StorerConfig WITH (NOLOCK)
      JOIN #MBOLCheck M ON (M.StorerKey = StorerConfig.StorerKey)
      WHERE ConfigKey = N'ShipByCBOL'



      IF ISNULL( @c_ShipByCBOL, '') = '1' AND @n_CBOLKey = 0
      BEGIN
         TRUNCATE TABLE #ErrorLogDetail

         IF EXISTS (SELECT 1 FROM dbo.MBOL WITH (NOLOCK)
                    WHERE MBOLKey = @c_MBOLKey
                    AND ISNULL(CBOLKey,0) <> 0 )
         BEGIN

            INSERT INTO #ErrorLogDetail (Key1, LineText)
            SELECT DISTINCT M.CBOLKEY,
                   CONVERT(NCHAR(10), M.CBOLKEY) + ' '
                  +CONVERT(NCHAR(10), M.MBOLKEY) + ' '
            FROM dbo.MBOL M WITH (NOLOCK)
            WHERE M.MBOLKey = @c_MBOLKey



            IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
            BEGIN
               SET @b_ReturnCode = -1
               SET @n_Continue = 4
               SET @n_err=73028
               SET @c_errmsg='MBOL with CBOLKey, Not Allow to Ship From MBOL'

               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                          '-----------------------------------------------------')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                      'MBOL with CBOLKey, Not Allow to Ship From MBOL')
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                      '-----------------------------------------------------')

               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), 'CBOLKey')  + ' '
                                          + CONVERT(NCHAR(10), 'MBOLKey')   + ' '


                                          )
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                            CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                          + CONVERT(NCHAR(10),  REPLICATE('-',10)) + ' '

                                               )
               INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
               SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
               FROM #ErrorLogDetail
            END
         END
      END
   END

   --(Wan05) - START
   TRUNCATE TABLE #ErrorLogDetail

   INSERT INTO #ErrorLogDetail (Key1, LineText)
   SELECT DISTINCT MBD.Orderkey
         ,CONVERT(NCHAR(10), MBD.Orderkey)
   FROM MBOL        MBH WITH (NOLOCK)
   JOIN MBOLDETAIL  MBD WITH (NOLOCK) ON (MBH.MBOLkey = MBD.MBOLkey)
   JOIN ORDERS      OH  WITH (NOLOCK) ON (MBD.Orderkey= OH.Orderkey)
   JOIN STORERCONFIG SC WITH (NOLOCK) ON (OH.StorerKey = SC.StorerKey AND SC.configkey = N'MBolCarrierMandatory'
                                      AND SC.sValue = '1'  )
   WHERE MBH.MBOLkey  = @c_MBOLKey
   AND (MBH.Carrierkey IS NULL OR LTRIM(MBH.Carrierkey) = '')


   IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
   BEGIN
      SET @n_err   =73029
      SET @c_errmsg='Carrier Key is Required.'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                             'Carrier Key is Required.')
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                   CONVERT(NCHAR(10), 'Orderkey')
                                  )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                   CONVERT(NCHAR(10), REPLICATE('-', 10))
                                  )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
      SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
      FROM #ErrorLogDetail
   END

   --(Wan05) - END

   --(Wan07) - START
   TRUNCATE TABLE #ErrorLogDetail

   SET @c_Facility = ''
   SET @c_Storerkey = ''

   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
         , @c_Facility = MBOL.Facility
   FROM MBOL       WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE MBOL.MBOLKey = @c_MBOLKey

   SET @c_FinalizeMBOL = '0'
   SET @b_success = 0
   EXECUTE dbo.nspGetRight @c_facility    -- facility
          ,  @c_Storerkey                 -- Storerkey
          ,  NULL                         -- Sku
          ,  'FinalizeMBOL'               -- Configkey
          ,  @b_success       OUTPUT
          ,  @c_FinalizeMBOL  OUTPUT
          ,  @n_err           OUTPUT
          ,  @c_errmsg        OUTPUT


   INSERT INTO #ErrorLogDetail (Key1, LineText)
   SELECT DISTINCT MBD.Orderkey
               ,   MBD.Orderkey
   FROM MBOL        MBH WITH (NOLOCK)
   JOIN MBOLDETAIL  MBD WITH (NOLOCK) ON (MBH.MBOLkey = MBD.MBOLkey)
   JOIN ORDERS      OH  WITH (NOLOCK) ON (MBD.Orderkey= OH.Orderkey)
   WHERE MBH.MBOLkey  = @c_MBOLKey
   AND @c_FinalizeMBOL = 1
   AND Finalizeflag <> 'Y'
   AND ISNULL(@c_CallFrom,'') <> 'FinalizeMBOL'  --NJOW07

   IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
   BEGIN
      SET @n_err   =73030
      SET @c_errmsg='Finalize MBOL is Required before ship'

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
   'Finalize MBOL is Required before ship')
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                             '-----------------------------------------------------')

      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                   CONVERT(NCHAR(10), 'MBOLKey')
                                  )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                   CONVERT(NCHAR(10), REPLICATE('-', 10))
                                  )
      INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
      SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
      FROM #ErrorLogDetail
   END
   --(Wan07) - END

   --NJOW09 S
   TRUNCATE TABLE #ErrorLogDetail

   SET @c_MBOLNotAllowPartialLoad = '0'
   SET @c_DocType = ''
   SET @b_success = 0

   Execute nspGetRight
           @c_Facility  = @c_facility
          ,@c_StorerKey = @c_StorerKey
          ,@c_sku       = NULL
          ,@c_ConfigKey = 'MBOLNotAllowPartialLoad' -- Configkey
          ,@b_Success   = @b_success   OUTPUT
          ,@c_authority = @c_MbolNotAllowPartialLoad OUTPUT
          ,@n_err       = @n_err  OUTPUT
          ,@c_errmsg    = @c_errmsg    OUTPUT
          ,@c_Option5   = @c_MbolNotAllowPartialLoad_opt5 OUTPUT

   SET @c_DocType = dbo.fnc_GetParamValueFromString('@c_DocType', @c_MbolNotAllowPartialLoad_opt5, '')

   IF @c_MbolNotAllowPartialLoad = '1'
   BEGIN
        IF @c_DocType = 'N'
        BEGIN
         INSERT INTO #ErrorLogDetail (Key1, LineText)
         SELECT DISTINCT LPD.Orderkey,
                         CONVERT(NCHAR(10), LPD.Loadkey) + ' '
                        +CONVERT(NCHAR(10), LPD.Orderkey) + ' '
         FROM LOADPLANDETAIL LPD (NOLOCK)
         LEFT JOIN MBOLDETAIL MD (NOLOCK) ON LPD.Orderkey = MD.Orderkey
         JOIN (SELECT DISTINCT O.Loadkey
               FROM MBOLDETAIL MD (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.OrderKey
                WHERE MD.Mbolkey = @c_Mbolkey
                AND O.DocType IN ('N','', NULL)
                ) L ON LPD.Loadkey = L.Loadkey
         WHERE ISNULL(MD.Mbolkey,'') <> @c_Mbolkey
         ORDER BY CONVERT(NCHAR(10), LPD.Loadkey) + ' ' +CONVERT(NCHAR(10), LPD.Orderkey) + ' '
        END
        ELSE
        BEGIN
         INSERT INTO #ErrorLogDetail (Key1, LineText)
         SELECT DISTINCT LPD.Orderkey,
                         CONVERT(NCHAR(10), LPD.Loadkey) + ' '
                        +CONVERT(NCHAR(10), LPD.Orderkey) + ' '
         FROM LOADPLANDETAIL LPD (NOLOCK)
         LEFT JOIN MBOLDETAIL MD (NOLOCK) ON LPD.Orderkey = MD.Orderkey
         JOIN (SELECT DISTINCT O.Loadkey
               FROM MBOLDETAIL MD (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.OrderKey
                WHERE MD.Mbolkey = @c_Mbolkey
                AND O.DocType = CASE WHEN @c_DocType <> '' THEN @c_DocType ELSE O.DocType END
                ) L ON LPD.Loadkey = L.Loadkey
         WHERE ISNULL(MD.Mbolkey,'') <> @c_Mbolkey
         ORDER BY CONVERT(NCHAR(10), LPD.Loadkey) + ' ' +CONVERT(NCHAR(10), LPD.Orderkey) + ' '
      END

      IF EXISTS (SELECT 1 FROM #ErrorLogDetail)
      BEGIN
         SET @n_err=73031
         SET @c_errmsg='Not allow ship partial load plan.'

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERRORMSG',
                                                                                'Not allow ship partial load plan with missing orders')
         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                                                                '-----------------------------------------------------')

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), 'Loadkey')  + '    '
                                    + CONVERT(NCHAR(10), 'Orderkey') + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText) VALUES (@c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR',
                                      CONVERT(NCHAR(10), REPLICATE('-', 10)) + ' '
                                    + CONVERT(NCHAR(10),  REPLICATE('-',10)) + ' '
                                    )

         INSERT INTO MBOLErrorReport (MBOLKey, ErrorNo, Type, LineText)
         SELECT @c_MBOLKey, CONVERT(NVARCHAR(10),@n_err), 'ERROR', LineText
         FROM #ErrorLogDetail
      END
   END
   --NJOW09 E

----------------------------------------------------------------------
--- SOS140791 Capture PackHeader Summary - Carton Information - Start
----------------------------------------------------------------------
 DECLARE CUR_PACKINFO_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT DISTINCT LPD.Loadkey
     FROM   LOADPLANDETAIL LPD WITH (NOLOCK)
     JOIN   MBOLDETAIL MBD WITH (NOLOCK) ON (MBD.OrderKey = LPD.Orderkey)
     WHERE  MBD.MBOLKey = @c_MBOLKey

  OPEN CUR_PACKINFO_CARTON

  FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_Loadkey
  WHILE @@FETCH_STATUS <> -1
  BEGIN
     SELECT @c_CartonGroup = CartonGroup
     FROM LOADPLAN WITH (NOLOCK)
     WHERE LoadKey = @c_Loadkey

     IF ISNULL(RTRIM(@c_CartonGroup), '') = ''
     BEGIN
          UPDATE LOADPLAN WITH (ROWLOCK)
             SET CtnCnt1 = PH.CtnCnt1,
                 CtnCnt2 = PH.CtnCnt2,
                 CtnCnt3 = PH.CtnCnt3,
                 CtnCnt4 = PH.CtnCnt4,
                 CtnCnt5 = PH.CtnCnt5,
                 CtnTyp1 = PH.CtnTyp1,
                 CtnTyp2 = PH.CtnTyp2,
                 CtnTyp3 = PH.CtnTyp3,
                 CtnTyp4 = PH.CtnTyp4,
                 CtnTyp5 = PH.CtnTyp5,
                 TotCtnWeight = ISNULL(PH.TotCtnWeight,0),
                 TotCtnCube   = ISNULL(PH.TotCtnCube,0),
                 CartonGroup  = PH.CartonGroup,
                 Trafficcop = NULL
           FROM LOADPLAN
           JOIN ( SELECT ORDERS.LoadKey,
                         MAX(PackHeader.CartonGroup) AS CartonGroup,
                         SUM(ISNULL(CtnCnt1,0)) AS CtnCnt1,
                         SUM(ISNULL(CtnCnt2,0)) AS CtnCnt2,
                         SUM(ISNULL(CtnCnt3,0)) AS CtnCnt3,
                         SUM(ISNULL(CtnCnt4,0)) AS CtnCnt4,
                         SUM(ISNULL(CtnCnt5,0)) AS CtnCnt5,
                         SUM(ISNULL(TotCtnWeight,0)) AS TotCtnWeight,
                         SUM(ISNULL(TotCtnCube,0)) AS TotCtnCube,
                         MAX(CtnTyp1) AS CtnTyp1,
                         MAX(CtnTyp2) AS CtnTyp2,
                         MAX(CtnTyp3) AS CtnTyp3,
                         MAX(CtnTyp4) AS CtnTyp4,
                         MAX(CtnTyp5) AS CtnTyp5
                  FROM Loadplandetail LPD (NOLOCK)   --TLTING07
                  JOIN ORDERS WITH (NOLOCK) ON ORDERS.orderkey = LPD.Orderkey
                  JOIN PackHeader WITH (NOLOCK)    ON (ORDERS.Orderkey = PackHeader.Orderkey)
                  WHERE LPD.LoadKey = @c_LoadKey AND LPD.Orderkey <> ''
                  --FROM PackHeader WITH (NOLOCK)
                  --JOIN ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey = PackHeader.Orderkey)
                  --WHERE ORDERS.LoadKey = @c_LoadKey
                  GROUP BY ORDERS.LoadKey) AS PH ON PH.LoadKey = LOADPLAN.LoadKey
           WHERE LOADPLAN.LoadKey = @c_LoadKey
      END

     FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_Loadkey
  END
  CLOSE CUR_PACKINFO_CARTON
  DEALLOCATE CUR_PACKINFO_CARTON
----------------------------------------------------------------------
--- SOS140791 Capture PackHeader Summary - Carton Information - End
----------------------------------------------------------------------
   --(Wan05) - START
   CREATE Table #TempErrorRpt
    (    SeqNo    INT   IDENTITY (1,1)
      ,  CBOLKEY  INT
      ,  MBOLKey  NVARCHAR(10)
      ,  Type     NVARCHAR(10)
      ,  LineText NVARCHAR(4000) )

   DECLARE @c_ErrRptType NVARCHAR(10)
         , @c_ErrText    NVARCHAR(2000)
         , @c_MBOL       NVARCHAR(10)

   SET @c_ErrRptType = ''
   SET @c_ErrText    = ''
   SET @c_MBOL       = ''

   IF @n_CBOLKey = 0
   BEGIN
      INSERT INTO #TempErrorRpt (CBOLKEY, MBOLKey, Type, LineText)
      SELECT @n_CBOLKey
            ,MBOLKey
            ,Type
            ,LineText
      FROM MBOLErrorReport WITH (NOLOCK)
      WHERE MBOLKey = @c_MBOLKey
      AND   Type IN ('ERRORMSG', 'WARNINGMSG')
      ORDER BY SeqNo
   END
   ELSE
   BEGIN
      INSERT INTO #TempErrorRpt (CBOLKEY, MBOLKey, Type, LineText)
      SELECT @n_CBOLKey
            ,ER.MBOLKey
            ,ER.Type
            ,ER.LineText
      FROM MBOLErrorReport ER WITH (NOLOCK)
      JOIN MBOL        MB WITH (NOLOCK) ON (ER.MBOLKey = MB.MBolkey)
      WHERE MB.CBOLKey = @n_CBOLKey
      AND   ER.Type IN ('ERRORMSG', 'WARNINGMSG')
   END

   SELECT @c_ErrRptType = ISNULL(MIN(Type),'')
   FROM #TempErrorRpt

   SET @c_ErrMsg    = ''
   IF @c_ErrRptType = ''           SET @b_ReturnCode = 0
   IF @c_ErrRptType = 'ERRORMSG'   SET @b_ReturnCode = -1
   IF @c_ErrRptType = 'WARNINGMSG' SET @b_ReturnCode = 1

   IF @b_ReturnCode IN (-1, 1)
   BEGIN
      DECLARE CUR_ErrRpt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ISNULL(RTRIM(MBOLKey),'')
            ,ISNULL(RTRIM(LineText),'')
      FROM #TempErrorRpt (NOLOCK)
      WHERE Type = @c_ErrRptType
      ORDER BY SeqNo

      OPEN CUR_ErrRpt
      FETCH NEXT FROM CUR_ErrRpt INTO @c_MBOL, @c_ErrText
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_ErrRptType = 'WARNINGMSG'
         BEGIN
            SET @c_ErrMsg = @c_ErrMsg + 'MBOL#: ' + @c_MBOL + ' - ' + @c_ErrText + master.dbo.fnc_GetCharASCII(13)
         END
         ELSE
         BEGIN
            SET @c_ErrMsg = @c_ErrMsg + @c_ErrText
            BREAK
         END

         FETCH NEXT FROM CUR_ErrRpt INTO @c_MBOL, @c_ErrText
      END
      CLOSE CUR_ErrRpt
      DEALLOCATE CUR_ErrRpt
   END
   --(Wan05) - END

   SET @d_step5 = GETDATE() - @d_step5 -- (tlting01)


-- TraceInfo (tlting01) - Start
--IF @n_TraceFlag = 1
--BEGIN
--   SET @d_endtime = GETDATE()
--   INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,
--                          Step1, Step2, Step3, Step4, Step5,
--                          Col1, Col2, Col3, Col4, Col5)
--   VALUES
--      (RTRIM(@c_TraceName), @d_starttime, @d_endtime
--      ,CONVERT(NCHAR(12),@d_endtime - @d_starttime ,114)
--      ,CONVERT(NCHAR(12),@d_step1,114)
--      ,CONVERT(NCHAR(12),@d_step2,114)
--      ,CONVERT(NCHAR(12),@d_step3,114)
--      ,CONVERT(NCHAR(12),@d_step4,114)
--      ,CONVERT(NCHAR(12),@d_step5,114)
--      ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

--      SET @d_step1 = NULL
--      SET @d_step2 = NULL
--      SET @d_step3 = NULL
--      SET @d_step4 = NULL
--      SET @d_step5 = NULL
-- END
-- TraceInfo (tlting01) - End


DROP TABLE #MBOLCheck
DROP TABLE #ConsoPick
DROP TABLE #OrderPick

-- end procedure

GO