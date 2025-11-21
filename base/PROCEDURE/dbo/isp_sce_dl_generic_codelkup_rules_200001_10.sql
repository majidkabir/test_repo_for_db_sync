SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_CODELKUP_RULES_200001_10        */
/* Creation Date: 10-May-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22487 - Perform insert or update into CODELKUP target   */
/*                      table                                           */
/*                                                                      */
/* Usage:  Update or Ignore  @c_InParm1 = '0' Ignore existing Codelkup  */
/*                           @c_InParm1 = '1' Update is allow           */
/*           Delete Codelkup @c_InParm2 = '0' Not allow delete          */
/*                           @c_InParm2 = '1' Delete is allow           */
/*            Codelkup Value @c_InParm3 = 'A,B,C'                       */
/*            Delimiter Sign @c_InParm4 = '-' Delimited by comma        */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-May-2023  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_CODELKUP_RULES_200001_10]
(
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
   --, @c_InParm3            NVARCHAR(60)    
   --, @c_InParm7            NVARCHAR(60)    
   --, @c_InParm8            NVARCHAR(60)    
   --, @c_InParm9            NVARCHAR(60)    
   --, @c_InParm10           NVARCHAR(60)    

   DECLARE @c_Listname   NVARCHAR(10)
         , @c_StorerKey  NVARCHAR(15)
         , @c_Code       NVARCHAR(30)
         , @c_Code2      NVARCHAR(30)
         , @c_UDF01      NVARCHAR(100)
         , @n_RowRefNo   INT
         , @n_FoundExist INT
         , @n_ActionFlag INT
         , @c_ttlMsg     NVARCHAR(250)
         , @c_chkcode    NVARCHAR(50)
         , @n_Casecnt    INT
         , @c_GetCode    NVARCHAR(30)
         , @c_InParm3Val NVARCHAR(500)
         , @c_InParm4Val NVARCHAR(50)
         , @n_SeqNo      INT
         , @c_ColValue   NVARCHAR(50)

   SELECT @c_InParm1 = InParm1
        , @c_InParm2 = InParm2
        , @c_InParm3 = InParm3
        , @c_InParm4 = InParm4
        , @c_InParm5 = InParm5
   FROM
      OPENJSON(@c_SubRuleJson)
      WITH (SPName NVARCHAR(300) '$.SubRuleSP'
          , InParm1 NVARCHAR(60) '$.InParm1'
          , InParm2 NVARCHAR(60) '$.InParm2'
          , InParm3 NVARCHAR(60) '$.InParm3'
          , InParm4 NVARCHAR(60) '$.InParm4'
          , InParm5 NVARCHAR(60) '$.InParm5')
   WHERE SPName = OBJECT_NAME(@@PROCID)

   CREATE TABLE [#TempCheckCodelkup]
   (
      [SeqNo]    [INT]          IDENTITY(1, 1) NOT NULL
    , [RowRefNo] [INT]
    , [listname] [NVARCHAR](10) NULL
   )

   SET @c_InParm3Val = @c_InParm3
   SET @c_InParm4Val = @c_InParm4

   SET @c_InParm3 = IIF(ISNULL(@c_InParm3, '') <> '', '1', '0')
   SET @c_InParm4 = IIF(ISNULL(@c_InParm4, '') <> '', '1', '0')

   BEGIN TRANSACTION

   DECLARE C_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(Listname)
        , TRIM(Code)
        , TRIM(Storerkey)
        , ISNULL(TRIM(Code2),'')
        , TRIM(UDF01)
   FROM dbo.SCE_DL_CODELKUP_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1'

   OPEN C_HDR

   FETCH NEXT FROM C_HDR
   INTO @c_Listname
      , @c_Code
      , @c_StorerKey
      , @c_Code2
      , @c_UDF01

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_FoundExist = 0

      SELECT @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_CODELKUP_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status = '1'
      AND   Storerkey = @c_StorerKey
      AND   Listname = @c_Listname
      AND   Code = @c_Code
      AND   ISNULL(Code2,'') = @c_Code2
      AND   UDF01 = @c_UDF01

      IF @c_InParm4 = '1' AND @c_InParm3 = '1'
      BEGIN
         DECLARE CUR_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT SeqNo
              , ColValue
         FROM dbo.fnc_DelimSplit(@c_InParm4Val, @c_InParm3Val)

         OPEN CUR_DelimSplit
         FETCH NEXT FROM CUR_DelimSplit
         INTO @n_SeqNo
            , @c_ColValue

         WHILE (@@FETCH_STATUS = 0)
         BEGIN
            INSERT INTO #TempCheckCodelkup (RowRefNo, listname)
            VALUES (@n_RowRefNo, @c_ColValue)

            FETCH NEXT FROM CUR_DelimSplit
            INTO @n_SeqNo
               , @c_ColValue
         END
         CLOSE CUR_DelimSplit
         DEALLOCATE CUR_DelimSplit
      END

      SELECT @n_FoundExist = 1
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND   LISTNAME = @c_Listname
      AND   Code = @c_Code
      AND   code2 = CASE WHEN @c_InParm3 = '0' THEN @c_Code2
                         ELSE code2 END

      IF @n_FoundExist = 1
      BEGIN
         IF @c_InParm1 = '1'
         BEGIN
            IF @c_InParm3 = '1'
            BEGIN
               SET @n_ActionFlag = 2 -- UPDATE & DELETE
            END
            ELSE IF @c_InParm2 = '1'
            BEGIN
               SET @n_ActionFlag = 3 -- DELETE
            END
         END
         ELSE IF @c_InParm1 = '0'
         BEGIN
            UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: Listname: ' + @c_Listname + ' Code: ' + @c_Code + ' Code2: ' + @c_Code2
                             + ' for Storerkey ' + @c_StorerKey + ' already exists in Codelkup Table.'
            WHERE RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            GOTO NEXTITEM
         END
      END
      ELSE
      BEGIN
         SET @n_ActionFlag = 0 -- INSERT
      END

      IF EXISTS (  SELECT 1
                   FROM CODELIST (NOLOCK)
                   WHERE LISTNAME = @c_Listname)
      BEGIN
         IF @c_InParm3 = '1' AND @n_ActionFlag = 2
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM #TempCheckCodelkup TCC (NOLOCK)
                             WHERE TCC.RowRefNo = @n_RowRefNo
                             AND   ISNULL(TCC.listname, '') = CASE WHEN ISNULL(TCC.listname, '') <> '' THEN @c_Listname
                                                                   ELSE TCC.listname END)
            BEGIN
               UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error: User not allow to update for Codelkup: ' + @c_Listname
               WHERE RowRefNo = @n_RowRefNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  ROLLBACK TRAN
                  GOTO QUIT
               END

               GOTO NEXTITEM
            END
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
         SET STG_Status = '5'
           , STG_ErrMsg = 'Error: Listname not exists in Codelist.'
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END

         GOTO NEXTITEM
      END

      IF @c_InParm3 = '1'
      BEGIN
         IF ISNULL(@c_Code, '') <> ''
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM SKU (NOLOCK)
                             WHERE StorerKey = @c_StorerKey AND Sku = @c_Code)
            BEGIN
               UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error: SKU: ' + @c_Code + ' not exists.'
               WHERE RowRefNo = @n_RowRefNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  ROLLBACK TRAN
                  GOTO QUIT
               END

               GOTO NEXTITEM
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: SKU is null.'
            WHERE RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            GOTO NEXTITEM
         END

         SET @c_chkcode = N''

         SELECT @c_chkcode = C.Code
         FROM CODELKUP C (NOLOCK)
         WHERE C.LISTNAME = 'LOGISUBINV' AND C.Storerkey = @c_StorerKey AND C.Code = @c_Code2

         IF @c_Code2 <> @c_chkcode
         BEGIN
            UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
            SET STG_Status = '5'
              , STG_ErrMsg = 'Error: Sub Inv not found : ' + @c_Code2
            WHERE RowRefNo = @n_RowRefNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END

            GOTO NEXTITEM
         END

         IF ISNUMERIC(@c_UDF01) = 1 AND @c_Listname = 'LOGIRSP'
         BEGIN
            SET @n_Casecnt = 1

            SELECT @n_Casecnt = P.CaseCnt
            FROM SKU S (NOLOCK)
            JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey
            WHERE S.StorerKey = @c_StorerKey AND S.Sku = @c_Code

            IF CAST(@c_UDF01 AS INT) % @n_Casecnt <> 0
            BEGIN
               UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
               SET STG_Status = '5'
                 , STG_ErrMsg = 'Error: Quantity not in carton for SKU : ' + @c_Code
               WHERE RowRefNo = @n_RowRefNo

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  ROLLBACK TRAN
                  GOTO QUIT
               END

               GOTO NEXTITEM
            END
         END

         IF @n_ActionFlag IN ( 2, 3 )
         BEGIN
            DELETE FROM dbo.CODELKUP
            WHERE LISTNAME = @c_Listname AND Storerkey = @c_StorerKey AND Code = @c_Code

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               ROLLBACK TRAN
               GOTO QUIT
            END
         END
      END

      IF @c_InParm2 = '1'
      BEGIN
         IF EXISTS (  SELECT 1
                      FROM CODELKUP WITH (NOLOCK)
                      WHERE LISTNAME = @c_Listname AND Storerkey = @c_StorerKey)
         BEGIN
            DECLARE CUR_DEL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT Code
            FROM CODELKUP (NOLOCK)
            WHERE LISTNAME = @c_Listname AND Storerkey = @c_StorerKey

            OPEN CUR_DEL

            FETCH NEXT FROM CUR_DEL
            INTO @c_GetCode

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               DELETE FROM dbo.CODELKUP
               WHERE LISTNAME = @c_Listname AND Storerkey = @c_StorerKey AND Code = @c_GetCode

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  ROLLBACK TRAN
                  GOTO QUIT
               END

               FETCH NEXT FROM CUR_DEL
               INTO @c_GetCode
            END
            CLOSE CUR_DEL
            DEALLOCATE CUR_DEL
         END
      END

      NEXTITEM:

      FETCH NEXT FROM C_HDR
      INTO @c_Listname
         , @c_Code
         , @c_StorerKey
         , @c_Code2
         , @c_UDF01
   END
   CLOSE C_HDR
   DEALLOCATE C_HDR

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   BEGIN TRANSACTION

   DECLARE C_INS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TRIM(Listname)
        , TRIM(Code)
        , TRIM(Storerkey)
        , ISNULL(TRIM(Code2),'')
   FROM dbo.SCE_DL_CODELKUP_STG WITH (NOLOCK)
   WHERE STG_BatchNo = @n_BatchNo AND STG_Status = '1'

   OPEN C_INS

   FETCH NEXT FROM C_INS
   INTO @c_Listname
      , @c_Code
      , @c_StorerKey
      , @c_Code2

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_FoundExist = 0

      SELECT @n_RowRefNo = RowRefNo
      FROM dbo.SCE_DL_CODELKUP_STG WITH (NOLOCK)
      WHERE STG_BatchNo = @n_BatchNo
      AND   STG_Status = '1'
      AND   Storerkey = @c_StorerKey
      AND   Listname = @c_Listname
      AND   Code = @c_Code
      AND   ISNULL(Code2,'') = @c_Code2

      SELECT @n_FoundExist = 1
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE Storerkey = @c_StorerKey AND LISTNAME = @c_Listname AND Code = @c_Code AND code2 = @c_Code2

      IF @c_InParm1 = '1' AND @n_FoundExist = 1
      BEGIN
         UPDATE CL WITH (ROWLOCK)
         SET CL.Code = ISNULL(STG.Code, CL.Code)
           , CL.[Description] = ISNULL(STG.[Description], '')
           , CL.Short = ISNULL(STG.Short, '')
           , CL.Long = ISNULL(STG.Long, '')
           , CL.Notes = ISNULL(STG.Notes, '')
           , CL.UDF01 = ISNULL(STG.UDF01, '')
           , CL.UDF02 = ISNULL(STG.UDF02, '')
           , CL.UDF03 = ISNULL(STG.UDF03, '')
           , CL.UDF04 = ISNULL(STG.UDF04, '')
           , CL.UDF05 = ISNULL(STG.UDF05, '')
           , CL.code2 = ISNULL(STG.code2, CL.code2)
           , CL.EditWho = @c_Username
           , CL.EditDate = GETDATE()
         FROM dbo.CODELKUP CL
         JOIN dbo.SCE_DL_CODELKUP_STG STG WITH (NOLOCK) ON  STG.Storerkey = CL.Storerkey
                                                        AND STG.LISTNAME = CL.LISTNAME
                                                        AND STG.Code = CL.Code
                                                        AND ISNULL(STG.code2,'') = CL.code2
         WHERE STG.RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         INSERT INTO CODELKUP (LISTNAME, Code, [Description], Short, Long, Notes, Storerkey, UDF01, UDF02, UDF03, UDF04
                             , UDF05, AddWho, EditWho, code2)
         SELECT LISTNAME
              , Code
              , ISNULL([Description],'')
              , ISNULL(Short,'')
              , ISNULL(Long,'')
              , ISNULL(Notes,'')
              , Storerkey
              , ISNULL(UDF01,'')
              , ISNULL(UDF02,'')
              , ISNULL(UDF03,'')
              , ISNULL(UDF04,'')
              , ISNULL(UDF05,'')
              , @c_Username
              , @c_Username
              , ISNULL(Code2,'')
         FROM dbo.SCE_DL_CODELKUP_STG WITH (NOLOCK)
         WHERE RowRefNo = @n_RowRefNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END

      UPDATE dbo.SCE_DL_CODELKUP_STG WITH (ROWLOCK)
      SET STG_Status = '9'
      WHERE RowRefNo = @n_RowRefNo  

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         ROLLBACK TRAN
         GOTO QUIT
      END   

      FETCH NEXT FROM C_INS
      INTO @c_Listname
         , @c_Code
         , @c_StorerKey
         , @c_Code2
   END
   CLOSE C_INS
   DEALLOCATE C_INS

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE C_HDR
      DEALLOCATE C_HDR
   END

   IF CURSOR_STATUS('LOCAL', 'C_INS') IN ( 0, 1 )
   BEGIN
      CLOSE C_INS
      DEALLOCATE C_INS
   END

   IF CURSOR_STATUS('LOCAL', 'C_HDR') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_DEL
      DEALLOCATE CUR_DEL
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_DelimSplit') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_DelimSplit
      DEALLOCATE CUR_DelimSplit
   END

   WHILE @@TRANCOUNT > 0
   COMMIT TRAN

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_CODELKUP_RULES_200001_10] EXIT... ErrMsg : '
             + ISNULL(TRIM(@c_ErrMsg), '')
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