SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: isp_AutoPackOrder                                    */
/* Creation Date: 10-June-2010                                            */
/* Copyright: IDS                                                         */
/* Written by: NJOW                                                       */
/*                                                                        */
/* Purpose: SOS#175251  - Auto pack Confirm All SKUs into 1 Carton        */
/*                                                                        */
/* Called By: nep_w_packing_precartonize_maintenance                      */
/*                                                                        */
/* Parameters:                                                            */
/*                                                                        */
/* PVCS Version: 1.2                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 06-Oct-2010  NJOW01    1.1   192020 - Fix locking and performance issue*/
/* 25-Jan-2010  Leong     1.2   SOS# 203239 - Apply AddWho / EditWho for  */
/*                                            data logging purpose        */
/* 13-Sep-2012	NJOW02    1.3   247575-Move confirm pack to after print   */
/*                              GS1 label at front end                    */
/**************************************************************************/

CREATE PROCEDURE [dbo].[isp_AutoPackOrder]
   @c_PickSlipNo NVARCHAR(10),
   @b_success    Int       OUTPUT,
   @n_err        Int       OUTPUT,
   @c_errmsg     NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue  Int,
            @n_cnt       Int,
            @n_starttcnt Int

   DECLARE  @c_orderkey       NVARCHAR(10),
            @c_StorerKey      NVARCHAR(15),
            @c_Sku            NVARCHAR(20),
            @n_Qty            Int,
            @c_FirstRec       NVARCHAR(1),
            @n_CartonNo       Int,
            @n_LabelLine      Int,
            @c_LabelLine      NVARCHAR(5),
            @c_LabelNo        NVARCHAR(20),
            @c_route          NVARCHAR(10),
            @c_consigneekey   NVARCHAR(15),
            @c_externorderkey NVARCHAR(30),
            @c_loadkey        NVARCHAR(10),
            @n_sumpickqty     Int

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg = '', @n_err = 0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF (SELECT COUNT(*) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) > 0
      BEGIN
         SELECT @n_sumpickqty = SUM(PD.Qty)
         FROM ORDERS O (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON (O.Orderkey = PD.Orderkey)
         JOIN Pickheader PH (NOLOCK) ON (PH.Orderkey = PD.Orderkey) -- AND PH.Zone = 'D')
         WHERE PD.Status BETWEEN '5' AND '9'
         AND PH.Pickheaderkey = @c_PickSlipNo

         IF (SELECT ISNULL(SUM(Qty),0) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = @n_sumpickqty OR
            (SELECT Status FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = '9'
         BEGIN
            SELECT @n_continue = 4
         END
         ELSE
         BEGIN
            DELETE FROM PACKDETAIL WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo
         END
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF (SELECT COUNT(*)
          FROM PICKDETAIL PD (NOLOCK)
          JOIN Pickheader PH (NOLOCK) ON (PH.Orderkey = PD.Orderkey)
          WHERE PD.Status < '5'
          AND PH.Pickheaderkey = @c_PickSlipNo) > 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60100
         SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Pickslip Not Confirm Picked Yet. (isp_AutoPackOrder)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO PROC_END
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT PD.StorerKey, PD.Sku, PD.Orderkey, SUM(PD.Qty) As Qty,
             O.Route, O.Consigneekey, O.Externorderkey, O.Loadkey
      INTO #TMP_PICKDET
      FROM ORDERS O (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON (O.Orderkey = PD.Orderkey)
      JOIN Pickheader PH (NOLOCK) ON (PH.Orderkey = PD.Orderkey)
      WHERE PD.Status BETWEEN '5' AND '8'
      AND PH.Pickheaderkey = @c_PickSlipNo
      GROUP BY PD.StorerKey, PD.Sku, PD.Orderkey, O.Route, O.Consigneekey, O.Externorderkey, O.Loadkey

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @n_continue = 4
      END
   END --continue

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Sku = '', @c_FirstRec = 'Y', @n_CartonNo = 1, @n_LabelLine = 1

      WHILE 1=1
      BEGIN
         SET ROWCOUNT 1

         SELECT @c_orderkey = Orderkey, @c_StorerKey = StorerKey, @c_loadkey = loadkey,
                @c_route = Route, @c_consigneekey = Consigneekey, @c_externorderkey = Externorderkey,
                @c_Sku = Sku, @n_Qty = Qty
         FROM #TMP_PICKDET
         WHERE Sku > @c_Sku
         ORDER BY Sku

         SELECT @n_cnt = @@ROWCOUNT

         SET ROWCOUNT 0

         IF @n_cnt = 0
         BEGIN
            BREAK
         END

         IF @c_FirstRec = 'Y'
         BEGIN
            IF (SELECT COUNT(1) FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo) = 0
            BEGIN
               INSERT INTO PACKHEADER (PickSlipNo, StorerKey, orderkey, loadkey, route, consigneekey, orderrefno, ttlcnts, AddWho) -- SOS# 203239
               VALUES (@c_PickSlipNo, @c_StorerKey, @c_orderkey, @c_loadkey, @c_route, @c_consigneekey, LEFT(@c_externorderkey,18), 1, '%' + SUser_SName())

               SELECT @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60101
                  SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Error Insert PACKHEADER Table. (isp_AutoPackOrder)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO PROC_END
               END
            END -- COUNT(1) FROM PACKHEADER

            EXECUTE isp_GenUCCLabelNo
                  @c_StorerKey,
                  @c_LabelNo  OUTPUT,
                  @b_success  OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT

            IF @b_success = 0
            BEGIN
               SELECT @n_continue = 3
               GOTO PROC_END
            END

            IF (SELECT COUNT(1) FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo) = 0
            BEGIN
               INSERT INTO PACKINFO (PickSlipNo, CartonNo, CartonType, AddWho, EditWho) -- SOS# 203239
               VALUES (@c_PickSlipNo, @n_CartonNo, 'STD', '%' + SUser_SName(), '%' + SUser_SName())
            END

            SELECT @c_FirstRec = 'N'
         END -- @c_FirstRec = 'Y'

         SELECT @c_LabelLine = RIGHT('00000' + RTRIM(CONVERT(Char(5), @n_LabelLine)), 5)

         INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, Sku, Qty, AddWho, EditWho) -- SOS# 203239
         VALUES (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_Sku, @n_Qty, '%' + SUser_SName(), '%' + SUser_SName())

         SELECT @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60102
            SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Error Insert PACKDETAIL Table. (isp_AutoPackOrder)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO PROC_END
         END

         SELECT @n_LabelLine = @n_LabelLine + 1
      END -- WHILE 1=1
   END -- @n_continue

   /* NJOW02 - to remove
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE PACKHEADER WITH (ROWLOCK)
      SET Status = '9'
        , AddWho = '^' + SUser_SName() -- SOS# 203239
      WHERE PickSlipNo = @c_PickSlipNo --NJOW01

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(Char(250),@n_err), @n_err = 60103
         SELECT @c_errmsg='NSQL'+CONVERT(Char(5),@n_err)+': Error Update PACKHEADER Table. (isp_AutoPackOrder)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END -- @n_continue
   */
   
   PROC_END:

   IF @n_continue=4
   BEGIN
      SET @n_err = 10000
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_AutoPackOrder'
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
END -- End PROC

GO