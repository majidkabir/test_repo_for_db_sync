SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWAVPK18                                         */
/* Creation Date: 16-Mar-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21904 - [CN] Chargeurs Auto Generate Packdetail by      */
/*          Pickdetail                                                  */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 16-Mar-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispWAVPK18]
   @c_Wavekey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey      NVARCHAR(15)
         , @c_Sku            NVARCHAR(20)
         , @n_Qty            INT
         , @c_PickslipNo     NVARCHAR(10)
         , @n_CartonNo       INT
         , @c_LabelNo        NVARCHAR(20)
         , @n_LabelLineNo    INT
         , @c_LabelLineNo    NVARCHAR(5)
         , @c_Orderkey       NVARCHAR(10)
         , @c_UOM            NVARCHAR(10)
         , @c_OrderGrp       NVARCHAR(50)
         , @c_DelNote        NVARCHAR(50)
         , @c_Stop           NVARCHAR(50)
         , @c_RefNo          NVARCHAR(50)
         , @c_Route          NVARCHAR(10)
         , @c_Lottable01     NVARCHAR(50)
         , @c_Lottable02     NVARCHAR(50)
         , @c_ExtLineNo      NVARCHAR(50)
         , @c_ExternOrderkey NVARCHAR(50)

   DECLARE @n_Continue  INT
         , @n_StartTCnt INT
         , @n_debug     INT

   IF @n_Err = 1
      SET @n_debug = 1
   ELSE
      SET @n_debug = 0

   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --Validation  
   IF @n_Continue IN ( 1, 2 )
   BEGIN
      IF EXISTS (  SELECT 1
                   FROM PICKDETAIL PD WITH (NOLOCK)
                   JOIN WAVEDETAIL WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
                   WHERE PD.Status = '4' AND PD.Qty > 0 AND WD.WaveKey = @c_Wavekey)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 38010
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Found Short Pick with Qty > 0 (ispWAVPK18)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
         GOTO QUIT_SP
      END
   END

   --Generate Pickslip
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      EXEC dbo.isp_CreatePickSlip @c_Wavekey = @c_Wavekey
                                , @c_PickslipType = N'3'
                                , @c_AutoScanIn = 'Y'
                                , @b_Success = @b_Success OUTPUT
                                , @n_Err = @n_Err OUTPUT
                                , @c_ErrMsg = @c_ErrMsg OUTPUT
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
              , @n_Err = 38015
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': EXEC isp_CreatePickSlip Failed (ispWAVPK18)'
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
         GOTO QUIT_SP
      END
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DECLARE CUR_DISCPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT WD.OrderKey
           , O.StorerKey
           , O.OrderGroup
           , O.DeliveryNote
           , O.[Stop]
           , O.[Route]
           , O.ExternOrderKey
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON W.WaveKey = WD.WaveKey
      JOIN ORDERS O (NOLOCK) ON WD.OrderKey = O.OrderKey
      LEFT JOIN PackHeader PH (NOLOCK) ON WD.OrderKey = PH.OrderKey
      WHERE W.WaveKey = @c_Wavekey AND PH.OrderKey IS NULL
      ORDER BY WD.OrderKey

      OPEN CUR_DISCPACK

      FETCH NEXT FROM CUR_DISCPACK
      INTO @c_Orderkey
         , @c_Storerkey
         , @c_OrderGrp
         , @c_DelNote
         , @c_Stop
         , @c_Route
         , @c_ExternOrderkey

      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN ( 1, 2 )
      BEGIN
         SELECT TOP 1 @c_PickslipNo = PH.PickHeaderKey
         FROM PICKHEADER PH (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON PH.OrderKey = O.OrderKey
         WHERE O.OrderKey = @c_Orderkey

         IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_PickslipNo)
         BEGIN
            INSERT INTO PackHeader (Route, OrderKey, OrderRefNo, LoadKey, ConsigneeKey, StorerKey, PickSlipNo)
            SELECT O.Route
                 , O.OrderKey
                 , LEFT(O.ExternOrderKey, 18)
                 , O.LoadKey
                 , O.ConsigneeKey
                 , O.StorerKey
                 , @c_PickslipNo
            FROM PICKHEADER PH (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON (PH.OrderKey = O.OrderKey)
            WHERE PH.PickHeaderKey = @c_PickslipNo

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 38020
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert Error On PACKHEADER Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
            END
         END

         SET @c_LabelNo = N''
         SET @n_CartonNo = 0
         SET @n_LabelLineNo = 0

         DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         WITH t1 AS
         (
            SELECT P.Sku
                 , P.UOMQty
                 , P.Qty AS Qty
                 , P.UOM
                 , LA.Lottable01
                 , LA.Lottable02
                 , OD.ExternLineNo
            FROM PICKDETAIL P (NOLOCK)
            JOIN LOTATTRIBUTE LA (NOLOCK) ON P.Lot = LA.Lot
            JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = P.OrderKey 
                                        AND OD.OrderLineNumber = P.OrderLineNumber 
                                        AND OD.StorerKey = P.Storerkey
                                        AND OD.SKU = P.SKU
            WHERE P.OrderKey = @c_Orderkey
            AND   P.Qty > 0
            AND   P.UOM = '2'
         )
            , t2 AS
         (
            SELECT TOP (10000) ROW_NUMBER() OVER (ORDER BY id) AS Val
            FROM sysobjects (NOLOCK)
         )
         SELECT t1.Sku
              , t1.Qty / t1.UOMQty AS Qty
              , '2' AS UOM
              , t1.Lottable01
              , t1.Lottable02
              , t1.ExternLineNo
         FROM t1
            , t2
         WHERE t1.UOMQty >= t2.Val
         UNION ALL
         SELECT P.Sku
              , P.Qty
              , P.UOM
              , LA.Lottable01
              , LA.Lottable02
              , OD.ExternLineNo
         FROM PICKDETAIL P (NOLOCK)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON P.Lot = LA.Lot
         JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = P.OrderKey 
                                     AND OD.OrderLineNumber = P.OrderLineNumber 
                                     AND OD.StorerKey = P.Storerkey
                                     AND OD.SKU = P.SKU
         WHERE P.OrderKey = @c_Orderkey AND P.Qty > 0 AND P.UOM <> '2'
         ORDER BY 1

         OPEN CUR_PICKDETAIL

         FETCH NEXT FROM CUR_PICKDETAIL
         INTO @c_Sku
            , @n_Qty
            , @c_UOM
            , @c_Lottable01
            , @c_Lottable02
            , @c_ExtLineNo

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            --SELECT @c_LabelNo, @c_PrevUOM, @c_UOM, @n_CartonNo
            SET @c_LabelNo = N''
            SET @n_CartonNo = @n_CartonNo + 1
            SET @n_LabelLineNo = 0

            IF NOT EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = @c_PickslipNo AND CartonNo = @n_CartonNo)
            BEGIN
               EXEC isp_GenUCCLabelNo_Std @cPickslipNo = @c_PickslipNo
                                        , @nCartonNo = @n_CartonNo
                                        , @cLabelNo = @c_LabelNo OUTPUT
                                        , @b_success = @b_Success OUTPUT
                                        , @n_err = @n_Err OUTPUT
                                        , @c_errmsg = @c_ErrMsg OUTPUT

               IF @b_Success <> 1
                  SET @n_Continue = 3

               -- Order not grouped
               IF ISNULL(@c_OrderGrp, '') = ''
               BEGIN
                  IF ISNULL(@c_DelNote, '') = ''
                  BEGIN
                     SELECT @c_RefNo = ISNULL(MAX(CAST(RefNo AS INT)), '')
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickslipNo
                  END
                  ELSE
                  BEGIN
                     SELECT @c_RefNo = ISNULL(MAX(CAST(SUBSTRING(RefNo, LEN(@c_DelNote) + 1, LEN(RefNo)) AS INT)), '')
                     FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickslipNo
                  END
               END

               -- Order are grouped
               IF ISNULL(@c_OrderGrp, '') <> ''
               BEGIN
                  -- Get parent carton prefix
                  IF @c_ExternOrderkey <> @c_OrderGrp -- child order
                  BEGIN
                     SELECT @c_DelNote = TRIM(ISNULL(DeliveryNote, ''))
                          , @c_Stop = CASE WHEN @c_Route = 'R' THEN @c_Stop
                                           ELSE [Stop] END -- If use own order carton start, don't retrieve group carton start
                     FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE StorerKey = @c_Storerkey AND OrderGroup = @c_OrderGrp AND ExternOrderKey = @c_OrderGrp -- Parent order
                  END

                  -- Use own order carton no
                  IF @c_Route = 'R' -- Reset
                  BEGIN
                     IF ISNULL(@c_DelNote, '') = ''
                     BEGIN
                        SELECT @c_RefNo = ISNULL(MAX(CAST(RefNo AS INT)), '')
                        FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickslipNo
                     END
                     ELSE
                     BEGIN
                        SELECT @c_RefNo = ISNULL(MAX(CAST(SUBSTRING(RefNo, LEN(@c_DelNote) + 1, LEN(RefNo)) AS INT)), '')
                        FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickslipNo
                     END
                  END

                  -- Use order group carton no
                  IF @c_Route <> 'R'
                  BEGIN
                     IF ISNULL(@c_DelNote, '') = ''
                     BEGIN
                        SELECT @c_RefNo = ISNULL(MAX(CAST(PD.RefNo AS INT)), '')
                        FROM dbo.PackHeader PH WITH (NOLOCK)
                        JOIN dbo.ORDERS O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey AND O.Route <> 'R') -- Exclude those by own order carton no
                        JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                        WHERE O.StorerKey = @c_Storerkey AND O.OrderGroup = @c_OrderGrp
                     END
                     ELSE
                     BEGIN
                        SELECT @c_RefNo = ISNULL(
                                             MAX(CAST(SUBSTRING(PD.RefNo, LEN(@c_DelNote) + 1, LEN(PD.RefNo)) AS INT)), '')
                        FROM dbo.PackHeader PH WITH (NOLOCK)
                        JOIN dbo.ORDERS O WITH (NOLOCK) ON (PH.OrderKey = O.OrderKey AND O.Route <> 'R') -- Exclude those by own order carton no
                        JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
                        WHERE O.StorerKey = @c_Storerkey AND O.OrderGroup = @c_OrderGrp
                     END
                  END
               END

               -- Increase carton no
               IF @c_RefNo = '0' -- 1st carton
               BEGIN
                  SET @c_RefNo = CAST(@c_Stop AS INT) + 1
               END
               ELSE
               BEGIN
                  SET @c_RefNo = CAST(@c_RefNo AS INT) + 1
               END

               -- Add prefix
               SET @c_RefNo = TRIM(@c_DelNote) + TRIM(@c_RefNo)

               SET @n_LabelLineNo = @n_LabelLineNo + 1
               SET @c_LabelLineNo = RIGHT('00000' + RTRIM(CAST(@n_LabelLineNo AS NVARCHAR)), 5)

               INSERT INTO PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, AddWho, AddDate
                                     , EditWho, EditDate, RefNo)
               VALUES (@c_PickslipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_Storerkey, @c_Sku, @n_Qty, SUSER_SNAME()
                     , GETDATE(), SUSER_SNAME(), GETDATE(), @c_RefNo)

               SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                       , @n_Err = 38025
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Insert Error On PACKDETAIL Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                                     + RTRIM(@c_ErrMsg) + ' ) '
               END
            
               INSERT INTO dbo.PackDetailInfo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, UserDefine01
                                             , UserDefine02, UserDefine03, QTY)
               VALUES (@c_PickslipNo, @n_CartonNo, @c_LabelNo, @c_LabelLineNo, @c_Storerkey, @c_Sku, @c_Lottable01
                     , @c_Lottable01, @c_ExtLineNo, @n_Qty)

               SET @n_Err = @@ERROR

               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                       , @n_Err = 38030
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Insert Error On PACKDETAILINFO Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                                     + RTRIM(@c_ErrMsg) + ' ) '
               END
            END

            IF NOT EXISTS (SELECT 1
                           FROM PACKINFO PIF (NOLOCK)
                           WHERE PIF.PickSlipNo = @c_PickslipNo
                           AND PIF.CartonNo = @n_CartonNo)
            BEGIN
               INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, [Weight], [Cube], Qty, CartonType
                                       , [Length], Width, Height)
               SELECT @c_PickslipNo, @n_CartonNo, SKU.STDGROSSWGT, SKU.STDCUBE, @n_Qty, 'LP'
                    , SKU.[Length], SKU.Width, SKU.Height
               FROM SKU (NOLOCK)
               WHERE SKU.StorerKey = @c_Storerkey
               AND SKU.SKU = @c_Sku

               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                       , @n_Err = 38035
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Insert Error On PACKINFO Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                                     + RTRIM(@c_ErrMsg) + ' ) '
               END
            END
            ELSE
            BEGIN
               ;WITH UPD AS (SELECT SKU.STDGROSSWGT, SKU.STDCUBE
                                  , SKU.[Length], SKU.Width, SKU.Height
                                  , @c_PickslipNo AS Pickslipno
                                  , @n_CartonNo AS CartonNo
                             FROM SKU (NOLOCK)
                             WHERE SKU.StorerKey = @c_Storerkey
                             AND SKU.SKU = @c_Sku)
               UPDATE PACKINFO WITH (ROWLOCK)
               SET CartonType = 'LP'
                  , [Weight] = UPD.STDGROSSWGT
                  , [Cube] = UPD.STDCUBE
                  , [Length] = UPD.[Length]
                  , Width = UPD.Width
                  , Height = UPD.Height
               FROM PACKINFO
               JOIN UPD WITH (NOLOCK) ON UPD.Pickslipno = PackInfo.PickSlipNo
                                     AND UPD.CartonNo = PackInfo.CartonNo
               WHERE PACKINFO.PickSlipNo = @c_PickslipNo
               AND PACKINFO.CartonNo = @n_CartonNo

               IF @n_Err <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                       , @n_Err = 38040
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                     + ': Update Error On PACKINFO Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                                     + RTRIM(@c_ErrMsg) + ' ) '
               END
            END

            FETCH NEXT FROM CUR_PICKDETAIL
            INTO @c_Sku
               , @n_Qty
               , @c_UOM
               , @c_Lottable01
               , @c_Lottable02
               , @c_ExtLineNo
         END
         CLOSE CUR_PICKDETAIL
         DEALLOCATE CUR_PICKDETAIL

         UPDATE PickingInfo WITH (ROWLOCK)
         SET ScanOutDate = GETDATE()
         WHERE PickSlipNo = @c_PickslipNo AND (ScanOutDate IS NULL OR ScanOutDate = '1900-01-01')

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 38045
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + ': Update Error On PICKINGINFO Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_ErrMsg) + ' ) '
         END
         /*
         UPDATE PackHeader WITH (ROWLOCK)
         SET Status = '9'
         WHERE PickSlipNo = @c_PickslipNo

         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 38050
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + ': Update Error On PACKHEADER Table. (ispWAVPK18)' + ' ( ' + ' SQLSvr MESSAGE='
                               + RTRIM(@c_ErrMsg) + ' ) '
         END
         */
         FETCH NEXT FROM CUR_DISCPACK
         INTO @c_Orderkey
            , @c_Storerkey
            , @c_OrderGrp
            , @c_DelNote
            , @c_Stop
            , @c_Route
            , @c_ExternOrderkey
      END
      CLOSE CUR_DISCPACK
      DEALLOCATE CUR_DISCPACK
   END

   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process AND Return  
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispWAVPK18'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012  
      --RAISERROR @nErr @cErrmsg  
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO