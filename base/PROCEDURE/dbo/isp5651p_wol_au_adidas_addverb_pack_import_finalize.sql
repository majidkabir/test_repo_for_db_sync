SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store Procedure:  isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize */
/* Creation Date: 28-Jun-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: YTKuek                                                    */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 1.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver   Purposes                                  */
/* 2022-08-02   SYCHUA   1.0   Let system handle Packdetail timestamp to */
/*                             fix DM sync, skip trigger to prevent      */
/*                             PackInfo misalignment (SY01)              */
/*************************************************************************/

CREATE   PROC [dbo].[isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize] (
           @c_StorerKey          NVARCHAR(15)
         , @c_OrderKey           NVARCHAR(10)
         , @c_PickSlipNo         NVARCHAR(10)
         , @b_Debug              INT
         , @b_Success            INT             = 0   OUTPUT
         , @n_Err                INT             = 0   OUTPUT
         , @c_ErrMsg             NVARCHAR(250)   = ''  OUTPUT

)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /**************************************/
   /* Variables Declaration (Start)      */
   /**************************************/
   --General
   DECLARE @n_Continue                 INT
         , @n_StartTCnt                INT
         , @c_ExecStatements           NVARCHAR(4000)
         , @c_ExecArguments            NVARCHAR(4000)
         , @n_Exists                   INT
         , @c_Status                   NVARCHAR(1)

   DECLARE @n_Done                     INT
         , @c_PackDetail_SKU           NVARCHAR(20)
         , @n_PackDetail_Qty           INT
         , @n_PickDetail_Qty           INT
         , @c_PickDetail_SKU           NVARCHAR(20)
         , @c_PickDetailKey            NVARCHAR(10)
         , @c_PickDetailKey_New        NVARCHAR(10)
         , @c_PackDetail_LabelNo       NVARCHAR(20)
         , @c_PackDetail_LabelLine     NVARCHAR(5)
         , @c_PackDetail_LabelLine_NEW NVARCHAR(5)
         , @n_PackDetail_CartonNo      INT

   --General
   SET @n_Continue                     = 0
   SET @n_StartTCnt                    = 0
   SET @c_ExecStatements               = ''
   SET @c_ExecArguments                = ''
   SET @n_Exists                       = 0
   SET @c_Status                       = ''

   SET @n_Done                         = 0
   SET @c_PackDetail_SKU               = ''
   SET @n_PackDetail_Qty               = 0
   SET @n_PickDetail_Qty               = 0
   SET @c_PickDetail_SKU               = ''
   SET @c_PickDetailKey                = ''
   SET @c_PickDetailKey_New            = ''
   SET @c_PackDetail_LabelNo           = ''
   SET @c_PackDetail_LabelLine         = ''
   SET @c_PackDetail_LabelLine_NEW     = ''
   SET @n_PackDetail_CartonNo          = 0

   /**************************************/
   /* Variables Declaration (End)        */
   /**************************************/
   /**************************************/
   /* Finalize PackHeader (Start)        */
   /**************************************/
   BEGIN TRAN

   DECLARE C_PickDetail_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(SKU),'')
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
   AND Storerkey = @c_Storerkey
   AND DropID = ''

   OPEN C_PickDetail_LOOP
   FETCH NEXT FROM C_PickDetail_LOOP INTO @c_PickDetail_SKU

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Done                 = 0
      SET @c_PickDetailKey        = ''
      SET @n_PickDetail_Qty       = 0
      SET @c_PackDetail_LabelNo   = ''
      SET @c_PackDetail_LabelLine = ''
      SET @n_PackDetail_CartonNo  = 0
      SET @n_PackDetail_Qty       = 0

      WHILE @n_Done = 0
      BEGIN
         SELECT TOP 1 @c_PickDetailKey = ISNULL(RTRIM(PickDetailKey),'')
                     ,@n_PickDetail_Qty = Qty
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
         AND Storerkey = @c_Storerkey
         AND DropID = ''
         AND Sku = @c_PickDetail_SKU
         AND PickDetailKey > @c_PickDetailKey
         ORDER BY PickDetailKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @n_Done = 1
            BREAK
         END

         SELECT TOP 1 @c_PackDetail_LabelNo = ISNULL(RTRIM(LabelNo),'')
                     ,@c_PackDetail_LabelLine = ISNULL(RTRIM(LabelLine),'')
                     ,@n_PackDetail_CartonNo = CartonNo
                     ,@n_PackDetail_Qty = Qty
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND Storerkey = @c_Storerkey
         AND Sku = @c_PickDetail_SKU
         AND LabelNo + LabelLine > @c_PackDetail_LabelNo + @c_PackDetail_LabelLine
         ORDER BY LabelNo + LabelLine

         IF @@ROWCOUNT = 0
         BEGIN
            SET @n_Done = 1
            BREAK
         END

         IF @n_PickDetail_Qty = @n_PackDetail_Qty
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET DropID = @c_PackDetail_LabelNo
               ,CaseID = @c_PackDetail_LabelNo
               ,ArchiveCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to update PickDetail for PickDetailKey = ' + @c_PickDetailKey
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END
         END
         ELSE IF @n_PickDetail_Qty < @n_PackDetail_Qty
         BEGIN
            SET @c_PackDetail_LabelLine_NEW = ''

            SELECT @c_PackDetail_LabelLine_NEW = RIGHT('00000' + CAST(CAST(ISNULL(MAX(LabelLine), 0) AS INT) + 1 AS NVARCHAR(5)), 5)
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND CartonNo = @n_PackDetail_CartonNo

            INSERT PACKDETAIL
            (
                  PickSlipNo
               , CartonNo
               , LabelNo
               , LabelLine
               , StorerKey
               , SKU
               , Qty
               --, AddWho     --SY01
               --, AddDate    --SY01
               --, EditWho    --SY01
               --, EditDate   --SY01
               , RefNo
               , ArchiveCop
               , ExpQty
               , UPC
               , DropID
               , RefNo2
            )
            SELECT PickSlipNo
                  , CartonNo
                  , LabelNo
                  , @c_PackDetail_LabelLine_NEW
                  , StorerKey
                  , SKU
                  , @n_PackDetail_Qty - @n_PickDetail_Qty
                  --, AddWho     --SY01
                  --, AddDate    --SY01
                  --, EditWho    --SY01
                  --, EditDate   --SY01
                  , RefNo
                  , '9'  --NULL  --SY01
                  , ExpQty
                  , UPC
                  , @c_PackDetail_LabelNo
                  , RefNo2
            FROM PACKDETAIL WITH (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND Storerkey = @c_Storerkey
            AND SKU = @c_PickDetail_SKU
            AND LabelNo = @c_PackDetail_LabelNo
            AND LabelLine = @c_PackDetail_LabelLine

            --SY01 START RESET ARCHIVECOP = NULL
            UPDATE PACKDETAIL WITH (ROWLOCK)
            SET ArchiveCop = NULL
            WHERE PickSlipNo = @c_PickSlipNo
            AND Storerkey = @c_Storerkey
            AND SKU = @c_PickDetail_SKU
            AND LabelNo = @c_PackDetail_LabelNo
            AND LabelLine = @c_PackDetail_LabelLine_NEW
            --SY01 END

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to insert PackDetail for PickSlipNo = ' + @c_PickSlipNo
                              + ', LabelNo = ' + @c_PackDetail_LabelNo
                              + ', LabelLine = ' + @c_PackDetail_LabelLine
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END

            UPDATE PACKDETAIL WITH (ROWLOCK)
            SET Qty = @n_PickDetail_Qty
               ,ArchiveCop = NULL
            WHERE PickSlipNo = @c_PickSlipNo
            AND Storerkey = @c_Storerkey
            AND SKU = @c_PickDetail_SKU
            AND LabelNo = @c_PackDetail_LabelNo
            AND LabelLine = @c_PackDetail_LabelLine

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to update PackDetail for PickSlipNo = ' + @c_PickSlipNo
                              + ', LabelNo = ' + @c_PackDetail_LabelNo
                              + ', LabelLine = ' + @c_PackDetail_LabelLine
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END

            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET DropID = @c_PackDetail_LabelNo
               ,CaseID = @c_PackDetail_LabelNo
               ,ArchiveCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to update PickDetail for PickDetailKey = ' + @c_PickDetailKey
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END
         END
         ELSE IF @n_PickDetail_Qty > @n_PackDetail_Qty
         BEGIN
            -- Get new PickDetailkey
            SET @c_PickDetailKey_New = ''
            SET @b_Success = 0

            EXECUTE nspg_getkey
                    @KeyName       = 'PICKDETAILKEY'
                  , @FieldLength   = 10
                  , @KeyString     = @c_PickDetailKey_New OUTPUT
                  , @b_Success     = @b_Success           OUTPUT
                  , @n_Err         = @n_Err               OUTPUT
                  , @c_ErrMsg      = @c_ErrMsg            OUTPUT

            IF @b_Success = 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to get PickDetailKey for PickDetailKey. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END

            IF @c_PickDetailKey_New = ''
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to get PickDetailKey for PickDetailKey. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END

            INSERT INTO PickDetail
            (
               PickHeaderKey
               ,OrderKey
               ,OrderLineNumber
               ,LOT
               ,StorerKey
               ,SKU
               ,AltSKU
               ,UOM
               ,UOMQTY
               ,LOC
               ,ID
               ,PackKey
               ,UpdateSource
               ,CartonGroup
               ,CartonType
               ,ToLoc
               ,DoReplenish
               ,ReplenishZone
               ,DoCartonize
               ,PickMethod
               ,WaveKey
               ,EffectiveDate
               ,ArchiveCop
               ,ShipFlag
               ,PickSlipNo
               ,TaskDetailKey
               ,TaskManagerReasonKey
               ,Notes
               ,PickDetailKey
               ,[Status]
               ,QTY
               ,QTYMoved
               ,TrafficCop
               ,OptimizeCop
            )
            SELECT PickHeaderKey
                  ,OrderKey
                  ,OrderLineNumber
                  ,LOT
                  ,StorerKey
                  ,SKU
                  ,AltSKU
                  ,UOM
                  ,UOMQTY
                  ,LOC
                  ,ID
                  ,PackKey
                  ,UpdateSource
                  ,CartonGroup
                  ,CartonType
                  ,ToLoc
                  ,DoReplenish
                  ,ReplenishZone
                  ,DoCartonize
                  ,PickMethod
                  ,WaveKey
                  ,EffectiveDate
                  ,ArchiveCop
                  ,ShipFlag
                  ,PickSlipNo
                  ,TaskDetailKey
                  ,TaskManagerReasonKey
                  ,Notes
                  ,@c_PickDetailKey_New
                  ,[Status]
                  ,@n_PickDetail_Qty - @n_PackDetail_Qty
                  ,QTYMoved
                  ,NULL
                  ,'1'
            FROM PICKDETAIL WITH (NOLOCK)
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to insert PickDetail for PickDetailKey = ' + @c_PickDetailKey
                              + ', ErrMsg (' + ERROR_MESSAGE() + ')'
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END

            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET Qty = @n_PackDetail_Qty
               ,DropID = @c_PackDetail_LabelNo
               ,CaseID = @c_PackDetail_LabelNo
               ,ArchiveCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN
               SET @n_Err = 68115
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))
                              + ': Fail to update PickDetail for PickDetailKey = ' + @c_PickDetailKey
                              + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
               GOTO QUIT
            END
         END
      END

      FETCH NEXT FROM C_PickDetail_LOOP INTO @c_PickDetail_SKU
   END
   CLOSE C_PickDetail_LOOP
   DEALLOCATE C_PickDetail_LOOP

   DECLARE C_PickDetailStatusUpdate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(PickDetailKey),'')
   FROM PICKDETAIL WITH (NOLOCK)
   WHERE OrderKey = @c_OrderKey
   AND CaseID <> ''
   AND [Status] = 0

   OPEN C_PickDetailStatusUpdate
   FETCH NEXT FROM C_PickDetailStatusUpdate INTO @c_PickDetailKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET [Status] = '5'
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
         SET @n_Err = 68119
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                           ': Fail to update PickDetail for PickDetailKey = ' +
                           @c_PickDetailKey + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
         GOTO QUIT
      END

      FETCH NEXT FROM C_PickDetailStatusUpdate INTO @c_PickDetailKey
   END
   CLOSE C_PickDetailStatusUpdate
   DEALLOCATE C_PickDetailStatusUpdate

   UPDATE PackHeader WITH (ROWLOCK)
   SET [Status] = '9'
   WHERE PickSlipNo = @c_PickSlipNo
   AND Storerkey = @c_Storerkey

   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN
      SET @n_Err = 68119
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +
                        ': Fail to update PackHeader for PickSlipNo = ' +
                        @c_PickSlipNo + '. (isp5651P_WOL_AU_Adidas_Addverb_Pack_Import_Finalize)'
      GOTO QUIT
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
   /**************************************/
   /* Finalize PackHeader (End)          */
   /**************************************/

   /***********************************************/
   /* Std - Error Handling (Start)                */
   /***********************************************/
   QUIT:

   IF CURSOR_STATUS('LOCAL' , 'C_PickDetail_LOOP') in (0 , 1)
   BEGIN
      CLOSE C_PickDetail_LOOP
      DEALLOCATE C_PickDetail_LOOP
   END

   IF CURSOR_STATUS('LOCAL' , 'C_PickDetailStatusUpdate') in (0 , 1)
   BEGIN
      CLOSE C_PickDetailStatusUpdate
      DEALLOCATE C_PickDetailStatusUpdate
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue=3  -- Error Occured
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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
   /********************************************/
   /* Std - Error Handling (End)               */
   /********************************************/
END -- End Procedure

GO