SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_SERIALNO_RULES_200001_10        */
/* Creation Date: 11-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose: WMS-20743 - Perform delete or insert into SERIALNO table    */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 = '0' Ignore update             */
/*                           @c_InParm1 = '1' Update is allow           */
/*                           @c_InParm2 = '|' Delimiter symbol          */
/*                           @c_InParm3 = '1' ByPass Checking           */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 11-May-2022  GHChan    1.1   Initial                                 */
/* 08-Sep-2022  WLChooi   1.1   DevOps Combine Script                   */
/* 11-Aug-2023  WLChooi   1.2   WMS-23260 - Add Lot (WL01)              */
/* 15-Aug-2023  WLChooi   1.3   JSM-170432 - Extend Length (WL02)       */
/* 15-Aug-2023  WLChooi   1.4   Performance Tuning (WL03)               */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_SERIALNO_RULES_200001_10] (
   @b_Debug       INT            = 0
 , @n_BatchNo     INT            = 0
 , @n_Flag        INT            = 0
 , @c_SubRuleJson NVARCHAR(MAX)
 , @c_STGTBL      NVARCHAR(250)  = ''
 , @c_POSTTBL     NVARCHAR(250)  = ''
 , @c_UniqKeyCol  NVARCHAR(1000) = ''
 , @c_Username    NVARCHAR(128)  = ''
 , @b_Success     INT            = 0 OUTPUT
 , @n_ErrNo       INT            = 0 OUTPUT
 , @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60)
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_Storerkey          NVARCHAR(15)
         , @c_ExternWorkOrderKey NVARCHAR(20)
         , @c_WorkOrderKey       NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_AdjustmentType     NVARCHAR(5)
         , @n_RowRefNo           INT
         , @c_SerialNoKey        NVARCHAR(10)
         , @c_SKU                NVARCHAR(20)
         , @n_iNo                INT
         , @c_SerialNo           NVARCHAR(50)   --WL02
         , @c_ActionFlag         NVARCHAR(2)
         , @c_OrderKey           NVARCHAR(10)
         , @c_tempSerialNo       NVARCHAR(50)   --WL02
         , @c_ttlMsg             NVARCHAR(250)
         , @n_Count              INT = 0
         , @c_Update             NVARCHAR(10)

   CREATE TABLE #TMP_SERIALNO (SerialNo NVARCHAR(50), Upd NVARCHAR(5) NULL )   --WL02
   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (
      SPName NVARCHAR(300) '$.SubRuleSP'
    , InParm1 NVARCHAR(60) '$.InParm1'
    , InParm2 NVARCHAR(60) '$.InParm2'
    , InParm3 NVARCHAR(60) '$.InParm3'
    , InParm4 NVARCHAR(60) '$.InParm4'
    , InParm5 NVARCHAR(60) '$.InParm5'
      )
   WHERE SPName = OBJECT_NAME(@@PROCID)

   BEGIN TRANSACTION

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RTRIM(SerialNo)
                 , ISNULL(RTRIM(ActionFlag), '')
                 , ISNULL(RTRIM(OrderKey), '')
                 , ISNULL(RTRIM(StorerKey), '')
                 , ISNULL(RTRIM(Sku), '')
   FROM dbo.SCE_DL_SERIALNO_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'

   OPEN C_HDR
   FETCH NEXT FROM C_HDR
   INTO @c_SerialNo
      , @c_ActionFlag
      , @c_OrderKey
      , @c_Storerkey
      , @c_SKU

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_SERIALNO_STG WITH (NOLOCK)
      WHERE STG_BatchNo                = @n_BatchNo
      AND   STG_Status                 = '1'
      AND   ISNULL(StorerKey,'')       = @c_Storerkey
      AND   ISNULL(TRIM(OrderKey),'')  = @c_OrderKey
      AND   ISNULL(TRIM(Sku),'')       = @c_SKU
      AND   ISNULL(TRIM(SerialNo),'')  = @c_SerialNo
      AND   ISNULL(RTRIM(ActionFlag), '') = @c_ActionFlag   --WL03
      ORDER BY STG_SeqNo ASC

      IF @c_InParm2 <> ''
      BEGIN
         INSERT INTO #TMP_SERIALNO (SerialNo, Upd)
         SELECT ISNULL(RTRIM([value]), ''), ''
         FROM STRING_SPLIT(@c_SerialNo, @c_InParm2)
      END
      ELSE
      BEGIN
         INSERT INTO #TMP_SERIALNO (SerialNo)
         VALUES
         (@c_SerialNo)
      END
      
      DECLARE CUR_VAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SerialNo
      FROM #TMP_SERIALNO 
      ORDER BY SerialNo ASC

      OPEN CUR_VAL

      FETCH NEXT FROM CUR_VAL INTO @c_tempSerialNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_InParm3 = '0'
         BEGIN
            SET @n_Count = 0
            
            SELECT @n_Count = COUNT(1)
            FROM BI.V_SERIALNO WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
            AND   SKU      = @c_SKU
            AND   SerialNo = @c_tempSerialNo

            IF @n_Count >= 1 SET @n_Count = 1

            IF @n_Count <> 1
            BEGIN
               IF @c_ActionFlag = 'D'
               BEGIN
                  SET @c_ttlMsg += N'/Delete failed. OrderKey(' + @c_OrderKey + N'), Sku(' + @c_SKU + N'), SerialNo.('
                                   + @c_tempSerialNo + N') not exists '
               END
            END

            IF @n_Count = 1
            BEGIN
               IF @c_ActionFlag = 'A' AND @c_InParm1 = '0'
               BEGIN
                  SET @c_ttlMsg += N'/Insert failed. OrderKey(' + @c_OrderKey + N'), Sku(' + @c_SKU + N'), SerialNo.('
                                   + @c_tempSerialNo + N') already exists '
               END
               ELSE IF @c_ActionFlag = 'A' AND @c_InParm1 = '1'
               BEGIN
                  UPDATE #TMP_SERIALNO
                  SET Upd = 'Y'
                  WHERE SerialNo = @c_tempSerialNo
               END
            END
         END
         ELSE IF @c_InParm3 = '1'
         BEGIN
            SET @n_Count = 0

            SELECT @n_Count = COUNT(1)
            FROM BI.V_SERIALNO WITH (NOLOCK)
            WHERE StorerKey   = @c_StorerKey
            AND   SKU         = @c_SKU
            AND   SerialNo    = @c_tempSerialNo

            IF @n_Count >= 1 SET @n_Count = 1

            IF @n_Count <> 1
            BEGIN
               IF @c_ActionFlag = 'D'
               BEGIN
                  SET @c_ttlMsg += N'/Delete failed. StorerKey(' + @c_StorerKey + N'), Sku(' + @c_SKU + N'), SerialNo.('
                                   + @c_tempSerialNo + N') not exists '
               END
            END

            IF @n_Count = 1
            BEGIN
               IF @c_ActionFlag = 'A' AND @c_InParm1 = '0'
               BEGIN
                  SET @c_ttlMsg += N'/Insert failed. StorerKey(' + @c_StorerKey + N'), Sku(' + @c_SKU + N'), SerialNo.('
                                   + @c_tempSerialNo + N') already exists '
               END
               ELSE IF @c_ActionFlag = 'A' AND @c_InParm1 = '1'
               BEGIN
                  UPDATE #TMP_SERIALNO
                  SET Upd = 'Y'
                  WHERE SerialNo = @c_tempSerialNo
               END
            END
         END
         
         IF @c_ttlMsg <> ''
         BEGIN
            UPDATE dbo.SCE_DL_SERIALNO_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = @c_ttlMsg
            WHERE STG_BatchNo                   = @n_BatchNo
            AND   STG_Status                    = '1'
            AND   RTRIM(SerialNo)               = @c_SerialNo
            AND   ISNULL(RTRIM(ActionFlag), '') = @c_ActionFlag
            AND   ISNULL(RTRIM(OrderKey), '')   = @c_OrderKey
            AND   ISNULL(RTRIM(StorerKey), '')  = @c_Storerkey
            AND   ISNULL(RTRIM(Sku), '')        = @c_SKU
            
            UPDATE #TMP_SERIALNO
            SET UPD = 'ERROR'
            WHERE SerialNo = @c_tempSerialNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END

         FETCH NEXT FROM CUR_VAL INTO @c_tempSerialNo
      END
      CLOSE CUR_VAL
      DEALLOCATE CUR_VAL

      SET @c_tempSerialNo = ''

      DECLARE CUR_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT SerialNo, CASE WHEN ISNULL(Upd,'N') = 'Y' THEN 'Y' ELSE 'N' END
      FROM #TMP_SERIALNO 
      WHERE Upd <> 'ERROR'
      ORDER BY SerialNo ASC

      OPEN CUR_INS

      FETCH NEXT FROM CUR_INS INTO @c_tempSerialNo, @c_Update

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_ActionFlag = 'A'
         BEGIN
            IF @c_Update = 'Y' AND @c_InParm3 = '0'
            BEGIN
               UPDATE SN WITH (ROWLOCK)
               SET   SN.OrderKey        = CASE WHEN ISNULL(TRIM(STG.Orderkey       ),'') = '' THEN SN.OrderKey        ELSE ISNULL(TRIM(STG.Orderkey       ),'') END
                   , SN.OrderLineNumber = CASE WHEN ISNULL(TRIM(STG.OrderLineNumber),'') = '' THEN SN.OrderLineNumber ELSE ISNULL(TRIM(STG.OrderLineNumber),'') END
                   --, SN.StorerKey       = CASE WHEN ISNULL(TRIM(STG.StorerKey      ),'') = '' THEN SN.StorerKey       ELSE ISNULL(TRIM(STG.StorerKey      ),'') END
                   , SN.SKU             = CASE WHEN ISNULL(TRIM(STG.SKU            ),'') = '' THEN SN.SKU             ELSE ISNULL(TRIM(STG.SKU            ),'') END
                   , SN.SerialNo        = CASE WHEN ISNULL(TRIM(STG.SerialNo       ),'') = '' THEN SN.SerialNo        ELSE ISNULL(TRIM(STG.SerialNo       ),'') END
                   , SN.Qty             = CASE WHEN ISNULL(STG.Qty                  ,0)  = 0  THEN SN.Qty             ELSE ISNULL(STG.Qty                  ,0)  END
                   --, SN.AddWho          = CASE WHEN ISNULL(TRIM(STG.AddWho         ),'') = '' THEN SN.AddWho          ELSE ISNULL(TRIM(STG.AddWho         ),'') END
                   , SN.Status          = CASE WHEN ISNULL(TRIM(STG.Status         ),'') = '' THEN SN.Status          ELSE ISNULL(TRIM(STG.Status         ),'') END
                   , SN.LotNo           = CASE WHEN ISNULL(TRIM(STG.LotNo          ),'') = '' THEN SN.LotNo           ELSE ISNULL(TRIM(STG.LotNo          ),'') END
                   , SN.ID              = CASE WHEN ISNULL(TRIM(STG.ID             ),'') = '' THEN SN.ID              ELSE ISNULL(TRIM(STG.ID             ),'') END
                   , SN.ExternStatus    = CASE WHEN ISNULL(TRIM(STG.ExternStatus   ),'') = '' THEN SN.ExternStatus    ELSE ISNULL(TRIM(STG.ExternStatus   ),'') END
                   , SN.PickSlipNo      = CASE WHEN ISNULL(TRIM(STG.PickSlipNo     ),'') = '' THEN SN.PickSlipNo      ELSE ISNULL(TRIM(STG.PickSlipNo     ),'') END
                   , SN.CartonNo        = CASE WHEN ISNULL(STG.CartonNo             ,0)  = '' THEN SN.CartonNo        ELSE ISNULL(STG.CartonNo             ,0)  END
                   , SN.UserDefine01    = CASE WHEN ISNULL(TRIM(STG.UserDefine01   ),'') = '' THEN SN.UserDefine01    ELSE ISNULL(TRIM(STG.UserDefine01   ),'') END
                   , SN.UserDefine02    = CASE WHEN ISNULL(TRIM(STG.UserDefine02   ),'') = '' THEN SN.UserDefine02    ELSE ISNULL(TRIM(STG.UserDefine02   ),'') END
                   , SN.UserDefine03    = CASE WHEN ISNULL(TRIM(STG.UserDefine03   ),'') = '' THEN SN.UserDefine03    ELSE ISNULL(TRIM(STG.UserDefine03   ),'') END
                   , SN.UserDefine04    = CASE WHEN ISNULL(TRIM(STG.UserDefine04   ),'') = '' THEN SN.UserDefine04    ELSE ISNULL(TRIM(STG.UserDefine04   ),'') END
                   , SN.UserDefine05    = CASE WHEN ISNULL(TRIM(STG.UserDefine05   ),'') = '' THEN SN.UserDefine05    ELSE ISNULL(TRIM(STG.UserDefine05   ),'') END
                   , SN.LabelLine       = CASE WHEN ISNULL(TRIM(STG.LabelLine      ),'') = '' THEN SN.LabelLine       ELSE ISNULL(TRIM(STG.LabelLine      ),'') END
                   , SN.UCCNo           = CASE WHEN ISNULL(TRIM(STG.UCCNo          ),'') = '' THEN SN.UCCNo           ELSE ISNULL(TRIM(STG.UCCNo          ),'') END
                   , SN.Lot             = CASE WHEN ISNULL(TRIM(STG.Lot            ),'') = '' THEN SN.Lot             ELSE ISNULL(TRIM(STG.Lot            ),'') END   --WL01
                   , SN.EditDate        = GETDATE()
                   , SN.EditWho         = SUSER_SNAME()
               FROM SERIALNO SN
               JOIN dbo.SCE_DL_SERIALNO_STG STG WITH (NOLOCK) ON ISNULL(TRIM(STG.OrderKey), '') = SN.OrderKey
                                                             AND STG.SerialNo = SN.SerialNo
                                                             AND STG.SKU = SN.SKU
               WHERE RowRefNo = @n_RowRefNo
            END
            ELSE IF @c_Update = 'Y' AND @c_InParm3 = '1'
            BEGIN
               UPDATE SN WITH (ROWLOCK)
               SET   SN.OrderKey        = CASE WHEN ISNULL(TRIM(STG.Orderkey       ),'') = '' THEN SN.OrderKey        ELSE ISNULL(TRIM(STG.Orderkey       ),'') END
                   , SN.OrderLineNumber = CASE WHEN ISNULL(TRIM(STG.OrderLineNumber),'') = '' THEN SN.OrderLineNumber ELSE ISNULL(TRIM(STG.OrderLineNumber),'') END
                   --, SN.StorerKey       = CASE WHEN ISNULL(TRIM(STG.StorerKey      ),'') = '' THEN SN.StorerKey       ELSE ISNULL(TRIM(STG.StorerKey      ),'') END
                   , SN.SKU             = CASE WHEN ISNULL(TRIM(STG.SKU            ),'') = '' THEN SN.SKU             ELSE ISNULL(TRIM(STG.SKU            ),'') END
                   , SN.SerialNo        = CASE WHEN ISNULL(TRIM(STG.SerialNo       ),'') = '' THEN SN.SerialNo        ELSE ISNULL(TRIM(STG.SerialNo       ),'') END
                   , SN.Qty             = CASE WHEN ISNULL(STG.Qty                  ,0)  = 0  THEN SN.Qty             ELSE ISNULL(STG.Qty                  ,0)  END
                   --, SN.AddWho          = CASE WHEN ISNULL(TRIM(STG.AddWho         ),'') = '' THEN SN.AddWho          ELSE ISNULL(TRIM(STG.AddWho         ),'') END
                   , SN.Status          = CASE WHEN ISNULL(TRIM(STG.Status         ),'') = '' THEN SN.Status          ELSE ISNULL(TRIM(STG.Status         ),'') END
                   , SN.LotNo           = CASE WHEN ISNULL(TRIM(STG.LotNo          ),'') = '' THEN SN.LotNo           ELSE ISNULL(TRIM(STG.LotNo          ),'') END
                   , SN.ID              = CASE WHEN ISNULL(TRIM(STG.ID             ),'') = '' THEN SN.ID              ELSE ISNULL(TRIM(STG.ID             ),'') END
                   , SN.ExternStatus    = CASE WHEN ISNULL(TRIM(STG.ExternStatus   ),'') = '' THEN SN.ExternStatus    ELSE ISNULL(TRIM(STG.ExternStatus   ),'') END
                   , SN.PickSlipNo      = CASE WHEN ISNULL(TRIM(STG.PickSlipNo     ),'') = '' THEN SN.PickSlipNo      ELSE ISNULL(TRIM(STG.PickSlipNo     ),'') END
                   , SN.CartonNo        = CASE WHEN ISNULL(STG.CartonNo             ,0)  = '' THEN SN.CartonNo        ELSE ISNULL(STG.CartonNo             ,0)  END
                   , SN.UserDefine01    = CASE WHEN ISNULL(TRIM(STG.UserDefine01   ),'') = '' THEN SN.UserDefine01    ELSE ISNULL(TRIM(STG.UserDefine01   ),'') END
                   , SN.UserDefine02    = CASE WHEN ISNULL(TRIM(STG.UserDefine02   ),'') = '' THEN SN.UserDefine02    ELSE ISNULL(TRIM(STG.UserDefine02   ),'') END
                   , SN.UserDefine03    = CASE WHEN ISNULL(TRIM(STG.UserDefine03   ),'') = '' THEN SN.UserDefine03    ELSE ISNULL(TRIM(STG.UserDefine03   ),'') END
                   , SN.UserDefine04    = CASE WHEN ISNULL(TRIM(STG.UserDefine04   ),'') = '' THEN SN.UserDefine04    ELSE ISNULL(TRIM(STG.UserDefine04   ),'') END
                   , SN.UserDefine05    = CASE WHEN ISNULL(TRIM(STG.UserDefine05   ),'') = '' THEN SN.UserDefine05    ELSE ISNULL(TRIM(STG.UserDefine05   ),'') END
                   , SN.LabelLine       = CASE WHEN ISNULL(TRIM(STG.LabelLine      ),'') = '' THEN SN.LabelLine       ELSE ISNULL(TRIM(STG.LabelLine      ),'') END
                   , SN.UCCNo           = CASE WHEN ISNULL(TRIM(STG.UCCNo          ),'') = '' THEN SN.UCCNo           ELSE ISNULL(TRIM(STG.UCCNo          ),'') END
                   , SN.Lot             = CASE WHEN ISNULL(TRIM(STG.Lot            ),'') = '' THEN SN.Lot             ELSE ISNULL(TRIM(STG.Lot            ),'') END   --WL01
                   , SN.EditDate        = GETDATE()
                   , SN.EditWho         = SUSER_SNAME()
               FROM SERIALNO SN
               JOIN dbo.SCE_DL_SERIALNO_STG STG WITH (NOLOCK) ON STG.Storerkey = SN.StorerKey 
                                                             AND STG.SerialNo = SN.SerialNo
                                                             AND STG.SKU = SN.SKU
               WHERE RowRefNo = @n_RowRefNo
            END
            ELSE
            BEGIN
               EXEC dbo.nspg_GetKey @KeyName = 'SerialNo'
                                  , @fieldlength = 10
                                  , @keystring = @c_SerialNoKey OUTPUT
                                  , @b_Success = @b_Success OUTPUT
                                  , @n_err = @n_ErrNo OUTPUT
                                  , @c_errmsg = @c_ErrMsg OUTPUT
               
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg = 'Unable to get a new SerialNo Key from nspg_getkey.'
                  ROLLBACK TRAN
                  GOTO QUIT
               END
               
               INSERT INTO dbo.SerialNo
               (
                  SerialNoKey
                , OrderKey
                , OrderLineNumber
                , StorerKey
                , SKU
                , SerialNo
                , Qty
                , AddWho
                , Status
                , LotNo
                , ID
                , ExternStatus
                , PickSlipNo
                , CartonNo
                , UserDefine01
                , UserDefine02
                , UserDefine03
                , UserDefine04
                , UserDefine05
                , LabelLine
                , UCCNo
                , Lot   --WL01
               )
               SELECT @c_SerialNoKey
                    , ISNULL(@c_OrderKey, '')
                    , ISNULL(STG.OrderLineNumber, '')
                    , @c_Storerkey
                    , @c_SKU
                    , @c_tempSerialNo
                    , ISNULL(STG.Qty, '1')
                    , @c_Username
                    , ISNULL(STG.Status, '0')
                    , ISNULL(STG.LotNO, '')
                    , ISNULL(STG.ID, '')
                    , ISNULL(STG.ExternStatus, '')
                    , ISNULL(STG.PickSlipNo, '')
                    , ISNULL(STG.CartonNo, '')
                    , ISNULL(STG.UserDefine01, '')
                    , ISNULL(STG.UserDefine02, '')
                    , ISNULL(STG.UserDefine03, '')
                    , ISNULL(STG.UserDefine04, '')
                    , ISNULL(STG.UserDefine05, '')
                    , ISNULL(STG.LabelLine, '')
                    , ISNULL(STG.UCCNo, '')
                    , ISNULL(STG.Lot, '')   --WL01
               FROM dbo.SCE_DL_SERIALNO_STG STG WITH (NOLOCK)
               WHERE RowRefNo = @n_RowRefNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  ROLLBACK TRAN
                  GOTO QUIT
               END
            END
         END
         ELSE IF @c_ActionFlag = 'D'
         BEGIN
            IF @c_InParm3 = '0'
            BEGIN
               SELECT @c_SerialNoKey = SerialNoKey
               FROM dbo.V_SerialNo WITH (NOLOCK)
               WHERE StorerKey   = @c_Storerkey
               AND   SKU         = @c_SKU
               AND   SerialNo    = @c_tempSerialNo
            END
            ELSE IF @c_InParm3 = '1'
            BEGIN
               SELECT @c_SerialNoKey = SerialNoKey
               FROM dbo.V_SerialNo WITH (NOLOCK)
               WHERE OrderKey = @c_OrderKey
               AND   SKU      = @c_SKU
               AND   SerialNo = @c_tempSerialNo
            END

            DELETE FROM dbo.SerialNo
            WHERE SerialNoKey = @c_SerialNoKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END

         FETCH NEXT FROM CUR_INS INTO @c_tempSerialNo, @c_Update
      END
      CLOSE CUR_INS
      DEALLOCATE CUR_INS

      --WL03 S
      UPDATE dbo.SCE_DL_SERIALNO_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo   
      --WHERE STG_BatchNo                   = @n_BatchNo
      --AND   STG_Status                    = '1'
      --AND   RTRIM(SerialNo)               = @c_SerialNo
      --AND   ISNULL(RTRIM(ActionFlag), '') = @c_ActionFlag
      --AND   ISNULL(RTRIM(OrderKey), '')   = @c_OrderKey
      --AND   ISNULL(RTRIM(StorerKey), '')  = @c_Storerkey
      --AND   ISNULL(RTRIM(Sku), '')        = @c_SKU
      --WL03 E

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXTITEM:

      TRUNCATE TABLE #TMP_SERIALNO
      FETCH NEXT FROM C_HDR
      INTO @c_SerialNo
         , @c_ActionFlag
         , @c_OrderKey
         , @c_Storerkey
         , @c_SKU
   END

   CLOSE C_HDR
   DEALLOCATE C_HDR

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN (0 , 1)
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_VAL') IN (0 , 1)
   BEGIN
      CLOSE CUR_VAL
      DEALLOCATE CUR_VAL   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_INS') IN (0 , 1)
   BEGIN
      CLOSE CUR_INS
      DEALLOCATE CUR_INS   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_SERIALNO_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
   END

   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 1
   END
   ELSE
   BEGIN
      SET @b_Success = 0
   END
END
GO