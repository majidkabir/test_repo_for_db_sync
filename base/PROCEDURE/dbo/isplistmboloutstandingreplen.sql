SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispListMBOLOutstandingReplen                       */
/* Creation Date:  09-Oct-2010                                          */
/* Copyright: IDS                                                       */
/* Written by:  SHONG                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:  @c_MBOLKey  - (MBOLKey)                           */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  Report                                               */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  r_dw_mbol_outstanding_replen_task                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-Oct-2012  Leong     1.1   SOS# 258237 - Insert TraceInfo          */
/* 16-Oct-2012  James     1.2   Add mbolkey                             */
/* 11-Aug-2016  NJOW01    1.3   374687-Allowoverallocations storerconfig*/
/*                              control by facility                     */
/************************************************************************/

CREATE PROC [dbo].[ispListMBOLOutstandingReplen]
   @c_MBOLKey        nvarchar(10)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_ReturnCode    INT,
      @n_err           int ,
      @c_errmsg        nvarchar(255)
    , @c_TraceName     NVARCHAR(80) -- SOS# 258237

   SET @c_TraceName = 'ispListMBOLOutstandingReplen - ' + ISNULL(RTRIM(@c_MBOLKey),'')

--   DECLARE    @c_starttime    datetime,
--              @c_endtime      datetime,
--              @c_step1        datetime,
--              @c_step2        datetime,
--              @c_step3        datetime,
--              @c_step4        datetime,
--              @c_step5        datetime
--
--   DECLARE @n_Continue int
--
--
--   DECLARE @c_CartonGroup char(10), -- SOS140791
--           @c_Loadkey     char(10)  -- SOS140791
--
--   -- (Vicky01)- Start
--   DECLARE @cCheckAllToteScan char(1),
--           @nTotalPackTote int,
--           @nTotalScanTote int,
--           @cCheckShortPick char(1) -- (Vicky02)
--   -- (Vicky01) - End
--
--   IF OBJECT_ID('tempdp..#MBOLCheck') IS NOT NULL
--      DROP TABLE #MBOLCheck
--
--   CREATE Table #MBOLCheck
--      (StorerKey        char(15) NULL,
--       OrderKey         char(10) NULL,
--       OrderLineNumber  char(5)  NULL,
--       Type             char(10) NULL,
--       QtyAllocated     int NULL,
--       QtyPicked        int NULL,
--       LoadKey          char(10) NULL,
--       Facility         char(5) NULL,
--       UserDefine08     char(10) NULL,
--       Status           char(10) NULL,
--       OriginalQty      int NULL,
--       ShippedQty       int NULL,
--       PickSlipNo       char(10) NULL,
--       PickSlipStatus   char(10) NULL)
--
--
--   INSERT INTO #MBOLCheck
--   SELECT DISTINCT ORDERS.StorerKey,
--          ORDERDETAIL.OrderKey,
--          ORDERDETAIL.OrderLineNumber,
--    ORDERS.Type,
--          ORDERDETAIL.QtyAllocated,
--          ORDERDETAIL.QtyPicked,
--          ORDERDETAIL.LoadKey,
--          ORDERS.Facility,
--          ORDERS.UserDefine08,
--          ORDERDETAIL.Status,
--          ORDERDETAIL.OriginalQty,
--          ORDERDETAIL.ShippedQty,
--          PickSlipNo = CASE WHEN OrderPick.PickSlipNo IS NULL THEN ISNULL(ConsoPick.PickSlipNo, '')
--               Else ISNULL(OrderPick.PickSlipNo, '') END,
--          PickSlipStatus = CASE WHEN OrderPick.PickSlipNo IS NULL THEN ISNULL(ConsoPick.Status, '')
--               Else ISNULL(OrderPick.Status, '') END
--   FROM MBOLDETAIL (NOLOCK)
--   JOIN ORDERDETAIL (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey AND MBOLDETAIL.MBOLKey = OrderDetail.MBOLKey
--                   AND MBOLDETAIL.Loadkey = ORDERDETAIL.Loadkey) -- SOS39592
--   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = OrderDetail.OrderKey)
--   LEFT OUTER JOIN (SELECT PickHeaderKey as PickSlipNo, PickHeader.OrderKey, PackHeader.Status FROM PickHeader (NOLOCK)
--                    JOIN MBOLDetail (NOLOCK) ON MBOLDetail.OrderKey = PickHeader.OrderKey
--                    JOIN PACKHeader (NOLOCK) ON (PackHeader.PickSlipNo = PickHeader.PickHeaderKey)
--           WHERE PickHeader.OrderKey IS NOT NULL AND PickHeader.OrderKey <> ''
--                    AND   MBOLDETAIL.MBOLKey = @c_MBOLKey) as OrderPick
--        ON (OrderPick.OrderKey = ORDERS.OrderKey)
--   LEFT OUTER JOIN (SELECT Distinct PickHeaderKey as PickSlipNo, PickHeader.ExternOrderKey as LoadKey,
--                    PackHeader.Status
--                    FROM PickHeader (NOLOCK)
--                    JOIN MBOLDetail (NOLOCK) ON MBOLDetail.LoadKey = PickHeader.ExternOrderKey
--                    JOIN PACKHeader (NOLOCK) ON (PackHeader.PickSlipNo = PickHeader.PickHeaderKey)
--                    WHERE (PickHeader.OrderKey IS NULL OR PickHeader.OrderKey = '')
--                    AND   (PickHeader.ExternOrderKey IS NOT NULL AND PickHeader.ExternOrderKey <> '')
--                    AND   MBOLDETAIL.MBOLKey = @c_MBOLKey) as ConsoPick
--        ON (ConsoPick.LoadKey = ORDERDETAIL.LoadKey)
--   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey

   DECLARE @c_OverAllocationFlag nvarchar(30)

   SET @c_OverAllocationFlag = '0'

   SELECT  @c_OverAllocationFlag = ISNULL(NSQLValue, '0')
   FROM    NSQLCONFIG (NOLOCK)
   WHERE   ConfigKey = 'ALLOWOVERALLOCATIONS'

   IF OBJECT_ID('tempdp..#P') IS NOT NULL
      DROP TABLE #P

   CREATE TABLE #P (
            LOT nvarchar(10) NULL,
            LOC nvarchar(10) NULL,
            ID  nvarchar(18) NULL ,
            StorerKey nvarchar(15) NULL ,
            SKU       nvarchar(20) NULL,
            Qty       int NULL )

   -- Check on the Valid records within the specific MBOLKey.
   IF @c_OverAllocationFlag = '1'
   BEGIN
      -- Check on the Valid records within the specific MBOLKey.
      INSERT INTO #P
      SELECT P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku, SUM(P.Qty) AS Qty
      FROM  ORDERDETAIL O (NOLOCK)
      JOIN  PICKDETAIL P WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON P.OrderKey =  O.OrderKey AND
                              P.OrderLineNumber = O.OrderLineNumber AND P.Status < '9'
      WHERE O.MBOLKEY = @c_MBOLKey
      GROUP BY P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku
   END
   ELSE
   BEGIN
      INSERT INTO #P
      SELECT P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku, SUM(P.Qty) AS Qty
      FROM  ORDERDETAIL OD (NOLOCK)
      JOIN  ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey
      JOIN  PICKDETAIL P WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON P.OrderKey =  OD.OrderKey AND
                              P.OrderLineNumber = OD.OrderLineNumber AND P.Status < '9'
      --JOIN  STORERCONFIG S (NOLOCK) ON (O.Storerkey = S.Storerkey AND S.ConfigKey = 'ALLOWOVERALLOCATIONS' AND S.sValue = '1' )
      JOIN  STORERCONFIG S (NOLOCK) ON (O.Storerkey = S.Storerkey AND S.ConfigKey = 'ALLOWOVERALLOCATIONS' AND S.sValue = '1' AND (S.Facility = o.Facility OR ISNULL(S.facility,'')='') ) --NJOW01
      WHERE O.MBOLKEY = @c_MBOLKey
 GROUP BY P.LOT, P.LOC, P.ID, P.Storerkey, P.Sku
   END

   IF OBJECT_ID('tempdp..#L') IS NOT NULL
      DROP TABLE #L

   SELECT L.LOT, L.LOC, L.ID, L.Storerkey, L.Sku, L.Qty AS Qty INTO #L
   FROM LOTxLOCxID L (NOLOCK)
   JOIN #P P ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku)

   -- SOS# 258237
   -- INSERT INTO TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5
   --                       , Col1, Col2, Col3, Col4, Col5, TotalTime )
   -- SELECT @c_TraceName, GETDATE()
   --      , L.Lot, L.Loc, L.Id, L.StorerKey, L.Sku, L.Qty, L.QtyAllocated, L.QtyPicked
   --      , L.QtyExpected, L.PendingMoveIn, L.QtyReplen
   -- FROM LOTxLOCxID L WITH (NOLOCK)
   -- JOIN #P P ON (L.Lot = P.Lot AND L.Loc = P.Loc AND L.Id = P.Id
   --               AND L.StorerKey = P.StorerKey AND L.Sku = P.Sku)
   -- WHERE L.QtyExpected > 0

   IF OBJECT_ID('tempdp..#P1') IS NOT NULL
      DROP TABLE #P1

   -- SOS# 229555
   -- INSERT INTO TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5
   --                       , Col1, Col2, Col3, Col4, Col5, TotalTime )
   -- SELECT 'ispListMBOLOutstandingReplen', GetDate(), P1.OrderKey, MBD.OrderKey, P1.Storerkey, P1.Sku
   --       , P1.LOT, P1.LOC, P1.ID, P1.Qty, P1.ShipFlag, P1.Status, @c_MBOLKey
   -- FROM PICKDETAIL P1 (NOLOCK)
   -- JOIN #P P ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
   -- LEFT OUTER JOIN (SELECT ORDERKEY FROM MBOLDETAIL (NOLOCK) WHERE MBOLKEY = @c_MBOLKey) as MBD
   --   ON P1.OrderKey = MBD.OrderKey

   -- Check on the records not within the specific MBOLKey.
   SELECT P1.LOT, P1.LOC, P1.ID, P1.Storerkey, P1.Sku, SUM(ISNULL(P1.Qty, 0)) as Qty INTO #P1
   FROM PICKDETAIL P1 (NOLOCK)
   JOIN #P P ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
   AND P1.SHIPFLAG = 'Y' and P1.Status < '9'
   LEFT OUTER JOIN (SELECT ORDERKEY FROM MBOLDETAIL (NOLOCK) WHERE MBOLKEY = @c_MBOLKey) as MBD
                   ON P1.OrderKey = MBD.OrderKey
   WHERE ISNULL(RTRIM(MBD.OrderKey),'') = ''
   GROUP BY P1.LOT, P1.LOC, P1.ID, P1.Storerkey, P1.Sku

   -- SOS# 229555
   -- INSERT INTO TraceInfo ( TraceName, TimeIn, Step5, Col1, Col2, Step3, Step4, Col3, Col4, TotalTime )
   -- SELECT 'ispListMBOLOutstandingReplen-Result', GetDate(), L.LOT, L.LOC, L.ID, L.Storerkey, L.Sku, L.Qty, P.Qty, @c_MBOLKey
   -- FROM #P P
   -- JOIN #L L ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku)
   -- LEFT OUTER JOIN #P1 P1 ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
   -- WHERE P.Qty > (L.Qty - ISNULL(P1.Qty,0))

   -- Overall check based on the specific MBOLKey.
   SELECT L.LOT, L.LOC, L.ID, L.Storerkey, L.Sku, L.Qty AS L_Qty, P.Qty As P_Qty, @c_MBOLKey
   FROM #P P
   JOIN #L L ON (L.LOT = P.LOT AND L.LOC = P.LOC AND L.ID = P.ID AND L.Storerkey = P.Storerkey AND L.Sku = P.Sku)
   LEFT OUTER JOIN #P1 P1 ON (P.LOT = P1.LOT AND P.LOC = P1.LOC AND P.ID = P1.ID AND P.Storerkey = P1.Storerkey AND P.Sku = P1.Sku)
   WHERE P.Qty > (L.Qty - ISNULL(P1.Qty,0))

END

GO