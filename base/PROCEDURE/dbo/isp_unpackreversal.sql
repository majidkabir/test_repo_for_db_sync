SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_UnpackReversal                                 */
/* Creation Date: 14-May-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Unpack or pack confirm reversal                             */
/*                                                                      */
/* Called By: nep_w_pack_maintenance                                    */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 2.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 28-Jul-2010 NJOW01   1.1   Not to reverse pick/scan out status if    */
/*                             CHECKPICKB4PACK is turned on             */
/* 09-Nov-2015 SHONG01  1.2   Reverse ShipFlag for Backend Pick confirm */
/* 17-Oct-2016 TLTING01 1.3   Deadlock tune                             */
/* 19-Dec-2016 SPChin   1.4   IN00214361 - Bug Fixed                    */
/* 09-Jun-2017 WAN01    1.5   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/* 19-Oct-2017 WAN02    1.6   Fixed wrong orders status if pickdetail.qty*/
/*                            = 0                                       */
/* 19-DEC-2017 Wan03    1.7   WMS-3486 - CR_Nike Korea ECOM Exceed      */
/*                            Packing Module                            */
/*13-JUN-2018  NJOW02   1.8   WMS-5219 - Add cancel packing order       */
/*                            feature                                   */
/*13-Dec-2018  TLTING   1.9   Missing nolock                            */
/* 16-MAR-2021 Wan04    2.0   WMS-16463-CN NIKE Phoenix Confirm Packing */
/*                            Reversal [CR]                             */
/* 21-Sep-2022 WLChooi  2.1   JSM-96945 - Clear TTLCNTS if              */
/*                            PackSummB4Packed is not turned on (WL01)  */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_UnpackReversal]
   @c_pickslipno  NVARCHAR(10),
   @c_unpacktype  NVARCHAR(1),
   @b_success     int OUTPUT,
   @n_err         int OUTPUT,
   @c_errmsg      NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int

   DECLARE @c_orderkey NVARCHAR(10),
           @c_loadkey NVARCHAR(30),
           @c_status NVARCHAR(1),
           @c_storerkey NVARCHAR(15),
           @n_cnt int,
           @n_starttcnt int,
           @c_CancelPackOrder_SP NVARCHAR(30) --NJOW02

   DECLARE @c_facility        NVARCHAR(5),
           @c_chkpickb4pack   NVARCHAR(1),
           @c_Pickdetailkey   NVARCHAR(10)

   DECLARE @c_ReverseStatus         NVARCHAR(10) = '0'   --(Wan04)
         , @c_CheckPickB4Pack_Opt5  NVARCHAR(500)= ''    --(Wan04)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0
   SET @c_Pickdetailkey = ''

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   SELECT @c_status = PACKHEADER.Status, @c_orderkey = ISNULL(PACKHEADER.orderkey,''),
          @c_loadkey = ISNULL(PACKHEADER.Loadkey,''), @c_storerkey = PACKHEADER.StorerKey,
          @c_facility = ORDERS.Facility
   FROM PACKHEADER (NOLOCK)
   LEFT JOIN ORDERS (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
   WHERE PACKHEADER.Pickslipno = @c_pickslipno

   IF @c_status <> '9'
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60010
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack Not Confirm Yet. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
   END

   IF @c_orderkey <> ''
   BEGIN
      IF (SELECT COUNT(1) FROM ORDERS(NOLOCK) WHERE Orderkey = @c_orderkey AND Status = '9') > 0
      BEGIN
      SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60020
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order Already Shipped. Unpack/Reversal Is Not Allowed . (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END
   ELSE
   BEGIN
      IF (SELECT COUNT(1) FROM LOADPLAN(NOLOCK) WHERE Loadkey = @c_loadkey AND Status = '9') > 0
      BEGIN
      SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60030
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': LoadPlan Already Shipped. Unpack/Reversal Is Not Allowed . (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_facility IS NULL
      BEGIN
         SELECT @c_facility = MAX(ORDERS.facility)
         FROM LOADPLANDETAIL (NOLOCK)
         JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE LOADPLANDETAIL.Loadkey = @c_loadkey
      END

      EXECUTE nspGetRight
              @c_Facility = @c_Facility
            , @c_Storerkey= @c_Storerkey
            , @c_Sku = null           -- Sku
            , @c_Configkey = 'CheckPickB4Pack' -- Configkey
            , @b_success   = @b_success                  output
            , @c_Authority = @c_chkpickb4pack            output
            , @n_err       = @n_err                      output
            , @c_errmsg    = @c_errmsg                   OUTPUT
            , @c_Option5   = @c_CheckPickB4Pack_Opt5  OUTPUT      --(Wan04)

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @n_err = 60040, @c_errmsg = 'isp_UnpackReversal' + rtrim(@c_errmsg)
      END

      --(Wan04) - START
      SET @c_ReverseStatus = '0'

      IF @c_chkpickb4pack = '0' AND @c_CheckPickB4Pack_Opt5 <> ''
      BEGIN
         SELECT @c_ReverseStatus = dbo.fnc_GetParamValueFromString('@c_PackReverseStatusWhenOff', @c_CheckPickB4Pack_Opt5, @c_ReverseStatus)
      END
      --(Wan04) - END
   END

   --NJOW02
   IF (@n_continue = 1 or @n_continue = 2) AND @c_unpacktype = 'C'
   BEGIN
      EXECUTE nspGetRight
              @c_Facility,
              @c_Storerkey,
              null,            -- Sku
              'CancelPackOrder_SP',  -- Configkey
              @b_success    output,
              @c_CancelPackOrder_SP output,
              @n_err        output,
              @c_errmsg     output

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3, @n_err = 60050, @c_errmsg = 'isp_UnpackReversal' + rtrim(@c_errmsg)
      END
      ELSE IF NOT EXISTS (SELECT 1 FROM sys.objects (NOLOCK) WHERE name = RTRIM(@c_CancelPackOrder_SP) AND type = 'P') OR ISNULL(@c_CancelPackOrder_SP,'') = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60060
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+'Storerconfig CancelPackOrder_SP - Stored Proc name invalid or Not setup ('+RTRIM(ISNULL(@c_CancelPackOrder_SP,''))+') (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO ENDPROC
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      --WL01 S
      IF NOT EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
                    WHERE StorerKey = @c_StorerKey
                    AND ConfigKey = 'PackSummB4Packed'
                    AND sValue = '1')
      BEGIN
         UPDATE PACKHEADER WITH (ROWLOCK)
         SET Status = '0', PackStatus = 'REPACK', TTLCNTS = 0
         WHERE ArchiveCop = NULL
         AND Pickslipno = @c_pickslipno
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60069
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO ENDPROC
         END
      END
      ELSE
      BEGIN
         UPDATE PACKHEADER WITH (ROWLOCK)
         SET Status = '0', PackStatus = 'REPACK'                           --(WAN01)
         WHERE ArchiveCop = NULL
         AND Pickslipno = @c_pickslipno
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60070
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO ENDPROC
         END
      END
      --WL01 E

      IF @c_chkpickb4pack <> '1'
      BEGIN
         UPDATE PICKINGINFO WITH (ROWLOCK)
         SET ScanOutDate = NULL, TrafficCop = NULL
         WHERE PickslipNo = @c_pickslipno
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60080
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKINGINFO Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO ENDPROC
         END

         IF @c_orderkey <> ''
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET Status = '3' , TrafficCop = NULL
            WHERE OrderKey = @c_orderkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60090
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END

            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET Status = '3', TrafficCop = NULL
            WHERE OrderKey = @c_orderkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60100
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END

            -- TLTING01
            DECLARE Pickdet_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT Pickdetailkey FROM PICKDETAIL WITH (NOLOCK)
               WHERE OrderKey = @c_Orderkey
               ORDER BY Qty Desc       --(Wan02)

            OPEN Pickdet_Cur
            FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey
            WHILE @@FETCH_STATUS = 0
            BEGIN

               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET Status = @c_ReverseStatus, ShipFlag = CASE WHEN ShipFlag = 'P' THEN '0' ELSE Shipflag END   --(Wan04)
               --WHERE OrderKey = @c_Pickdetailkey    --IN00214361
               WHERE PickDetailKey = @c_Pickdetailkey --IN00214361
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60110
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO ENDPROC
               END

               FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey
            END
            CLOSE Pickdet_Cur
            DEALLOCATE Pickdet_Cur

            UPDATE LOADPLANDETAIL WITH (ROWLOCK)
            SET Status = '3', TrafficCop =  NULL
            WHERE Orderkey = @c_Orderkey
            AND LoadKey = @c_loadkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60120
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLANDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END
         END
         ELSE
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET Status = '3' , TrafficCop = NULL
            WHERE LoadKey = @c_loadkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60130
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERS Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END

            UPDATE ORDERDETAIL WITH (ROWLOCK)
            SET Status = '3', TrafficCop = NULL
            WHERE LoadKey = @c_loadkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60140
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END

            -- TLTING01
            DECLARE Pickdet_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Pickdetailkey FROM PICKDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
            JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
            AND LOADPLANDETAIL.Loadkey = @c_loadkey

            OPEN Pickdet_Cur
            FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey
            WHILE @@FETCH_STATUS = 0
            BEGIN

               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET Status = @c_ReverseStatus,          --(Wan04)
               ShipFlag = CASE WHEN PICKDETAIL.ShipFlag = 'P' THEN '0' ELSE PICKDETAIL.Shipflag END
               --WHERE OrderKey = @c_Pickdetailkey     --IN00214361
               WHERE PickDetailKey = @c_Pickdetailkey  --IN00214361
               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60150
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO ENDPROC
               END

               FETCH NEXT FROM Pickdet_Cur INTO @c_Pickdetailkey
            END
            CLOSE Pickdet_Cur
            DEALLOCATE Pickdet_Cur

            UPDATE LOADPLANDETAIL WITH (ROWLOCK)
            SET Status = '3', TrafficCop =  NULL
            WHERE LoadKey = @c_loadkey
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60160
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLANDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO ENDPROC
            END
         END
      END

      SELECT @c_status = MAX(Status)
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE LoadKey = @c_loadkey

      IF @c_status = '3'
      BEGIN
         UPDATE LOADPLAN WITH (ROWLOCK)
         SET Status = '3', TrafficCop = NULL
         WHERE LoadKey = @c_loadkey
      END
      ELSE
      BEGIN
         UPDATE LOADPLAN WITH (ROWLOCK)
         SET Status = '5', TrafficCop = NULL
         WHERE LoadKey = @c_loadkey
      END
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60170
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update LOADPLAN Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO ENDPROC
      END

      IF @c_unpacktype = 'U' -- unpack
         OR @c_unpacktype = 'C'  --NJOW02
      BEGIN
         --(Wan03) - START
         DECLARE @n_CartonNo              INT
               , @c_authority             NVARCHAR(30)
               , @c_CTNTrackNoReverse_SP  NVARCHAR(30)
               , @c_DocType               NVARCHAR(10)

               , @c_SQL                   NVARCHAR(MAX)
               , @c_SQLParms              NVARCHAR(MAX)

               , @CUR_PACKINFO            CURSOR

         IF ISNULL(RTRIM(@c_orderkey),'') <> ''
         BEGIN
            SET @c_DocType = ''
            SELECT @c_DocType  = ISNULL(RTRIM(DocType),'')
            FROM ORDERS WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey
         END
         ELSE
         BEGIN
            SET @c_DocType = ''
            SELECT TOP 1 @c_DocType  = ISNULL(RTRIM(DocType),'')
            FROM ORDERS WITH (NOLOCK)
            WHERE Loadkey = @c_Loadkey
         END

         IF @c_DocType = 'E'
         BEGIN
            SET @c_authority = ''
            EXEC nspGetRight
                  @c_Facility  = @c_Facility
               ,  @c_StorerKey = @c_StorerKey
               ,  @c_sku       = NULL
               ,  @c_ConfigKey = 'EPACKCTNTrackNoReverse_SP'
               ,  @b_Success   = @b_Success    OUTPUT
               ,  @c_authority = @c_authority  OUTPUT
               ,  @n_err       = @n_err        OUTPUT
               ,  @c_errmsg    = @c_errmsg     OUTPUT


            SET @c_CTNTrackNoReverse_SP = ''
            IF EXISTS ( SELECT 1 FROM sys.objects (NOLOCK)
                        WHERE name = @c_authority
                        AND Type = 'P'
                  )
            BEGIN
               SET @c_CTNTrackNoReverse_SP = RTRIM(@c_authority)
            END

            SET @CUR_PACKINFO = CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT CartonNo
            FROM   PACKDETAIL WITH (NOLOCK)
            WHERE  PickSlipNo = @c_PickSlipNo
            ORDER BY CartonNo

            OPEN @CUR_PACKINFO

            FETCH NEXT FROM @CUR_PACKINFO INTO @n_CartonNo

            WHILE @@FETCH_STATUS <> -1
            BEGIN

               IF @c_CTNTrackNoReverse_SP <> ''
               BEGIN
                  SET @c_SQL =N'EXEC ' + @c_CTNTrackNoReverse_SP
                              + ' @c_PickSlipNo, @n_CartonNo, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT'

                  SET @c_SQLParms = N'@c_PickSlipNo NVARCHAR(10)'
                                    +', @n_CartonNo  INT'
                                    +', @b_Success   INT OUTPUT'
                                    +', @n_err       INT OUTPUT'
                                    +', @c_errmsg    NVARCHAR(255) OUTPUT'

                  EXEC sp_executesql @c_SQL
                        ,  @c_SQLParms
                        ,  @c_PickSlipNo
                        ,  @n_CartonNo
                        ,  @b_Success   OUTPUT
                        ,  @n_err       OUTPUT
                        ,  @c_errmsg    OUTPUT

                  IF @b_Success <> 1
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 60180
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_CTNTrackNoReverse_SP + '. (isp_UnpackReversal)'
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                     GOTO ENDPROC
                  END
               END
               FETCH NEXT FROM @CUR_PACKINFO INTO @n_CartonNo
            END
         END
         --(Wan03) - END

         DELETE PACKDETAIL WHERE PickslipNo = @c_pickslipno
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
         SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60190
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKDETAIL Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO ENDPROC
         END

         DELETE PACKINFO WHERE PickslipNo = @c_pickslipno
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
         SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60200
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKINFO Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO ENDPROC
         END
      END
   END

   --NJOW02
   IF (@n_continue = 1 or @n_continue = 2) AND @c_unpacktype = 'C' AND ISNULL(@c_CancelPackOrder_SP,'') <> ''
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_CancelPackOrder_SP + ' @c_PickslipNo, @b_Success OUTPUT, @n_Err OUTPUT,' +
                   ' @c_ErrMsg OUTPUT '

      EXEC sp_executesql @c_SQL,
           N'@c_PickslipNo NVARCHAR(10), @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',
           @c_pickslipno,
           @b_Success OUTPUT,
           @n_Err OUTPUT,
           @c_ErrMsg OUTPUT

      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         GOTO ENDPROC
      END

      DELETE PACKHEADER WHERE PickslipNo = @c_pickslipno
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
      SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60210
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Delete PACKHEADER Table. (isp_UnpackReversal)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO ENDPROC
      END
   END

ENDPROC:

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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_UnpackReversal'
       --RAISERROR @n_err @c_errmsg
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