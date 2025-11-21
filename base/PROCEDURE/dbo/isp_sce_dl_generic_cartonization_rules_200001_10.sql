SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CARTONIZATION_RULES_200001_10   */
/* Creation Date: 09-Sep-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20654 - Perform insert into Cartonization target table  */
/*                                                                      */
/* Usage: Random CartonizationKey @c_InParm1 =  '1' Turn On '0' Turn Off*/
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-Sep-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CARTONIZATION_RULES_200001_10] (
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

   DECLARE @c_CartonizationKey      NVARCHAR(10)
         , @c_CartonizationGroup    NVARCHAR(10)
         , @c_CartonType            NVARCHAR(10)
         , @c_CartonDescription     NVARCHAR(60)
         , @n_UseSequence           INT
         , @n_Cube                  FLOAT
         , @n_MaxWeight             FLOAT
         , @n_MaxCount              INT
         , @n_CartonWeight          FLOAT
         , @n_CartonLength          FLOAT
         , @n_CartonWidth           FLOAT
         , @n_CartonHeight          FLOAT
         , @c_Barcode               NVARCHAR(30)
         , @n_FillTolerance         INT
         , @c_ttlMsg                NVARCHAR(250)
         , @n_RowRefNo              INT
         , @n_ContinueInsert        INT = 0
         , @c_NewCartonizationKey   NVARCHAR(10)

   DECLARE @T TABLE (SerialNo NVARCHAR(20))
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
   SELECT ISNULL(TRIM(CartonizationKey),'')
        , ISNULL(TRIM(CartonizationGroup),'')
        , ISNULL(TRIM(CartonType),'')
        , ISNULL(UseSequence,1)
   FROM SCE_DL_CARTONIZATION_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo
   AND   STG_Status  = '1'

   OPEN C_HDR
   FETCH NEXT FROM C_HDR
   INTO @c_CartonizationKey  
      , @c_CartonizationGroup
      , @c_CartonType        
      , @n_UseSequence         

   WHILE @@FETCH_STATUS = 0
   BEGIN
      BEGIN TRANSACTION

      SET @c_ttlMsg = N''
      SET @n_ContinueInsert = 0

      SELECT TOP (1) @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_CARTONIZATION_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   CartonizationKey   = @c_CartonizationKey
      AND   CartonizationGroup = @c_CartonizationGroup
      AND   CartonType = @c_CartonType
      AND   UseSequence = @n_UseSequence
      ORDER BY STG_SeqNo ASC

      IF @c_InParm1 = '1'
      BEGIN
         WHILE @n_ContinueInsert = 0
         BEGIN
            EXEC dbo.nspg_GetKey @KeyName = 'Cartonization'
               , @fieldlength = 5
               , @keystring = @c_NewCartonizationKey OUTPUT
               , @b_Success = @b_Success OUTPUT
               , @n_err = @n_ErrNo OUTPUT
               , @c_errmsg = @c_ErrMsg OUTPUT
            
            IF @b_Success = 0
            BEGIN
               SET @n_ContinueInsert = 1
               SET @n_Continue = 3
               SET @c_ErrMsg = 'Unable to get a new Cartonization Key from nspg_getkey.'
            
               UPDATE dbo.SCE_DL_CARTONIZATION_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = @c_ErrMsg
               WHERE STG_BatchNo = @n_BatchNo
               AND   STG_Status  = '1'
               AND   CartonizationKey   = @c_CartonizationKey
               AND   CartonizationGroup = @c_CartonizationGroup
               AND   CartonType = @c_CartonType
               AND   UseSequence = @n_UseSequence
            
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END
               
               ROLLBACK TRAN
               GOTO QUIT
            END
            ELSE
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM CARTONIZATION C (NOLOCK) WHERE C.CartonizationKey = @c_NewCartonizationKey)
               BEGIN
                  SET @n_ContinueInsert = 1
               END
            END
         END

         INSERT INTO dbo.CARTONIZATION (CartonizationKey, CartonizationGroup, CartonType, CartonDescription, UseSequence, Cube
                                      , MaxWeight, MaxCount, AddWho
                                      , CartonWeight, CartonLength, CartonWidth, CartonHeight, Barcode, FillTolerance)
         SELECT @c_NewCartonizationKey, CartonizationGroup, CartonType, CartonDescription, UseSequence, Cube
              , MaxWeight, MaxCount, @c_Username
              , CartonWeight, CartonLength, CartonWidth, CartonHeight, Barcode, FillTolerance
         FROM dbo.SCE_DL_CARTONIZATION_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         INSERT INTO dbo.CARTONIZATION (CartonizationKey, CartonizationGroup, CartonType, CartonDescription, UseSequence, Cube
                                      , MaxWeight, MaxCount, AddWho
                                      , CartonWeight, CartonLength, CartonWidth, CartonHeight, Barcode, FillTolerance)
         SELECT CartonizationKey, CartonizationGroup, CartonType, CartonDescription, UseSequence, Cube
              , MaxWeight, MaxCount, @c_Username
              , CartonWeight, CartonLength, CartonWidth, CartonHeight, Barcode, FillTolerance
         FROM dbo.SCE_DL_CARTONIZATION_STG STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
    
      UPDATE dbo.SCE_DL_CARTONIZATION_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status  = '1'
      AND   CartonizationKey   = @c_CartonizationKey
      AND   CartonizationGroup = @c_CartonizationGroup
      AND   CartonType = @c_CartonType
      AND   UseSequence = @n_UseSequence

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END

      NEXTITEM:
      FETCH NEXT FROM C_HDR
      INTO @c_CartonizationKey  
         , @c_CartonizationGroup
         , @c_CartonType        
         , @n_UseSequence   
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

   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CARTONIZATION_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '')
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