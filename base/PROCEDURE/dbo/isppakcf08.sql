SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: ispPAKCF08                                            */
/* Creation Date: 05-May-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5522 CN TeamSales - Update Carton track                    */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 04/04/2019   NJOW01  1.0   WMS-8741 Update labelno to pickdetial.dropid */
/*                            and packdetail.dropid for B2C only           */
/* 06/05/2019   CSCHONG 1.1   WMS-8860 update pickdetail.dropid (CS01)     */
/* 16/08/2019   WAN01   1.2   WMS-10243 - CN UA EcomPacking_For JD ORD CR  */
/* 03/01/2020   NJOW02  1.3   WMS-10647 update packdetail labelno=dropid   */
/*                            for JD                                       */
/* 09/042021    Wan02   1.4   WMS-16026 - PB-Standardize TrackingNo        */
/* 19/09/2022   CSCHONG 1.5   WMS-20748 - revised logic (CS02)             */
/***************************************************************************/
CREATE PROC [dbo].[ispPAKCF08]
(     @c_PickSlipNo  NVARCHAR(10)
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug           INT
         , @n_Continue        INT
         , @n_StartTCnt       INT

   DECLARE @c_sku             NVARCHAR(20),
          @n_packqty          INT,
          @n_pickqty          INT,
          @n_splitqty         INT,
          @c_pickdetailkey    NVARCHAR(10),
          @c_newpickdetailkey NVARCHAR(10),
          @n_TotPickQty       INT,
          @n_TotPackQty       INT,
          @n_cnt              INT,
          @c_DropID           NVARCHAR(20),
          @c_GetOrderkey      NVARCHAR(10),  --CS01
          @c_OHTrackingNo     NVARCHAR(30),
          @c_GetTrackingNo    NVARCHAR(30),
          @c_Shipperkey       NVARCHAR(30),
          @c_keyname          NVARCHAR(30),
          @n_TCartonNo        INT,
          @c_Facility         NVARCHAR(5),
          @c_Child            NVARCHAR(10),
          @c_CartonTo         NVARCHAR(10),
          @c_CarrierName      NVARCHAR(30),
          @c_GetDropID        NVARCHAR(20),
          @c_TrackingNo_PI    NVARCHAR(50),     --(Wan02)
          @c_TotalCtn         VARCHAR(10),
          @c_GetStorerkey     NVARCHAR(15),   --CS01
          @c_OrdGrp           NVARCHAR(20),   --CS02 
          @c_LabelLine        NVARCHAR(5)  = '',
          @CUR_TrackingNo     CURSOR,
          @CUR_PD             CURSOR

         ,@CUR_UPD            CURSOR            --(Wan01)

   SET @b_Success= 1
   SET @n_Err    = 0
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   DECLARE @n_RowRef   INT,
           @c_LabelNo  NVARCHAR(20),
           @c_Orderkey NVARCHAR(10),
           --@c_PackCopyLabelNoToDropId NVARCHAR(10),
           --@c_AssignPackLabelToOrdCfg NVARCHAR(10),
           @n_CartonNo   INT,
           @c_TrackingNo NVARCHAR(20),
           @c_CartonNo   NVARCHAR(5)


   --SELECT @c_PackCopyLabelNoToDropId = dbo.fnc_GetRight('', @c_Storerkey, '', 'PackCopyLabelNoToDropId')
   --SELECT @c_AssignPackLabelToOrdCfg = dbo.fnc_GetRight('', @c_Storerkey, '', 'AssignPackLabelToOrdCfg')

   IF EXISTS(SELECT 1
               FROM PACKHEADER PH (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
               JOIN CODELKUP CL (NOLOCK) ON O.Userdefine03 = CL.Long AND CL.Listname = 'UAEPLCN' AND Short = 'M'
               WHERE PH.Pickslipno = @c_Pickslipno)
   BEGIN
      DECLARE cur_Pack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PD.CartonNo, PD.LabelNo, PH.Orderkey
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
         WHERE PH.Pickslipno = @c_Pickslipno
         ORDER BY PD.CartonNo

      OPEN cur_Pack

      FETCH NEXT FROM cur_Pack INTO @n_CartonNo, @c_LabelNo, @c_Orderkey

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
         SELECT @n_RowRef = 0, @c_TrackingNo = ''

         SELECT TOP 1 @n_RowRef = CT.RowRef,
                     @c_TrackingNo = CT.TrackingNo
         FROM ORDERS O (NOLOCK)
         JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND O.Shipperkey = CL.Short AND CL.Listname = 'WSCOURIER'
         JOIN CARTONTRACK_POOL CT (NOLOCK) ON O.ShipperKey = CT.CarrierName AND CL.Long = CT.KeyName
         WHERE O.Orderkey = @c_Orderkey
         AND CL.Code = '1_2702'
         AND CT.Carrierref2 = 'PEND'
         ORDER BY CT.RowRef

         IF ISNULL(@c_TrackingNo,'') = ''
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 38010
            SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Unable get carton track#. (ispPAKCF08)'
         END
         ELSE
         BEGIN
            UPDATE PACKDETAIL WITH (ROWLOCK)
            SET LabelNo = @c_TrackingNo,
               --DropId = CASE WHEN @c_PackCopyLabelNoToDropId = '1' THEN @c_TrackingNo ELSE DropID END,
               ArchiveCop = NULL
            WHERE Pickslipno = @c_Pickslipno
            AND CartonNo = @n_CartonNo
            AND LabelNo = @c_LabelNo

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_Err = 38020
               SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PACKDETAIL Table Failed. (ispPAKCF08)'
            END

            IF @n_CartonNo = 1
            BEGIN
               UPDATE ORDERS WITH (ROWLOCK)
               SET Userdefine04 = @c_TrackingNo,
                  TrackingNo = @c_TrackingNo,            --(Wan02)
                  TrafficCop = NULL
               WHERE Orderkey = @c_Orderkey

               SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_Err = 38030
                     SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Failed. (ispPAKCF08)'
               END
            END

               /*IF @c_AssignPackLabelToOrdCfg = '1'
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET DropID = @c_TrackingNo,
                     TrafficCop = NULL
                  WHERE Orderkey = @c_Orderkey
                  AND RIGHT('00' + RTRIM(DropId),20) = @c_LabelNo

                  SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_Err = 38040
                     SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PICKDETAIL Table Failed. (ispPAKCF08)'
               END
               END*/

            INSERT INTO CARTONTRACK (TrackingNo, CarrierName, KeyName, LabelNo,
                        CarrierRef1, CarrierRef2)
            SELECT ctp.TrackingNo, ctp.CarrierName, ctp.KeyName, @c_Orderkey,
                  ctp.CarrierRef1, 'GET'
            FROM CartonTrack_Pool ctp (NOLOCK)
            WHERE ctp.RowRef = @n_RowRef

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_Err = 38050
               SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Insert CARTONTRACK Table Failed. (ispPAKCF08)'
            END

            DELETE FROM CARTONTRACK_POOL
            WHERE RowRef = @n_RowRef

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 38060
                  SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Delete CARTONTRACK_POOL Table Failed. (ispPAKCF08)'
            END
         END

         FETCH NEXT FROM cur_Pack INTO @n_CartonNo, @c_LabelNo, @c_Orderkey
      END
      CLOSE cur_Pack
      DEALLOCATE cur_Pack
   END

   --(Wan01) - START  -- IF JD, Update PackDetail.DropID with Tracking + CartonNo and Update it to PICKDETAIL.Dropid
   IF @n_Continue IN (1,2)
   BEGIN
      SET @n_Cnt = 0
      SET @c_Facility   = ''
      SET @c_GetOrderkey= ''
      SET @c_Shipperkey = ''
      SET @c_OHTrackingNo= ''
      SELECT @n_Cnt = 1
            ,@c_Facility   = O.Facility
            ,@c_GetOrderkey= O.Orderkey
            ,@c_Shipperkey = O.Shipperkey
            ,@c_OHTrackingNo = ISNULL(O.TrackingNo,'')  -- ORder's TRackingNo & userDefine04 has value when pack
            ,@c_OrdGrp       = ISNULL(O.OrderGroup,'')  --CS02
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      WHERE PH.Pickslipno = @c_Pickslipno
      AND O.doctype='E'

      IF @n_Cnt <= 0
      BEGIN
         GOTO QUIT_SP
      END

      IF @c_Shipperkey = 'JD' AND @c_OrdGrp <> 'VMI'    --CS02
      BEGIN
         IF @c_OHTrackingNo = ''
         BEGIN
            GOTO QUIT_SP
         END

         SET @c_TrackingNo = ''
         SELECT TOP 1
                  @c_GetTrackingNo = ISNULL(RTRIM(TrackingNo),'')
         FROM CARTONTRACK WITH (NOLOCK)
         WHERE LabelNo = @c_GetOrderkey
         AND   CarrierRef2 = 'GET'
         ORDER BY AddDate

         IF @c_GetTrackingNo = ''
         BEGIN
            GOTO QUIT_SP
         END

         SELECT @c_keyname = ISNULL(C.long,'')
         FROM CODELKUP C WITH (NOLOCK)
         WHERE C.listname = 'AsgnTNo'
         AND C.storerkey = @c_Storerkey
         AND C.short = @c_shipperkey
         AND C.notes = @c_Facility

         SET @c_TotalCtn = 1
         SET @c_TrackingNo = ''

         SELECT TOP 1 @c_TotalCtn = Cartonno
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE Pickslipno = @c_PickSlipNo
         ORDER BY Cartonno DESC

         IF @c_TotalCtn > 0
         BEGIN
            UPDATE PACKHEADER WITH (ROWLOCK)
            SET TTLCNTS = @c_TotalCtn
               ,ArchiveCop = NULL
            WHERE PickSlipNo = @c_PickSlipNo
         END

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
            SET @n_Err = 61804
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKHEADER Fail. (ispPAKCF08)'
                           + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
            GOTO QUIT_SP
         END

         SET @CUR_PD = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT
                PD.CartonNo
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PD.Pickslipno = @c_PickSlipNo

         OPEN @CUR_PD

         FETCH NEXT FROM @CUR_PD INTO @n_TCartonNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_Child = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_TCartonNo))
            SET @c_CartonTo = '0'

            SET @c_GetTrackingNo = @c_OHTrackingNo +  @c_Child

            SET @CUR_UPD = CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT PD.LabelNo
                  ,PD.LabelLine
            FROM PACKDETAIL PD WITH (NOLOCK)
            WHERE PD.Pickslipno = @c_PickSlipNo
            AND PD.CartonNo = @n_TCartonNo
            AND DropID <> @c_GetTrackingNo

            OPEN @CUR_UPD
            FETCH NEXT FROM @CUR_UPD INTO @c_labelno
                                       ,  @c_LabelLine

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               UPDATE PACKDETAIL WITH (ROWLOCK)
               SET DropID = @c_GetTrackingNo
                  ,LabelNo = @c_GetTrackingNo  --NJOW02
                  ,ArchiveCop = NULL
               WHERE PickSlipNo = @c_PickSlipNo
               AND   CartonNo = @n_TCartonNo
               AND   LabelNo  = @c_labelno
               AND   LabelLine= @c_LabelLine

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
                  SET @n_Err = 61802
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKDETIL Fail. (ispPAKCF08)'
                                 + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
                  GOTO QUIT_SP
               END
               FETCH NEXT FROM @CUR_UPD INTO @c_labelno
                                          ,  @c_LabelLine
            END
            CLOSE @CUR_UPD
            DEALLOCATE @CUR_UPD


            --IF EXISTS ( SELECT 1                       --(Wan02) - START
            --            FROM PACKINFO WITH (NOLOCK)
            --            WHERE PickSlipNo = @c_PickSlipNo
            --            AND   CartonNo = @n_TCartonNo
            --            AND   Refno <> @c_GetTrackingNo
            --         )
            SELECT @c_TrackingNo_PI = CASE WHEN TrackingNo <> '' THEN TrackingNo ELSE '' END
                  --@c_TrackingNo_PI = CASE WHEN TrackingNo <> '' THEN TrackingNo ELSE ISNULL(RefNo,'') END
            FROM PACKINFO WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo = @n_TCartonNo

            IF @c_TrackingNo_PI <> @c_GetTrackingNo      --(Wan02) - END
            BEGIN
               UPDATE PACKINFO WITH (ROWLOCK)
               SET --refno = @c_GetTrackingNo
                   --,Trackingno = @c_GetTrackingNo       --(Wan02) -
                   Trackingno = @c_GetTrackingNo         --(Wan02) -
                  ,TrafficCop = NULL
               WHERE PickSlipNo = @c_PickSlipNo
               AND   CartonNo = @n_TCartonNo

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
                  SET @n_Err = 61802
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKINFO Fail. (ispPAKCF08)'
                                 + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
                  GOTO QUIT_SP
               END
            END

            IF EXISTS ( SELECT 1
                        FROM CartonTrack WITH (NOLOCK)
                        WHERE TrackingNo = @c_GetTrackingNo
                        AND LabelNo  = @c_GetOrderkey
                        AND CarrierRef2 = 'GET'
                     )
            BEGIN
               GOTO NEXT_CARTON
            END

            INSERT INTO CARTONTRACK
                  (  TrackingNo
                  ,  CarrierName
                  ,  KeyName
                  ,  LabelNo
                  ,  CarrierRef2
                  ,  UDF02
                  )
            VALUES(
                     @c_GetTrackingNo
                  ,  @c_shipperkey
                  ,  @c_KeyName + '_Child'
                  ,  @c_GetOrderkey
                  ,  'GET'
                  ,  @c_GetTrackingNo
                  )

            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
               SET @n_Err = 61803
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update CARTONTRACK Fail. (ispPAKCF08) '
                              + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
               GOTO QUIT_SP
            END

            NEXT_CARTON:

            FETCH NEXT FROM @CUR_PD INTO @n_TCartonNo
         END
         CLOSE @CUR_PD
         DEALLOCATE @CUR_PD
      END
   END
   --(Wan01) - END

   --NJOW01 Start
   IF @n_continue IN(1,2)
   BEGIN
      SET @n_TotPackQty = 0
      SELECT @n_TotPackQty = SUM(PACKDETAIL.Qty)
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

      SET @n_TotPickQty = 0
      SELECT @n_TotPickQty = SUM(PICKDETAIL.Qty)
      FROM PACKHEADER WITH (NOLOCK)
      JOIN PICKDETAIL WITH (NOLOCK) ON PACKHEADER.Orderkey = PICKDETAIL.Orderkey
      WHERE PACKHEADER.Pickslipno = @c_Pickslipno

      IF ISNULL(@n_TotPackQty, 0) <> ISNULL(@n_TotPickQty, 0)
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 38065
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total PackQty ('+ CAST(@n_TotPackQty AS VARCHAR) +
                            ') vs PickQty ('+ CAST(@n_TotPickQty AS VARCHAR) +') Not Tally. (ispPACKCF08)'
      END
   END

   IF @n_continue IN(1,2)
   BEGIN
      DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT PICKDETAIL.Pickdetailkey
        FROM PACKHEADER (NOLOCK)
        JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
        JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey
        WHERE PACKHEADER.Pickslipno = @c_Pickslipno
        AND ORDERS.DocType = 'E'
        --AND ORDERS.ECOM_SINGLE_Flag <> 'S'

      OPEN PickDet_cur

      FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey

      WHILE @@FETCH_STATUS = 0 AND ( @n_continue = 1 OR @n_continue = 2 )
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET PICKDETAIL.DropId = ''
            ,TrafficCop = NULL
         WHERE PICKDETAIL.Pickdetailkey = @c_pickdetailkey

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38070
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPACKCF08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END

         FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey
      END
      CLOSE PickDet_cur
      DEALLOCATE PickDet_cur

      DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,
             PACKHEADER.Orderkey
            ,PACKDETAIL.CartonNo                      --(Wan01)
            ,PACKDETAIL.LabelLine                     --(Wan01)
            ,PACKDETAIL.DropID                        --(Wan01)
      FROM   PACKHEADER (NOLOCK)
      JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
      JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
      WHERE  PACKHEADER.Pickslipno = @c_Pickslipno
      AND ORDERS.DocType = 'E'
      --AND ORDERS.ECOM_SINGLE_Flag <> 'S'
      ORDER BY PACKDETAIL.Sku, PACKDETAIL.Labelno

      OPEN CUR_PACKDET

      FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey
                                    , @n_TCartonNo    --(Wan01)
                                    , @c_LabelLine    --(Wan01)
                                    , @c_GetDropID    --(Wan01)
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
         SELECT @c_pickdetailkey = ''

         --(Wan01) - (START)
         IF @c_ShipperKey <> 'JD'
         BEGIN
            SET @c_GetDropId = @c_labelno
         END
         --(Wan01) - (END)

         UPDATE PACKDETAIL WITH (ROWLOCK)
         SET DropID = @c_GetDropId     --labelno      --(Wan01)
            ,ArchiveCop = NULL                        --(Wan01)
         WHERE PickSlipno = @c_Pickslipno
         AND Sku = @c_Sku
         AND CartonNo = @n_TCartonNo                  --(Wan01)
         AND LabelNo  = @c_LabelNo
         AND LabelLine= @c_LabelLine                  --(Wan01)

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38080
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Packdetail Table Failed. (ispPACKCF08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END

         WHILE @n_packqty > 0
         BEGIN
            SET @n_cnt = 0

            SELECT TOP 1
                  @c_pickdetailkey = PICKDETAIL.Pickdetailkey,
                  @n_pickqty = PICKDETAIL.Qty
            FROM PICKDETAIL (NOLOCK)
            WHERE (PICKDETAIL.Dropid = '' OR PICKDETAIL.Dropid IS NULL)
            AND PICKDETAIL.Sku = @c_sku
            AND PICKDETAIL.Orderkey = @c_orderkey
            AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey
            ORDER BY PICKDETAIL.Pickdetailkey

            SELECT @n_cnt = @@ROWCOUNT

            IF @n_cnt = 0
               BREAK

            IF @n_pickqty <= @n_packqty
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET PICKDETAIL.DropId = @c_GetDropId --@c_labelno     --(Wan01)
                  ,TrafficCop = NULL
               WHERE Pickdetailkey = @c_pickdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38090
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPACKCF08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  BREAK
               END
               SELECT @n_packqty = @n_packqty - @n_pickqty
            END
            ELSE
            BEGIN  -- pickqty > packqty
               SELECT @n_splitqty = @n_pickqty - @n_packqty

               EXECUTE nspg_GetKey
               'PICKDETAILKEY',
               10,
               @c_newpickdetailkey OUTPUT,
               @b_success OUTPUT,
               @n_err OUTPUT,
               @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SELECT @n_continue = 3
                  BREAK
               END

               INSERT PICKDETAIL
                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, TaskDetailKey
                      )
               SELECT @c_newpickdetailkey
                    , PICKDETAIL.CaseID
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                      ''
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo
                    , TaskDetailKey
               FROM PICKDETAIL (NOLOCK)
               WHERE PickdetailKey = @c_pickdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38100
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispPAKCF08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  BREAK
               END

               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET PICKDETAIL.DropId = @c_GetDropID --@c_labelno   --(Wan01)
                  ,Qty = @n_packqty
                  ,UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END
                  ,TrafficCop = NULL
                WHERE Pickdetailkey = @c_pickdetailkey

                SELECT @n_err = @@ERROR
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38110
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPAKCF08)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   BREAK
                END

                SELECT @n_packqty = 0
            END
         END -- While packqty > 0

        FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey
                                    , @n_TCartonNo --(Wan01)
                                    , @c_LabelLine --(Wan01)
                                    , @c_GetDropID --(Wan01)
      END -- Cursor While
      DEALLOCATE CUR_PACKDET
      --NJOW End
/*
      --CS01 Start
      IF EXISTS(SELECT 1
               FROM PACKHEADER PH (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
            -- JOIN CODELKUP CL (NOLOCK) ON O.Userdefine03 = CL.Long AND CL.Listname = 'UAEPLCN' AND Short = 'M'
               WHERE PH.Pickslipno = @c_Pickslipno AND O.Shipperkey='JD' )
      BEGIN
         SET @c_GetOrderkey = ''
         SELECT @c_GetOrderkey = Orderkey
         FROM PACKHEADER WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo

         IF @c_GetOrderkey = ''
         BEGIN
            GOTO QUIT_SP
         END

         SET @c_TrackingNo = ''
         SELECT TOP 1
                @c_GetTrackingNo = ISNULL(RTRIM(TrackingNo),'')
               --,@c_CarrierName= ISNULL(RTRIM(CarrierName),'')
               --,@c_KeyName    = ISNULL(RTRIM(KeyName),'')
         FROM CARTONTRACK WITH (NOLOCK)
         WHERE LabelNo = @c_GetOrderkey
         AND   CarrierRef2 = 'GET'
         ORDER BY AddDate

         IF @c_GetTrackingNo = ''
         BEGIN
            GOTO QUIT_SP
         END

         SET @c_TotalCtn = 1
         SET @c_TrackingNo = ''

         SELECT @c_TotalCtn = MAX(Cartonno)
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE Pickslipno = @c_PickSlipNo

         IF @c_TotalCtn > 0
         BEGIN
            UPDATE PACKHEADER WITH (ROWLOCK)
            SET TTLCNTS = @c_TotalCtn
            WHERE PickSlipNo = @c_PickSlipNo
         END

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
            SET @n_Err = 61804
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKHEADER Fail. (ispPAKCF08)'
                           + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
            GOTO QUIT_SP
         END

         SET @CUR_TrackingNo = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT
                PH.Orderkey
            ,   OH.Shipperkey
            ,   OH.Trackingno
            ,   PD.CartonNo
         FROM PACKHEADER PH  WITH (NOLOCK)
         JOIN Orders OH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno
         WHERE PH.Pickslipno = @c_PickSlipNo
         AND OH.doctype='E' and OH.shipperkey='JD'

         OPEN @CUR_TrackingNo

         FETCH NEXT FROM @CUR_TrackingNo INTO @c_GetOrderkey
                                           ,  @c_shipperkey
                                           ,  @c_OHTrackingNo
                                           ,  @n_TCartonNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_keyname = ''
            SET @c_Facility = ''
            SET @c_GetTrackingNo = ''
            SET @c_Child = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_TCartonNo))
            SET @c_CartonTo = '0'

            SELECT @c_Facility = OH.Facility
            FROM ORDERS OH WITH (NOLOCK)
            WHERE OH.Orderkey = @c_GetOrderkey

            SELECT @c_keyname = C.long
            FROM CODELKUP C WITH (NOLOCK)
            WHERE C.listname = 'AsgnTNo'
            AND C.storerkey = @c_Storerkey
            AND C.short = @c_shipperkey
            AND C.notes=@c_Facility

            IF ISNULL(@c_OHTrackingNo,'') = ''
            BEGIN
               GOTO NEXT_CARTON
            END

            IF @c_TotalCtn = 1
            BEGIN
              SET @c_GetTrackingNo = @c_OHTrackingNo +  @c_Child --+ @c_CartonTo
            END
            ELSE
            BEGIN
               IF @n_TCartonNo <> @c_TotalCtn
               BEGIN
                  --SET @c_CartonTo = '-0-'
                  SET @c_GetTrackingNo = @c_OHTrackingNo +  @c_Child --+ @c_CartonTo
               END
               ELSE
               BEGIN
                  --SET @c_CartonTo = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_TCartonNo)) + '-'
                  SET @c_GetTrackingNo = @c_OHTrackingNo + @c_Child --+ @c_CartonTo
               END
            END

            SET @CUR_PD =CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT PD.LabelLine
               ,   DropID = ISNULL(RTRIM(PD.DropID),'')
               ,   RefNo = PF.RefNo
            FROM   PACKDETAIL PD WITH (NOLOCK)
            JOIN PackInfo PF WITH (NOLOCK) ON PF.PickSlipNo=PD.PickSlipNo and PF.CartonNo=PD.CartonNo
            WHERE  PD.PickSlipNo = @c_PickSlipNo
            AND    PD.CartonNo = @n_TCartonNo
            ORDER BY PD.LabelLine

            OPEN @CUR_PD

            FETCH NEXT FROM @CUR_PD INTO @c_LabelLine
                                        ,@c_GetDropID
                                        ,@c_TrackingNo_PI

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @c_GetDropID <> @c_GetTrackingNo
               BEGIN
                  UPDATE PACKDETAIL WITH (ROWLOCK)
                  SET DropID = @c_GetTrackingNo
                  WHERE PickSlipNo = @c_PickSlipNo
                  AND   CartonNo = @n_TCartonNo
                  AND   LabelLine= @c_LabelLine

                  SET @n_Err = @@ERROR
                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
                     SET @n_Err = 61802
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKDETIL Fail. (ispPAKCF08)'
                                   + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
                     GOTO QUIT_SP
                  END
               END

               IF @c_TrackingNo_PI <> @c_GetTrackingNo
               BEGIN
                  UPDATE PACKINFO WITH (ROWLOCK)
                  SET refno = @c_GetTrackingNo
                  WHERE PickSlipNo = @c_PickSlipNo
                  AND   CartonNo = @n_TCartonNo

                  SET @n_Err = @@ERROR
                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
                     SET @n_Err = 61802
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKINFO Fail. (ispPAKCF08)'
                                   + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
                     GOTO QUIT_SP
                  END
               END

               SET @c_CartonNo = ''
               SET @c_CartonNo = RIGHT('0000' + CAST(@n_TCartonNo AS NVARCHAR(5)), 5 )

               UPDATE PICKDETAIL
               SET Dropid = @c_GETTrackingNo
               FROM PICKHEADER PH WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = PH.Orderkey
               where ph.pickheaderkey=  @c_PickSlipNo
               and pd.orderlinenumber = @c_CartonNo

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
                  SET @n_Err = 61805
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PICKDETAIL Fail. (ispPAKCF08)'
                                 + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
                  GOTO QUIT_SP
               END

               FETCH NEXT FROM @CUR_PD INTO @c_LabelLine
                                          , @c_DropID
                                          , @c_TrackingNo_PI
            END
            CLOSE @CUR_PD
            DEALLOCATE @CUR_PD

            IF EXISTS ( SELECT 1
                        FROM CartonTrack WITH (NOLOCK)
                        WHERE TrackingNo = @c_GetTrackingNo
                        AND LabelNo  = @c_GetOrderkey
                        AND CarrierRef2 = 'GET'
                     )
            BEGIN
               GOTO NEXT_CARTON
            END

            INSERT INTO CARTONTRACK
                  (  TrackingNo
                  ,  CarrierName
                  ,  KeyName
                  ,  LabelNo
                  ,  CarrierRef2
                  ,  UDF02
                  )
            VALUES(
                     @c_GetTrackingNo
                  ,  @c_shipperkey
                  ,  @c_KeyName + '_Child'
                  ,  @c_GetOrderkey
                  ,  'GET'
                  ,  @c_GetTrackingNo
                  )

            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err)
               SET @n_Err = 61803
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update CARTONTRACK Fail. (ispPAKCF08) '
                             + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
               GOTO QUIT_SP
            END

            NEXT_CARTON:

            FETCH NEXT FROM @CUR_TrackingNo INTO @c_GetOrderkey
                                          ,  @c_shipperkey
                                          ,  @c_OHTrackingNo
                                          ,  @n_TCartonNo
         END
         CLOSE @CUR_TrackingNo
      END
       --CS01 END
 */
   END

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF08'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END
      RETURN
   END
END

GO