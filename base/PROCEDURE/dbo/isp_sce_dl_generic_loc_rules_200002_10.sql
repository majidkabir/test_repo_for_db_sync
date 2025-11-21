SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_LOC_RULES_200002_10             */
/* Creation Date: 20-Feb-2025                                           */
/* Copyright: Maersk                                                    */
/* Written by: BDI048                                                   */
/*                                                                      */
/* Purpose:  Perform insert or update ColorCode into target table       */
/*                                                                      */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 =  '0'  Ignore ColorCode        */
/*                           @c_InParm1 =  '1'  Insert ColorCode        */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 20-Feb-2025  BDI048    1.0   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_LOC_RULES_200002_10]
   (
   @b_Debug       INT            = 0
 ,
   @n_BatchNo     INT            = 0
 ,
   @n_Flag        INT            = 0
 ,
   @c_SubRuleJson NVARCHAR(MAX)
 ,
   @c_STGTBL      NVARCHAR(250)  = ''
 ,
   @c_POSTTBL     NVARCHAR(250)  = ''
 ,
   @c_UniqKeyCol  NVARCHAR(1000) = ''
 ,
   @c_Username    NVARCHAR(128)  = ''
 ,
   @b_Success     INT            = 0 OUTPUT
 ,
   @n_ErrNo       INT            = 0 OUTPUT
 ,
   @c_ErrMsg      NVARCHAR(250)  = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_WARNINGS OFF;

   DECLARE @c_ExecStatements NVARCHAR(4000)
         , @c_ExecArguments  NVARCHAR(4000)
         , @n_Continue       INT
         , @n_StartTCnt      INT;

   DECLARE @c_InParm1 NVARCHAR(60)
         , @c_InParm2 NVARCHAR(60)
         , @c_InParm3 NVARCHAR(60)
         , @c_InParm4 NVARCHAR(60)
         , @c_InParm5 NVARCHAR(60);
   --, @c_InParm6            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @n_RowRefNo  INT
         , @c_Storerkey NVARCHAR(15)
         , @c_Loc       NVARCHAR(15)
         , @c_ttlMsg    NVARCHAR(250);

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
   WHERE SPName = OBJECT_NAME(@@PROCID);

   SET @n_StartTCnt = @@TRANCOUNT;

   IF @c_InParm1 = '1'
   BEGIN
      DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRefNo
         , ISNULL(RTRIM(Loc), '')
      FROM dbo.SCE_DL_LOC_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo

      OPEN C_HDR;
      FETCH NEXT FROM C_HDR
      INTO @n_RowRefNo
         , @c_Loc;

      WHILE @@FETCH_STATUS = 0
      BEGIN
         BEGIN TRAN;

         IF EXISTS (
         SELECT 1
         FROM dbo.V_LOC WITH (NOLOCK)
         WHERE Loc = @c_Loc
         )
         BEGIN
            UPDATE L WITH (ROWLOCK)
               SET L.ColorCode = ISNULL(STG.ColorCode, L.ColorCode) 
               , L.EditWho = @c_Username
               , L.EditDate = GETDATE()          
               FROM dbo.SCE_DL_LOC_STG STG WITH (NOLOCK)
               JOIN dbo.LOC            L
               ON L.Loc = STG.Loc
               WHERE STG.RowRefNo = @n_RowRefNo;
         END;

         IF @@ERROR <> 0
            BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         IF @@ERROR <> 0
            BEGIN
            SET @n_Continue = 3;
            ROLLBACK TRAN;
            GOTO QUIT;
         END;

         WHILE @@TRANCOUNT > 0
            COMMIT TRAN;

         FETCH NEXT FROM C_HDR
            INTO @n_RowRefNo
               , @c_Loc;
      END;

      CLOSE C_HDR;
      DEALLOCATE C_HDR;
   End
   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_LOC_RULES_200002_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN;

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN;
         END;
      END;
   END;
   ELSE
   BEGIN
      SET @b_Success = 1;
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN;
      END;
   END;
END;

GO