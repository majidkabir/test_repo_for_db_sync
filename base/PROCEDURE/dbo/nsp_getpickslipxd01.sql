SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Stored Proc : nsp_GetPickSlipXD01                                           */
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose: PickSlip Report                                                    */
/*                                                                             */
/* Called By: r_dw_print_pickxdorder01                                         */
/*                                                                             */
/* PVCS Version: 1.4                                                           */
/*                                                                             */
/* Version: 5.4                                                                */
/*                                                                             */
/* Updates:                                                                    */
/* Date        Author      Purposes                                            */
/* 2007-04-05  ONG01       SOS#71903 - Add Column POTYPE                       */
/* 2007-07-11  LEONG       SOS#79918 - Change Join TABLE                       */
/* 2008-05-08  TLTING      Avoid return multiple result in LEFT JOIN           */
/* 2011-08-10  NJOW01      222323-Pickslip Format for X-dock Modification      */
/* 2012-05-07  NJOW02      243364-Add PO.Notes                                 */
/* 2012-07-16  Leong       SOS# 250526 - Update with EditDate & EditWho.       */
/*******************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipXD01] (@c_RefKey NVARCHAR(20), @c_Type NVARCHAR(2))
AS
BEGIN
-- Type = P for ExternPOKey, L for LoadKey
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey   NVARCHAR(10),
           @n_continue        Int,
           @c_errmsg          NVARCHAR(255),
           @b_success         Int,
           @n_err             Int,
           @c_Sku             NVARCHAR(20),
           @c_FirstTime       NVARCHAR(1),
           @c_row             NVARCHAR(10),
           @c_PrintedFlag     NVARCHAR(1),
           @c_StorerKey       NVARCHAR(15),
           @c_skudescr        NVARCHAR(60),
           @n_Casecnt         Float,
           @n_innerpack       Float,
           @c_recvby          NVARCHAR(18),
           @n_rowid           Int,
           @n_starttcnt       Int

   CREATE TABLE #TEMPPICKDETAIL (
         PickDetailKey     NVARCHAR(18),
         OrderKey          NVARCHAR(10),
         OrderLineNumber   NVARCHAR(5),
         StorerKey         NVARCHAR(15),
         Sku               NVARCHAR(20),
         Qty               Int,
         Lot               NVARCHAR(10),
         Loc               NVARCHAR(10),
         ID                NVARCHAR(18),
         Packkey           NVARCHAR(10),
         PickslipNo        NVARCHAR(10) NULL,
         PrintedFlag       NVARCHAR(1))

   CREATE TABLE #TEMPPICKSKU (
         Rowid       Int IDENTITY(1,1),
         StorerKey   NVARCHAR(20),
         Sku         NVARCHAR(15))

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT
   SELECT @c_row = '0'

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, XD - CrossDock
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK)
             WHERE ExternOrderKey = @c_RefKey
             AND   Zone = 'XD')
   BEGIN
      SELECT @c_FirstTime = 'N'

      IF EXISTS (SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_RefKey AND Zone = 'XD'
                 AND PickType = '0')
      BEGIN
         SELECT @c_PrintedFlag = 'N'
      END
      ELSE
      BEGIN
         SELECT @c_PrintedFlag = 'Y'
      END

      -- Uses PickType as a Printed Flag
      BEGIN TRAN
      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL
      WHERE ExternOrderKey = @c_RefKey
      AND   Zone = 'XD'
      AND   PickType = '0'

      IF @@ERROR = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
         SELECT @n_continue = 3
         SELECT @n_err = 63314
         SELECT @c_errmsg = CONVERT(Char(250), @n_err)
         SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update PickHeader Failed. (nsp_GetPickSlipXD01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF ISNULL(RTRIM(@c_Type),'') = 'P'
      BEGIN
         INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, StorerKey, Sku, Qty,
                                      Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag)
         SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.StorerKey, PD.Sku, PD.Qty,
                PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag
           FROM ORDERDETAIL OD (NOLOCK), PICKDETAIL PD (NOLOCK)
          WHERE PD.ORDERKEY = OD.ORDERKEY
            AND PD.ORDERLINENUMBER = OD.ORDERLINENUMBER
            AND OD.EXTERNPOKEY = @c_RefKey
            AND PD.STATUS < '5'
         ORDER BY PD.Pickdetailkey
      END
      ELSE
      BEGIN
         INSERT INTO #TEMPPICKDETAIL (Pickdetailkey, OrderKey, OrderLinenumber, StorerKey, Sku, Qty,
                                      Lot, Loc, ID, Packkey, PickSlipNo, PrintedFlag)
         SELECT PD.Pickdetailkey, PD.OrderKey, PD.OrderLineNumber, PD.StorerKey, PD.Sku, PD.Qty,
                PD.Lot, PD.Loc, PD.ID, PD.Packkey, PD.PickSlipNo, @c_PrintedFlag
           FROM LOADPLANDETAIL LPD (NOLOCK), PICKDETAIL PD (NOLOCK)
          WHERE PD.ORDERKEY = LPD.ORDERKEY
            AND LPD.LOADKEY = @c_RefKey
            AND PD.STATUS < '5'
         ORDER BY PD.Pickdetailkey
      END

      IF @c_FirstTime = 'Y'
      BEGIN
         INSERT INTO #TEMPPICKSKU (StorerKey, Sku)
         SELECT DISTINCT StorerKey, Sku
           FROM #TEMPPICKDETAIL
         ORDER BY StorerKey, Sku

         SELECT @n_rowid = 0

         WHILE 1=1
         BEGIN
            SELECT @n_rowid = MIN(rowid)
              FROM #TEMPPICKSKU
             WHERE Rowid > @n_rowid

            IF ISNULL(@n_rowid, 0) = 0
            BEGIN
               BREAK
            END

            SELECT @c_StorerKey = StorerKey, @c_Sku = Sku
              FROM #TEMPPICKSKU
             WHERE Rowid = @n_rowid

            EXECUTE nspg_GetKey
                     'PICKSLIP',
                     9,
                     @c_pickheaderkey OUTPUT,
                     @b_success       OUTPUT,
                     @n_err           OUTPUT,
                     @c_errmsg        OUTPUT

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               BREAK
            END

            IF @c_Type = 'P'
            BEGIN
               SELECT @c_pickheaderkey = 'X' + @c_pickheaderkey
            END
            ELSE
            BEGIN
               SELECT @c_pickheaderkey = 'X' + @c_pickheaderkey
            END

            SELECT @c_row = Convert(Char(10), convert(Int, @c_row) + 1)

            BEGIN TRAN
            INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES (@c_pickheaderkey, @c_row, @c_RefKey, '0', 'XD', '')

            IF @@ERROR = 0
            BEGIN
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN
            END
            ELSE
            BEGIN
               ROLLBACK TRAN
               SELECT @n_continue = 3
               SELECT @n_err = 63315
               SELECT @c_errmsg = CONVERT(Char(250), @n_err)
               SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Insert Into PickHeader Failed. (nsp_GetPickSlipXD01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
               BREAK
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               BEGIN TRAN
               UPDATE #TEMPPICKDETAIL
                  SET PICKSLIPNO = @c_pickheaderkey
                WHERE #TEMPPICKDETAIL.StorerKey = @c_StorerKey
                  AND #TEMPPICKDETAIL.Sku = @c_Sku

               SELECT @n_err = @@ERROR

               IF @n_err = 0
               BEGIN
                  WHILE @@TRANCOUNT > 0
                     COMMIT TRAN
               END
               ELSE
               BEGIN
                  ROLLBACK TRAN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63316
                  SELECT @c_errmsg = CONVERT(Char(250), @n_err)
                  SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
                  BREAK
               END
            END
         END

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            BEGIN TRAN
            UPDATE PICKDETAIL
               SET TRAFFICCOP = NULL,
                   PICKSLIPNO = #TEMPPICKDETAIL.PICKSLIPNO
                 , EditDate = GETDATE(),   -- SOS# 250526
                   EditWho = SUSER_SNAME() -- SOS# 250526
              FROM #TEMPPICKDETAIL (NOLOCK)
             WHERE PICKDETAIL.PICKDETAILKEY = #TEMPPICKDETAIL.PICKDETAILKEY

            SELECT @n_err = @@ERROR

            IF @n_err = 0
            BEGIN
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN
            END
            ELSE
            BEGIN
               ROLLBACK TRAN
               SELECT @n_continue = 3
               SELECT @n_err = 63317
               SELECT @c_errmsg = CONVERT(Char(250),@n_err)
               SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5),@n_err)+': Update PickDetail Failed. (nsp_GetPickSlipXD01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END

            SELECT @c_row = '0'

            BEGIN TRAN
            INSERT INTO RefKeyLookup (OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey)
            SELECT OrderKey, OrderLinenumber, Pickslipno, Pickdetailkey FROM #TEMPPICKDETAIL
            ORDER BY Pickdetailkey

            SELECT @n_err = @@ERROR
            IF @n_err = 0
            BEGIN
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN
            END
            ELSE
            BEGIN
               ROLLBACK TRAN
               SELECT @n_continue = 3
               SELECT @n_err = 63318
               SELECT @c_errmsg = CONVERT(Char(250), @n_err)
               SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': Insert Into RefKeyLookup Failed. (nsp_GetPickSlipXD01)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
         END

      END

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF @c_Type <> 'P'
         BEGIN
            SELECT @c_RefKey = (SELECT DISTINCT OD.EXTERNPOKEY
                                 FROM ORDERDETAIL OD (NOLOCK), #TEMPPICKDETAIL
                                WHERE OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY
                                  AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER)
         END

         SELECT @c_recvby = (SELECT MAX(EDITWHO)
                              FROM RECEIPTDETAIL (NOLOCK)
                             WHERE EXTERNRECEIPTKEY = @c_RefKey)

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN

         SELECT #TEMPPICKDETAIL.*, ISNULL(Sku.DESCR,'') SKUDESCR, OD.EXTERNPOKEY, OH.CONSIGNEEKEY, OH.C_COMPANY,
                OH.Priority, OH.DeliveryDate, OH.NOTES, STORERSODEFAULT.XDockLane,  STORERSODEFAULT.XDockRoute,
                ISNULL(PACK.Casecnt, 0) CASECNT, ISNULL(PACK.Innerpack, 0) Innerpack, @c_recvby
                , ISNULL(PO.POTYPE , '') POTYPE    -- ONG01
                , Sku.RetailSku  --NJOW01
                , CONVERT(NVARCHAR(250),PO.Notes) --NJOW02
           FROM #TEMPPICKDETAIL JOIN ORDERDETAIL OD WITH (NOLOCK)
               ON OD.ORDERKEY = #TEMPPICKDETAIL.ORDERKEY
               AND OD.ORDERLINENUMBER = #TEMPPICKDETAIL.ORDERLINENUMBER
         -- Add by June 30.June.2004, dun display P/S records when Pickheader rec not successfully inserted
           JOIN PICKHEADER PH (NOLOCK) ON PH.Pickheaderkey = #TEMPPICKDETAIL.PickslipNo
           JOIN Sku WITH (NOLOCK)
               ON #TEMPPICKDETAIL.StorerKey = Sku.StorerKey
               AND #TEMPPICKDETAIL.Sku = Sku.Sku
           JOIN PACK WITH (NOLOCK)
               ON Sku.PACKKEY = PACK.PACKKEY
           JOIN ORDERS OH WITH (NOLOCK)
               ON OH.ORDERKEY = OD.ORDERKEY
           LEFT OUTER JOIN STORER WITH (NOLOCK)
               ON STORER.StorerKey = OH.CONSIGNEEKEY
            LEFT OUTER JOIN STORERSODEFAULT
               ON STORER.StorerKey = STORERSODEFAULT.StorerKey
            --LEFT JOIN PO (NOLOCK) ON OH.ExternPOKey = PO.ExternPOkey     -- ONG01
            LEFT JOIN PO (NOLOCK) ON OD.ExternPOKey = PO.ExternPOkey       -- SOS#79918
                                   AND OH.StorerKey = PO.StorerKey         -- TLTING
         ORDER BY #TEMPPICKDETAIL.PICKSLIPNO, STORERSODEFAULT.XDockRoute
      END
   END

   DROP TABLE #TEMPPICKDETAIL
   DROP TABLE #TEMPPICKSKU

   IF @n_continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipXD01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

GO