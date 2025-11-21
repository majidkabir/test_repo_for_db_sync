SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_POD_RULES_200001_10             */
/* Creation Date: 01-Feb-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24517 - POD - Perform insert into POD target table      */
/*                                                                      */
/* Usage:  @c_InParm1 = '1' Update Or Ignore                            */
/*                                                                      */
/* Version: 1.1                                                         */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 01-Feb-2024  WLChooi   1.0   DevOps Combine Script                   */
/* 29-Feb-2024  WLChooi   1.1   Bug Fix - Remove Columns (WL01)         */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_POD_RULES_200001_10] (
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

   DECLARE @n_RowRefNo           BIGINT
         , @c_ttlMsg             NVARCHAR(250)
         , @c_Storerkey          NVARCHAR(15)
         , @c_Mbolkey            NVARCHAR(10)
         , @c_Mbollinenumber     NVARCHAR(10)
         , @c_ExternOrderKey     NVARCHAR(50)

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

   DECLARE C_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , Mbolkey
        , Mbollinenumber
        , ExternOrderkey
        , Storerkey
   FROM dbo.SCE_DL_POD_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status = '1'

   OPEN C_INS
   FETCH NEXT FROM C_INS
   INTO @n_RowRefNo
      , @c_Mbolkey
      , @c_Mbollinenumber
      , @c_ExternOrderKey
      , @c_Storerkey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      IF EXISTS ( SELECT 1
                  FROM POD (NOLOCK) 
                  WHERE POD.ExternOrderKey = @c_ExternOrderKey
                  AND POD.Storerkey = @c_Storerkey
                  AND POD.Mbolkey = @c_Mbolkey ) AND @c_InParm1 = '1'
      BEGIN
         UPDATE dbo.POD WITH (ROWLOCK)
         SET InvoiceNo = ISNULL(STG.InvoiceNo, POD.InvoiceNo)
           , [Status] = ISNULL(STG.[Status], POD.[Status])
           , ActualDeliveryDate = ISNULL(STG.ActualDeliveryDate, POD.ActualDeliveryDate)
           , InvDespatchDate = ISNULL(STG.InvDespatchDate, POD.InvDespatchDate)
           , PodReceivedDate = ISNULL(STG.PodReceivedDate, POD.PodReceivedDate)
           , PodFiledDate = ISNULL(STG.PodFiledDate, POD.PodFiledDate)
           , InvCancelDate = ISNULL(STG.InvCancelDate, POD.InvCancelDate)
           , RedeliveryDate = ISNULL(STG.RedeliveryDate, POD.RedeliveryDate)
           , FullRejectDate = ISNULL(STG.FullRejectDate, POD.FullRejectDate)
           , PartialRejectDate = ISNULL(STG.PartialRejectDate, POD.PartialRejectDate)
           , RejectReasonCode = ISNULL(STG.RejectReasonCode, POD.RejectReasonCode)
           , EditWho = STG.AddWho
           , EditDate = GETDATE()
         FROM dbo.SCE_DL_POD_STG STG (NOLOCK)
         JOIN dbo.POD POD ON (   STG.Storerkey = POD.Storerkey
                             AND POD.ExternOrderKey = STG.ExternOrderKey
                             AND POD.Mbolkey = STG.Mbolkey
                             AND POD.Mbollinenumber = STG.Mbollinenumber)
         WHERE POD.Mbolkey = @c_MBOLkey
         AND   POD.Mbollinenumber = @c_Mbollinenumber
         AND   POD.ExternOrderKey = @c_ExternOrderkey
         AND   POD.Storerkey = @c_Storerkey
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.RowRefNo = @n_RowRefNo
      END
      ELSE
      BEGIN
         INSERT INTO dbo.POD (Mbolkey, Mbollinenumber, LoadKey, Storerkey, OrderKey, BuyerPO, ExternOrderKey, InvoiceNo, Status
                            , ActualDeliveryDate, InvDespatchDate, PodReceivedDate, PodFiledDate, InvCancelDate, RedeliveryDate
                            , RedeliveryCount, FullRejectDate, ReturnRefNo, PartialRejectDate, RejectReasonCode, PoisonFormDate
                            , PoisonFormNo, ChequeNo, ChequeAmount, ChequeDate, Notes, Notes2, PODDef01, PODDef02, PODDef03
                            , PODDef04, PODDef05, PODDef06, PODDef07, PODDef08, PODDef09, PODDate01, PODDate02, PODDate03
                            , PODDate04, PODDate05, TrackCol01, TrackCol02, TrackCol03, TrackCol04, TrackCol05, TrackDate01
                            , TrackDate02, TrackDate03, TrackDate04, TrackDate05, FinalizeFlag, EditWho, EditDate
                            , SpecialHandling, Latitude, Longtitude, ExternLoadKey, RefDocID
                            --, Notes3, TrackCol06, TrackCol07, TrackCol08, TrackCol09   --WL01
                            )   
         SELECT STG.Mbolkey
              , STG.Mbollinenumber
              , STG.LoadKey
              , STG.Storerkey
              , STG.OrderKey
              , ISNULL(STG.BuyerPO, '')
              , STG.ExternOrderKey
              , ISNULL(STG.InvoiceNo, '')
              , ISNULL(STG.[Status], 0)
              , STG.ActualDeliveryDate
              , STG.InvDespatchDate
              , STG.PodReceivedDate
              , STG.PodFiledDate
              , STG.InvCancelDate
              , STG.RedeliveryDate
              , ISNULL(STG.RedeliveryCount, 0)
              , STG.FullRejectDate
              , ISNULL(STG.ReturnRefNo, '')
              , STG.PartialRejectDate
              , ISNULL(STG.RejectReasonCode, '')
              , STG.PoisonFormDate
              , STG.PoisonFormNo
              , ISNULL(STG.ChequeNo, '')
              , STG.ChequeAmount
              , STG.ChequeDate
              , ISNULL(STG.Notes, '')
              , ISNULL(STG.Notes2, '')
              , ISNULL(STG.PODDef01, '')
              , ISNULL(STG.PODDef02, '')
              , ISNULL(STG.PODDef03, '')
              , ISNULL(STG.PODDef04, '')
              , ISNULL(STG.PODDef05, '')
              , ISNULL(STG.PODDef06, '')
              , ISNULL(STG.PODDef07, '')
              , ISNULL(STG.PODDef08, '')
              , ISNULL(STG.PODDef09, '')
              , STG.PODDate01
              , STG.PODDate02
              , STG.PODDate03
              , STG.PODDate04
              , STG.PODDate05
              , ISNULL(STG.TrackCol01, '')
              , ISNULL(STG.TrackCol02, '')
              , ISNULL(STG.TrackCol03, '')
              , ISNULL(STG.TrackCol04, '')
              , ISNULL(STG.TrackCol05, '')
              , STG.TrackDate01
              , STG.TrackDate02
              , STG.TrackDate03
              , STG.TrackDate04
              , STG.TrackDate05
              , ISNULL(STG.FinalizeFlag, 'N')
              , SUSER_SNAME()
              , GETDATE()
              , ISNULL(SpecialHandling, 'N')
              , ISNULL(Latitude, '')
              , ISNULL(Longtitude, '')
              , ISNULL(ExternLoadKey, '')
              , ISNULL(RefDocID, '')
              --, ISNULL(Notes3, '')       --WL01
              --, ISNULL(TrackCol06, '')   --WL01
              --, ISNULL(TrackCol07, '')   --WL01
              --, ISNULL(TrackCol08, '')   --WL01
              --, ISNULL(TrackCol09, '')   --WL01
         FROM SCE_DL_POD_STG STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1' AND RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      UPDATE dbo.SCE_DL_POD_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXT_ITEM:

      FETCH NEXT FROM C_INS
      INTO @n_RowRefNo
         , @c_Mbolkey
         , @c_Mbollinenumber
         , @c_ExternOrderKey
         , @c_Storerkey
   END
   CLOSE C_INS
   DEALLOCATE C_INS

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_INS') IN (0 , 1)
   BEGIN
      CLOSE C_INS
      DEALLOCATE C_INS   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_POD_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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