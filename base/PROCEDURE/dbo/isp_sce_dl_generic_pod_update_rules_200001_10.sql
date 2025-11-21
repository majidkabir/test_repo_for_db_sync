SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_POD_UPDATE_RULES_200001_10      */
/* Creation Date: 01-Feb-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-24517 - POD_Update - Update POD Table                   */
/*                                                                      */
/* Usage:  @c_InParm1 = 'ispXXX' Update Order InvoiceNo by Sub SP       */
/*         @c_InParm2 = '1' Update TrackCol                             */
/*         @c_InParm3 = '1' Update PODDef                               */
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
CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_POD_UPDATE_RULES_200001_10] (
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
         , @c_Orderkey           NVARCHAR(10)
         , @c_InvoiceNo          NVARCHAR(20)

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

   --Excel Loader          -> Data Loader
   --@c_UpdateOrdInvno     -> @c_InParm1
   --@c_GetORDKEYBYINV     -> @c_InParm2
   --@c_UPDATEBYEXTORDKEY  -> @c_InParm3

   BEGIN TRANSACTION

   DECLARE C_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RowRefNo
        , OrderKey
   FROM dbo.SCE_DL_POD_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status = '1'

   OPEN C_UPD
   FETCH NEXT FROM C_UPD
   INTO @n_RowRefNo
      , @c_OrderKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @c_ttlMsg = N''

      UPDATE dbo.POD WITH (ROWLOCK)
      SET PodReceivedDate    = ISNULL(STG.PodReceivedDate, POD.PodReceivedDate)
        , ActualDeliveryDate = ISNULL(STG.ActualDeliveryDate, POD.ActualDeliveryDate)
        , FullRejectDate     = ISNULL(STG.FullRejectDate, POD.FullRejectDate)
        , PartialRejectDate  = ISNULL(STG.PartialRejectDate, POD.PartialRejectDate)
        , InvDespatchDate    = ISNULL(STG.InvDespatchDate, POD.InvDespatchDate)
        , PodFiledDate       = ISNULL(STG.PodFiledDate, POD.PodFiledDate)
        , RedeliveryDate     = ISNULL(STG.RedeliveryDate, POD.RedeliveryDate)
        , PoisonFormDate     = ISNULL(STG.PoisonFormDate, POD.PoisonFormDate)
        , RedeliveryCount    = ISNULL(STG.RedeliveryCount, POD.RedeliveryCount)

        , RejectReasonCode   = IIF(ISNULL(STG.RejectReasonCode, '') = '', POD.RejectReasonCode, STG.RejectReasonCode)
        , [Status]           = IIF(ISNULL(STG.[Status]        , '') = '', POD.[Status]        , STG.[Status]        )
        , FinalizeFlag       = IIF(ISNULL(STG.FinalizeFlag    , '') = '', POD.FinalizeFlag    , STG.FinalizeFlag    )
        , InvoiceNo          = IIF(ISNULL(STG.InvoiceNo       , '') = '', POD.InvoiceNo       , STG.InvoiceNo       )
        , Notes              = IIF(ISNULL(STG.Notes           , '') = '', POD.Notes           , STG.Notes           )
        , Notes2             = IIF(ISNULL(STG.Notes2          , '') = '', POD.Notes2          , STG.Notes2          )
        --, Notes3             = IIF(ISNULL(STG.Notes3          , '') = '', POD.Notes3          , STG.Notes3          )   --WL01
        , PoisonFormNo       = IIF(ISNULL(STG.PoisonFormNo    , '') = '', POD.PoisonFormNo    , STG.PoisonFormNo    )
        , SpecialHandling    = IIF(ISNULL(STG.SpecialHandling , '') = '', POD.SpecialHandling , STG.SpecialHandling )
        , Latitude           = IIF(ISNULL(STG.Latitude        , '') = '', POD.Latitude        , STG.Latitude        )
        , Longtitude         = IIF(ISNULL(STG.Longtitude      , '') = '', POD.Longtitude      , STG.Longtitude      )
        , ExternLoadKey      = IIF(ISNULL(STG.ExternLoadKey   , '') = '', POD.ExternLoadKey   , STG.ExternLoadKey   )
        , RefDocID           = IIF(ISNULL(STG.RefDocID        , '') = '', POD.RefDocID        , STG.RefDocID        )
        , EditWho = STG.AddWho
      FROM dbo.SCE_DL_POD_STG STG (NOLOCK)
      JOIN dbo.POD POD ON (STG.OrderKey = POD.OrderKey)
      WHERE POD.OrderKey = @c_Orderkey
      AND   STG.STG_BatchNo = @n_BatchNo
      AND   STG.STG_Status = '1'
      AND   STG.RowRefNo = @n_RowRefNo

      IF ISNULL(@c_InParm1, '') <> ''
      BEGIN
         SELECT @c_InvoiceNo = ISNULL(STG.InvoiceNo, '')
         FROM dbo.SCE_DL_POD_STG STG (NOLOCK)
         WHERE STG.RowRefNo = @n_RowRefNo

         IF ISNULL(@c_InvoiceNo, '') <> ''
         BEGIN
            SET @c_ExecStatements = N''
            SET @c_ExecArguments = N''

            SET @c_ExecStatements = N' EXEC ' + TRIM(@c_InParm1) + CHAR(13)
                                  + N'   @b_Debug          ' + CHAR(13)
                                  + N' , @n_BatchNo        ' + CHAR(13)
                                  + N' , @n_Flag           ' + CHAR(13)
                                  + N' , @c_SubRuleJson    ' + CHAR(13)
                                  + N' , @c_STGTBL         ' + CHAR(13)
                                  + N' , @c_POSTTBL        ' + CHAR(13)
                                  + N' , @c_UniqKeyCol     ' + CHAR(13)
                                  + N' , @c_Username       ' + CHAR(13)
                                  + N' , @c_Storerkey      ' + CHAR(13)
                                  + N' , @b_Success OUTPUT ' + CHAR(13)
                                  + N' , @n_ErrNo   OUTPUT ' + CHAR(13)
                                  + N' , @c_ErrMsg  OUTPUT ' + CHAR(13)

            SET @c_ExecArguments = N'   @b_Debug       INT                  ' + CHAR(13)
                                 + N' , @n_BatchNo     INT                  ' + CHAR(13)
                                 + N' , @n_Flag        INT                  ' + CHAR(13)
                                 + N' , @c_SubRuleJson NVARCHAR(MAX)        ' + CHAR(13)
                                 + N' , @c_STGTBL      NVARCHAR(250)        ' + CHAR(13)
                                 + N' , @c_POSTTBL     NVARCHAR(250)        ' + CHAR(13)
                                 + N' , @c_UniqKeyCol  NVARCHAR(1000)       ' + CHAR(13)
                                 + N' , @c_Username    NVARCHAR(128)        ' + CHAR(13)
                                 + N' , @c_Storerkey   NVARCHAR(15)         ' + CHAR(13)
                                 + N' , @b_Success     INT OUTPUT           ' + CHAR(13)
                                 + N' , @n_ErrNo       INT OUTPUT           ' + CHAR(13)
                                 + N' , @c_ErrMsg      NVARCHAR(250) OUTPUT ' + CHAR(13)

            EXEC sp_executesql @c_ExecStatements
                             , @c_ExecArguments
                             , @b_Debug      
                             , @n_BatchNo    
                             , @n_Flag       
                             , @c_SubRuleJson
                             , @c_STGTBL     
                             , @c_POSTTBL    
                             , @c_UniqKeyCol 
                             , @c_Username  
                             , @c_Storerkey
                             , @b_Success OUTPUT    
                             , @n_ErrNo   OUTPUT    
                             , @c_ErrMsg  OUTPUT    
                               

            IF @n_ErrNo <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END
      END

      IF @c_InParm2 = '1'
      BEGIN
         UPDATE dbo.POD WITH (ROWLOCK)
         SET TrackDate01 = ISNULL(STG.TrackDate01, POD.TrackDate01)
           , TrackDate02 = ISNULL(STG.TrackDate02, POD.TrackDate02)
           , TrackDate03 = ISNULL(STG.TrackDate03, POD.TrackDate03)
           , TrackDate04 = ISNULL(STG.TrackDate04, POD.TrackDate04)
           , TrackDate05 = ISNULL(STG.TrackDate05, POD.TrackDate05)
           , TrackCol01 = IIF(ISNULL(STG.TrackCol01, '') = '', POD.TrackCol01, STG.TrackCol01)
           , TrackCol02 = IIF(ISNULL(STG.TrackCol02, '') = '', POD.TrackCol02, STG.TrackCol02)
           , TrackCol03 = IIF(ISNULL(STG.TrackCol03, '') = '', POD.TrackCol03, STG.TrackCol03)
           , TrackCol04 = IIF(ISNULL(STG.TrackCol04, '') = '', POD.TrackCol04, STG.TrackCol04)
           , TrackCol05 = IIF(ISNULL(STG.TrackCol05, '') = '', POD.TrackCol05, STG.TrackCol05)
           --, TrackCol06 = IIF(ISNULL(STG.TrackCol06, '') = '', POD.TrackCol06, STG.TrackCol06)   --WL01
           --, TrackCol07 = IIF(ISNULL(STG.TrackCol07, '') = '', POD.TrackCol07, STG.TrackCol07)   --WL01
           --, TrackCol08 = IIF(ISNULL(STG.TrackCol08, '') = '', POD.TrackCol08, STG.TrackCol08)   --WL01
           --, TrackCol09 = IIF(ISNULL(STG.TrackCol09, '') = '', POD.TrackCol09, STG.TrackCol09)   --WL01
           , FinalizeFlag = IIF(ISNULL(STG.FinalizeFlag, '') = '', POD.FinalizeFlag, STG.FinalizeFlag)
           , EditWho = STG.AddWho
         FROM dbo.SCE_DL_POD_STG STG (NOLOCK)
         JOIN dbo.POD POD ON (STG.OrderKey = POD.OrderKey)
         WHERE POD.OrderKey = @c_Orderkey
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.RowRefNo = @n_RowRefNo
      END
      
      IF @c_InParm3 = '1'
      BEGIN
         UPDATE dbo.POD WITH (ROWLOCK)
         SET PODDate01 = ISNULL(STG.PODDate01, POD.PODDate01)
           , PODDate02 = ISNULL(STG.PODDate02, POD.PODDate02)
           , PODDate03 = ISNULL(STG.PODDate03, POD.PODDate03)
           , PODDate04 = ISNULL(STG.PODDate04, POD.PODDate04)
           , PODDate05 = ISNULL(STG.PODDate05, POD.PODDate05)
           , PODDef01 = IIF(ISNULL(STG.PODDef01, '') = '', POD.PODDef01, STG.PODDef01)
           , PODDef02 = IIF(ISNULL(STG.PODDef02, '') = '', POD.PODDef02, STG.PODDef02)
           , PODDef03 = IIF(ISNULL(STG.PODDef03, '') = '', POD.PODDef03, STG.PODDef03)
           , PODDef04 = IIF(ISNULL(STG.PODDef04, '') = '', POD.PODDef04, STG.PODDef04)
           , PODDef05 = IIF(ISNULL(STG.PODDef05, '') = '', POD.PODDef05, STG.PODDef05)
           , PODDef06 = IIF(ISNULL(STG.PODDef06, '') = '', POD.PODDef06, STG.PODDef06)
           , PODDef07 = IIF(ISNULL(STG.PODDef07, '') = '', POD.PODDef07, STG.PODDef07)
           , PODDef08 = IIF(ISNULL(STG.PODDef08, '') = '', POD.PODDef08, STG.PODDef08)
           , PODDef09 = IIF(ISNULL(STG.PODDef09, '') = '', POD.PODDef09, STG.PODDef09)
           , EditWho = STG.AddWho
         FROM dbo.SCE_DL_POD_STG STG (NOLOCK)
         JOIN dbo.POD POD ON (STG.OrderKey = POD.OrderKey)
         WHERE POD.OrderKey = @c_Orderkey
         AND   STG.STG_BatchNo = @n_BatchNo
         AND   STG.STG_Status = '1'
         AND   STG.RowRefNo = @n_RowRefNo
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

      FETCH NEXT FROM C_UPD
      INTO @n_RowRefNo
         , @c_OrderKey
   END
   CLOSE C_UPD
   DEALLOCATE C_UPD

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:

   IF CURSOR_STATUS('LOCAL', 'C_UPD') IN (0 , 1)
   BEGIN
      CLOSE C_UPD
      DEALLOCATE C_UPD   
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_POD_UPDATE_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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