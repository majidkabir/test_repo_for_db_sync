SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : ispGenOWORDALLOC_E1                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Replicate base on ispGenOWORDALLOC - Ver 1.1               */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 06-Jun-2002  SHONG      Should SUM the qty cause if there is         */
/*                         duplicate line, it will pass thru if not     */
/*                         GROUP BY externline, lottable02, sku         */
/* 20-Feb-2003  June       FBR9706 (PGD PH - Post Pick Invoicing        */
/*                         Trigger)                                     */
/*                         - Include 'OWORDPICK' in the Tablename.      */
/*                         - OUTPUT Wavekey AS Loadkey for 'OWPREPICK', */
/*                         otherwise uses Loadkey.                      */
/* 04-Sep-2003  June       FBR14179 (PGD TH - Post Ship Invoicing)      */
/*                         - if Storer Configflag 'PICKCFMDATE' is ON,  */
/*                         invoice date will be based ON Scanoutdate.   */
/*                         Otherwise, it will based ON LP date          */
/*                         (lpuserdefdate01).                           */
/* 03-Oct-2005  YokeBeen   Added Header List.                           */
/* 15-Apr-2007  Shong      Performance Tuning - Replace SELECT WITH     */
/*                         Cursor Loop (Shong01)                        */
/* 14-Jul-2008  Shong      Fixing Bug ON SQL2005 - Transmitflag = '1'   */
/* 25-Mar-2010  KC         SOS 165424 To retrieve PickDetail loc (KC01) */
/* 30-May-2013  SWYep      E1 Trading StoreKey Filter (SW01)            */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */
/************************************************************************/

CREATE PROC [dbo].[ispGenOWORDALLOC_E1]
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_Continue int

   DECLARE @c_ListName_E1TStorer NVARCHAR(10)         --(SW01)
   DECLARE @c_Short_E1TStorer NVARCHAR(10)            --(SW01)

   SET @c_ListName_E1TStorer = 'E1TStorer'            --(SW01)
   SET @c_Short_E1TStorer = 'E1T'                     --(SW01)   
   
   SELECT @n_Continue = 1

   SET NOCOUNT ON
   IF NOT EXISTS( SELECT 1 FROM TransmitLog TL WITH (NOLOCK)
                   WHERE TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK') AND
                   TL.TransmitFlag = '1')
   BEGIN
      SELECT @n_Continue = 3
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- Delete those extern Orders already exists
      DELETE OWORDALLOC
      FROM   OWORDALLOC
      INNER JOIN Orders WITH (NOLOCK)
         ON Orders.ExternOrderKey = OWORDALLOC.ExternOrderkey
      INNER JOIN TransmitLog TL WITH (NOLOCK)
         ON TL.Key1 = ORDERS.OrderKey AND TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK') AND
            TL.TransmitFlag = '1'
      WHERE NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                                                       --(SW01)
         WHERE CDL.Code = Orders.StorerKey AND CDL.ListName = @c_ListName_E1TStorer AND CDL.Short = @c_Short_E1TStorer )   --(SW01)            
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- insert allocated order details into table
      INSERT INTO OWORDALLOC (ExternOrderkey,ExternOrderkey2,ExternOrderKey3,ExternLineNo,SKU,UOM,Storerkey,Lottable02,
                              Status,PickCode,LoadKey,Qty,Loc,Deliverydate,NewLineNo,TableName,DiscreteFlag,ActionCode,
                              TLDate,TransmitFlag,TransmitLogKey)
      SELECT OrderDetail.ExternOrderkey,
             OrderDetail.ExternOrderkey ExternOrderkey2,
             OrderDetail.ExternOrderkey ExternOrderKey3 ,
             OrderDetail.ExternLineNo AS ExternLineNo,
             OrderDetail.SKU, OrderDetail.UOM,
             OrderDetail.Storerkey,
             LA.Lottable02,
             OrderDetail.Status,
             PickCode,
             CASE WHEN TL.Tablename LIKE 'OWDPREPICK%' THEN ISNULL(Orders.Userdefine09, '')
                  ELSE ISNULL(OrderDetail.LoadKey, '')
             END AS LoadKey, -- Modify by June 13.Aug.02 - To O/P Wavekey If DPREPICK/DPREPICK+1 is ON
             CASE WHEN OrderDetail.UOM = Pack.PackUOM1 THEN ISNULL(SUM(PickDetail.QTY),0)/Pack.CASECnt
                  WHEN OrderDetail.UOM = Pack.PackUOM2 THEN ISNULL(SUM(PickDetail.QTY),0)/Pack.InnerPack
                  WHEN OrderDetail.UOM = Pack.PackUOM4 THEN ISNULL(SUM(PickDetail.QTY),0)/Pack.Pallet
             Else ISNULL(SUM(PickDetail.QTY),0)
             END AS Qty,
             --' ' AS Loc,   --(KC01)
             ISNULL(RTRIM(LOC.HostWHCode),' ') AS Loc,  --(KC01)
             NULL AS Deliverydate,
             ISNULL(NewLineNo, '') AS NewLineNo,
             TL.TableName,
             Orders.Userdefine08 AS DiscreteFlag,
             CASE WHEN SUM(ISNULL(PickDetail.Qty,0)) = 0 THEN 'D'
                  Else ISNULL(ActionCode, 'C')
             END AS ActionCode,
             TL.AddDate AS TLDate,
             '0' AS TransmitFlag,
             MAX(TransmitLogKey)
      FROM OrderDetail WITH (NOLOCK)
      INNER JOIN TransmitLog TL WITH (NOLOCK)
         ON TL.Key1 = OrderKey AND TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK') AND
            TL.TransmitFlag = '1'
      INNER JOIN PickDetail WITH (NOLOCK)
         ON (PickDetail.OrderKey=OrderDetail.OrderKey AND
             PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
      INNER JOIN Pack WITH (NOLOCK)
         ON (OrderDetail.Packkey = Pack.PackKey)
      INNER JOIN Exe2OW_allocpickship Exe2Ow
         ON (Exe2Ow.ExternOrderkey = OrderDetail.ExternOrderkey AND
             Exe2Ow.ExternLineNo = OrderDetail.ExternLineno)
      INNER JOIN Loc WITH (NOLOCK)
         ON (PickDetail.Loc = Loc.Loc)
      INNER JOIN LOTAttribute LA WITH (NOLOCK)
         ON (PickDetail.LOT = LA.LOT AND LA.Lottable02 = exe2ow.Batchno )
      INNER JOIN ORDERS WITH (NOLOCK)
         ON (ORDERS.OrderKey = OrderDetail.OrderKey)
      WHERE NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                                                       --(SW01)
         WHERE CDL.Code = ORDERS.StorerKey AND CDL.ListName = @c_ListName_E1TStorer AND CDL.Short = @c_Short_E1TStorer )   --(SW01)          
      GROUP BY OrderDetail.ExternOrderKey, OrderDetail.ExternLineNo, OrderDetail.SKU,
               OrderDetail.UOM, OrderDetail.Storerkey, LA.Lottable02, OrderDetail.Status,PickCode,
               OrderDetail.LoadKey, ISNULL(RTRIM(LOC.HostWHCode),' '), TL.TableName, Orders.Userdefine08, NewLineNo,    --(KC01)
               ActionCode, TL.AddDate, Pack.CASEcnt, Pack.PackUOM1, Pack.InnerPack, Pack.PackUOM2,
               Pack.Pallet, Pack.PackUOM4, Orders.Userdefine09
   END -- continue = 1

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      -- Insert Unallocated Order Detail
      INSERT INTO OWORDALLOC (ExternOrderkey,ExternOrderkey2,ExternOrderKey3,ExternLineNo,SKU,UOM,Storerkey,
                              Lottable02,Status,PickCode,LoadKey,Qty,Loc,Deliverydate,NewLineNo,TableName,
                              DiscreteFlag,ActionCode,TLDate,TransmitFlag,TransmitLogKey)
      SELECT OrderDetail.ExternOrderkey,
             OrderDetail.ExternOrderkey ExternOrderkey2,
             OrderDetail.ExternOrderkey ExternOrderKey3 ,
             OrderDetail.ExternLineNo AS ExternLineNo,
             OrderDetail.SKU,
             OrderDetail.UOM,
             OrderDetail.Storerkey, ' ',
             OrderDetail.Status,
             '' AS PickCode,
             CASE WHEN TL.Tablename LIKE 'OWDPREPICK%' THEN ISNULL(Orders.Userdefine09, '')
                  ELSE ISNULL(OrderDetail.LoadKey, '')
             END AS LoadKey, -- Modify by June 13.Aug.02 - To O/P Wavekey If DPREPICK/DPREPICK+1 is ON
             0 AS Qty,
             ' ' AS Loc,
             NULL AS Deliverydate,
             ISNULL(NewLineNo, '') AS NewLineNo,
             TL.TableName,
             Orders.Userdefine08 AS DiscreteFlag,
             'D' AS ActionCode,
             TL.AddDate AS TLDate,
             '0' AS TransmitFlag,
             TransmitLogKey
      FROM OrderDetail WITH (NOLOCK)
      INNER JOIN TransmitLog TL WITH (NOLOCK)
         ON (TL.Key1 = OrderKey AND TL.TableName IN ('OWORDALLOC', 'OWDPREPICK', 'OWORDPICK') AND
             TL.TransmitFlag = '1' )
      INNER JOIN ORDERS WITH (NOLOCK)
         ON (ORDERS.OrderKey = OrderDetail.OrderKey)
      INNER JOIN Exe2OW_allocpickship Exe2Ow
         ON (Exe2Ow.ExternOrderkey = OrderDetail.ExternOrderkey AND
             Exe2Ow.ExternLineNo = OrderDetail.ExternLineno)
      WHERE (OrderDetail.QtyAllocated + QtyPicked + ShippedQty) = 0
      AND NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                                                         --(SW01)
         WHERE CDL.Code = ORDERS.StorerKey AND CDL.ListName = @c_ListName_E1TStorer AND CDL.Short = @c_Short_E1TStorer )   --(SW01)       
   END -- continue = 1

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE @c_ExternOrderKey NVARCHAR(50),  --tlting_ext
              @c_ExternLineNo   NVARCHAR(10),
              @c_SKU            NVARCHAR(10),
              @c_UOM            NVARCHAR(10),
              @c_StorerKey      NVARCHAR(15),
              @c_Lottable02     NVARCHAR(18),
              @n_Qty            int,
              @c_TransmitLogKey NVARCHAR(10),
              @n_WMS_Qty        int,
              -- SOS14179
              @c_PrevStorerkey  NVARCHAR(10),
              @b_success        int,
              @c_errmsg         NVARCHAR(60),
              @c_authority      NVARCHAR(1),
              @n_err            int

      SELECT @c_ExternOrderKey = SPACE(50)   --tlting_ext
      SELECT @c_PrevStorerkey  = SPACE(10) -- SOS14179

      -- Change By SHONG ON 15-Apr-2007 (Shong01)
      DECLARE CUR_OWORDALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OWORDALLOC.ExternOrderkey,
             OWORDALLOC.Storerkey
      FROM   OWORDALLOC WITH (NOLOCK)
      INNER JOIN ORDERDETAIL WITH (NOLOCK)                                             --(SW01)
         ON OWORDALLOC.ExternOrderKey = ORDERDETAIL.ExternOrderKey                     --(SW01)
         AND  OWORDALLOC.ExternLineNo = ORDERDETAIL.ExternLineNo                       --(SW01)
      INNER JOIN ORDERS WITH (NOLOCK)                                                  --(SW01)
         ON ORDERS.OrderKey = ORDERDETAIL.OrderKey                                     --(SW01)
      WHERE  OWORDALLOC.TransmitFlag = '0'                                             --(SW01)
      AND NOT EXISTS ( SELECT 1 FROM Codelkup AS CDL WITH (NOLOCK)                     --(SW01)
         WHERE CDL.Code = ORDERS.StorerKey AND CDL.ListName = @c_ListName_E1TStorer    --(SW01)
         AND CDL.Short = @c_Short_E1TStorer )                                          --(SW01)
      ORDER BY OWORDALLOC.ExternOrderKey

      OPEN CUR_OWORDALLOC
      FETCH NEXT FROM CUR_OWORDALLOC INTO @c_ExternOrderKey, @c_storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- change by Shong
         -- Date: 06-06-2002
         -- Should SUM the qty cause if there is duplicate line, it will pass thru if not GROUP BY externline, lottable02, sku
         DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT  ExternLineNo, -- StorerKey, SOS14179
                    SKU, Lottable02, SUM(Qty) AS Qty, TransmitLogKey
            FROM    OWORDALLOC WITH (NOLOCK)
            WHERE   TransmitFlag = '0'
            AND     ExternOrderKey = @c_ExternOrderKey
            GROUP BY ExternLineNo, StorerKey, SKU, Lottable02, TransmitLogKey

         OPEN CUR1

         FETCH NEXT FROM CUR1 INTO @c_ExternLineNo, -- @c_Storerkey, SOS14179
                                   @c_SKU, @c_Lottable02, @n_Qty, @c_TransmitLogKey
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n_Qty > 0
            BEGIN
               SELECT @n_WMS_Qty =
               CASE OrderDetail.UOM WHEN Packuom1 THEN FLOOR( SUM(PickDetail.Qty) / CASEcnt)
                     WHEN Packuom2 THEN Floor( SUM(PickDetail.Qty) / innerpack)
                     WHEN Packuom3 THEN SUM(PickDetail.Qty)
                     WHEN Packuom4 THEN Floor(SUM(PickDetail.Qty) / pallet)
               END
               FROM OrderDetail WITH (NOLOCK)
               JOIN PickDetail WITH (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey AND
                                                 PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
               JOIN PACK WITH (NOLOCK) ON (PACK.PackKey = OrderDetail.PackKey)
               JOIN LOTAttribute WITH (NOLOCK) ON (LOTAttribute.LOT = PickDetail.LOT)
               WHERE OrderDetail.StorerKey = @c_StorerKey
               AND   OrderDetail.ExternOrderKey = @c_ExternOrderKey
               AND   OrderDetail.ExternLineNo = @c_ExternLineNo
               AND   LotAttribute.StorerKey = OrderDetail.StorerKey
               AND   LotAttribute.SKU = OrderDetail.SKU
               AND   LotAttribute.Lottable02 = @c_Lottable02
               GROUP BY OrderDetail.UOM, PACKUOM1, PACKUOM2, PACKUOM3, PACKUOM4, InnerPack, CASECnt, Pallet

               IF @n_WMS_Qty IS NULL
                  SELECT @n_WMS_Qty = 0

               IF @n_WMS_Qty <> @n_Qty
               BEGIN
                 -- Wrong Qty, update flag to 5 (Invalid)
                  SELECT @c_StorerKey '@c_StorerKey', @c_ExternOrderKey '@c_ExternOrderKey', @n_WMS_Qty, '@n_WMS_Qty'
                         , @c_ExternLineNo '@c_ExternLineNo', @c_Lottable02 '@c_Lottable02'

                  UPDATE OWORDALLOC
                     SET TransmitFlag = '5'
                  WHERE TransmitFlag = '0'
                  AND   ExternOrderKey = @c_ExternOrderKey

                  BREAK
               END
            END

            FETCH NEXT FROM CUR1 INTO @c_ExternLineNo, -- @c_Storerkey, SOS14179
                                      @c_SKU, @c_Lottable02, @n_Qty, @c_TransmitLogKey
         END -- while fetch status <> -1
         CLOSE CUR1
         DEALLOCATE CUR1

         -- SOS14179 (TH Post-Ship Invoice)
         -- Start - Add by June 4.SEP.03
         IF @c_Storerkey <> @c_PrevStorerkey
         BEGIN
            SELECT @c_PrevStorerkey = @c_storerkey
            EXECUTE nspGetRight NULL, -- facility
                    @c_Storerkey,     -- Storerkey
                    NULL,             -- Sku
                    'PICKCFMDATE',    -- Configkey
                    @b_success   OUTPUT,
                    @c_authority OUTPUT,
                    @n_err       OUTPUT,
                    @c_errmsg    OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'ispGenOWORDALLOC_E1' + dbo.fnc_RTrim(@c_errmsg)
            END

            IF @b_success = 1 AND @c_authority = '1'
            BEGIN
               -- AS request by OW, use Pick Confirm date for the delivery / Invoice date
               UPDATE OWORDALLOC
               SET Deliverydate = CONVERT(DATETIME, CONVERT(CHAR, ISNULL(P.ScanOutDate, GETDATE()), 106))
               FROM  PICKINGINFO P (NOLOCK), PICKHEADER PH (NOLOCK), ORDERS (NOLOCK)
               WHERE P.Pickslipno = PH.Pickheaderkey
               AND   PH.ExternOrderkey = ORDERS.Loadkey
               AND   ORDERS.Externorderkey = OWORDALLOC.ExternOrderkey
               AND   OWORDALLOC.TransmitFlag = '0'
               AND   OWORDALLOC.Deliverydate IS NULL
               AND   OWORDALLOC.Tablename IN ('OWORDALLOC', 'OWORDPICK')
               AND   OWORDALLOC.Storerkey = @c_storerkey
            END
            ELSE
            BEGIN
               -- AS request by OW, they need the delivery date
               UPDATE OWORDALLOC
                  SET Deliverydate = LOADPLAN.lpuserdefdate01
               FROM Loadplan (NOLOCK)
               WHERE Loadplan.LoadKey = OWORDALLOC.Loadkey
               AND   OWORDALLOC.TransmitFlag = '0'
               AND   OWORDALLOC.Deliverydate IS NULL
               AND   OWORDALLOC.Tablename IN ('OWORDALLOC', 'OWORDPICK') -- Modify by June (13.Aug.02 & 20.Feb.03)
               AND   OWORDALLOC.Storerkey = @c_storerkey
            END
         END -- <> @c_PrevStorerkey
         -- END (SOS14179 - TH Post-Ship Invoice)
         FETCH NEXT FROM CUR_OWORDALLOC INTO @c_ExternOrderKey, @c_storerkey
      END -- While @@fetch_status <> -1
      CLOSE CUR_OWORDALLOC
      DEALLOCATE CUR_OWORDALLOC

      SET ROWCOUNT 0
        /*
        -- Remark by June, SOS14179 - Move to above
            -- AS request by OW, they need the delivery date
            UPDATE OWORDALLOC
               SET Deliverydate = LOADPLAN.lpuserdefdate01
            FROM Loadplan (NOLOCK)
            WHERE Loadplan.LoadKey = OWORDALLOC.Loadkey
            AND   OWORDALLOC.TransmitFlag = '0'
            AND   OWORDALLOC.Deliverydate IS NULL
        AND   OWORDALLOC.Tablename IN ('OWORDALLOC', 'OWORDPICK') -- Modify by June (13.Aug.02 & 20.Feb.03)
        */
   END -- if continue = 1
   SET NOCOUNT OFF
END -- procedure

GO