SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store Procedure:  isp_SCE_DL_GENERIC_IH_RULES_200001_10              */
/* Creation Date: 02-Mar-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: GHChan                                                   */
/*                                                                      */
/* Purpose:  Perform Insert into target table action. INVENTORYHOLD     */
/*                                                                      */
/* Usage:                                                               */
/*   @c_InParm1 = '1' Perform Insert into target table action.          */
/*                                                                      */
/* Called By: - SCE DL Main Stored Procedures e.g. (isp_SCE_DL_Generic) */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 02-Mar-2022  GHChan    1.1   Initial                                 */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_SCE_DL_GENERIC_IH_RULES_200001_10] (
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

   DECLARE @n_RowRefNo         INT
         , @c_InventoryHoldKey NVARCHAR(10)
         , @c_Lot              NVARCHAR(10)
         , @c_Loc              NVARCHAR(10)
         , @c_Id               NVARCHAR(18)
         , @c_Storerkey        NVARCHAR(18)
         , @c_SKU              NVARCHAR(20)
         , @c_Lottable01       NVARCHAR(18)
         , @c_Lottable02       NVARCHAR(18)
         , @c_Lottable03       NVARCHAR(18)
         , @dt_Lottable04      DATETIME
         , @dt_Lottable05      DATETIME
         , @c_Lottable06       NVARCHAR(30)
         , @c_Lottable07       NVARCHAR(30)
         , @c_Lottable08       NVARCHAR(30)
         , @c_Lottable09       NVARCHAR(30)
         , @c_Lottable10       NVARCHAR(30)
         , @c_Lottable11       NVARCHAR(30)
         , @c_Lottable12       NVARCHAR(30)
         , @dt_Lottable13      DATETIME
         , @dt_Lottable14      DATETIME
         , @dt_Lottable15      DATETIME
         , @b_Proceed          BIT;
   --, @c_ttlErrMsg        NVARCHAR(250);

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

   SET @n_Continue = 1;

   SET @n_StartTCnt = @@TRANCOUNT;

   IF @c_InParm1 = '1'
   BEGIN

      BEGIN TRANSACTION;

      BEGIN TRY
         DECLARE C_CHK_CONF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRefNo
              , Lot
              , Loc
              , Id
              , Storerkey
              , SKU
              , Lottable01
              , Lottable02
              , Lottable03
              , Lottable04
              , Lottable05
              , Lottable06
              , Lottable07
              , Lottable08
              , Lottable09
              , Lottable10
              , Lottable11
              , Lottable12
              , Lottable13
              , Lottable14
              , Lottable15
         FROM dbo.INVENTORYHOLD_STG WITH (NOLOCK)
         WHERE STG_BatchNo = @n_BatchNo
         AND   STG_Status    = '1';

         OPEN C_CHK_CONF;
         FETCH NEXT FROM C_CHK_CONF
         INTO @n_RowRefNo
            , @c_Lot
            , @c_Loc
            , @c_Id
            , @c_Storerkey
            , @c_SKU
            , @c_Lottable01
            , @c_Lottable02
            , @c_Lottable03
            , @dt_Lottable04
            , @dt_Lottable05
            , @c_Lottable06
            , @c_Lottable07
            , @c_Lottable08
            , @c_Lottable09
            , @c_Lottable10
            , @c_Lottable11
            , @c_Lottable12
            , @dt_Lottable13
            , @dt_Lottable14
            , @dt_Lottable15;

         WHILE @@FETCH_STATUS = 0
         BEGIN

            SET @b_Proceed = 0;

            IF  NOT LTRIM(RTRIM(@c_Lot)) = ''
            AND LTRIM(RTRIM(@c_Loc)) = ''
            AND LTRIM(RTRIM(@c_Id)) = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable01)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable02)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable03)), '') = ''
            AND ISNULL(@dt_Lottable04, '') = ''
            AND ISNULL(@dt_Lottable05, '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable06)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable07)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable08)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable09)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable10)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable11)), '') = ''
            AND ISNULL(LTRIM(RTRIM(@c_Lottable12)), '') = ''
            AND ISNULL(@dt_Lottable13, '') = ''
            AND ISNULL(@dt_Lottable14, '') = ''
            AND ISNULL(@dt_Lottable15, '') = ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.INVENTORYHOLD WITH (NOLOCK)
               WHERE Lot = @c_Lot
               )
               BEGIN
                  SET @b_Proceed = 1;
               END;
               ELSE
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 11001
                  SET @c_ErrMsg = N'Lot (' + @c_Lot + N') already existed in Inventory Hold table.';
                  GOTO QUIT;
               END;
            END;
            ELSE IF  LTRIM(RTRIM(@c_Lot)) = ''
                 AND NOT LTRIM(RTRIM(@c_Loc)) = ''
                 AND LTRIM(RTRIM(@c_Id)) = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable01)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable02)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable03)), '') = ''
                 AND ISNULL(@dt_Lottable04, '') = ''
                 AND ISNULL(@dt_Lottable05, '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable06)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable07)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable08)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable09)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable10)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable11)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable12)), '') = ''
                 AND ISNULL(@dt_Lottable13, '') = ''
                 AND ISNULL(@dt_Lottable14, '') = ''
                 AND ISNULL(@dt_Lottable15, '') = ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.INVENTORYHOLD WITH (NOLOCK)
               WHERE Loc = @c_Loc
               )
               BEGIN
                  SET @b_Proceed = 1;
               END;
               ELSE
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 11002
                  SET @c_ErrMsg = N'Loc (' + @c_Loc + N') already existed in Inventory Hold table.';
                  GOTO QUIT;
               END;
            END;
            ELSE IF  LTRIM(RTRIM(@c_Lot)) = ''
                 AND LTRIM(RTRIM(@c_Loc)) = ''
                 AND NOT LTRIM(RTRIM(@c_Id)) = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable01)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable02)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable03)), '') = ''
                 AND ISNULL(@dt_Lottable04, '') = ''
                 AND ISNULL(@dt_Lottable05, '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable06)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable07)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable08)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable09)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable10)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable11)), '') = ''
                 AND ISNULL(LTRIM(RTRIM(@c_Lottable12)), '') = ''
                 AND ISNULL(@dt_Lottable13, '') = ''
                 AND ISNULL(@dt_Lottable14, '') = ''
                 AND ISNULL(@dt_Lottable15, '') = ''
            BEGIN
               IF NOT EXISTS (
               SELECT 1
               FROM dbo.INVENTORYHOLD WITH (NOLOCK)
               WHERE Id = @c_Id
               )
               BEGIN
                  SET @b_Proceed = 1;
               END;
               ELSE
               BEGIN
                  SET @n_Continue = 3;
                  SET @n_ErrNo = 11003
                  SET @c_ErrMsg = N'Id (' + @c_Id + N') already existed in Inventory Hold table.';
                  GOTO QUIT;
               END;
            END;
            ELSE IF  LTRIM(RTRIM(@c_Lot)) = ''
                 AND LTRIM(RTRIM(@c_Loc)) = ''
                 AND LTRIM(RTRIM(@c_Id)) = ''
                 AND NOT LTRIM(RTRIM(@c_Storerkey)) = ''
                 AND NOT LTRIM(RTRIM(@c_SKU)) = ''
                 AND (
                      NOT LTRIM(RTRIM(@c_Lottable01)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable02)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable03)) = ''
                   OR NOT @dt_Lottable04 = ''
                   OR NOT @dt_Lottable05 = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable06)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable07)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable08)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable09)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable10)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable11)) = ''
                   OR NOT LTRIM(RTRIM(@c_Lottable12)) = ''
                   OR NOT @dt_Lottable13 = ''
                   OR NOT @dt_Lottable14 = ''
                   OR NOT @dt_Lottable15 = ''
                 )
            BEGIN
               SET @b_Proceed = 1;
            END;
            ELSE
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 11004
               SET @c_ErrMsg = N'Constraint [CK_IH_01] Validation Failed.';
               GOTO QUIT;
            END;

            IF @b_Proceed = 1
            BEGIN
               EXEC dbo.nspg_GetKey @KeyName = N'InventoryHoldKey'          -- nvarchar(18)
                                  , @fieldlength = 10                       -- int
                                  , @keystring = @c_InventoryHoldKey OUTPUT -- nvarchar(25)
                                  , @b_Success = @b_Success OUTPUT          -- int
                                  , @n_err = @n_ErrNo OUTPUT                -- int
                                  , @c_errmsg = @c_ErrMsg OUTPUT;           -- nvarchar(250)

               IF  (@n_ErrNo <> 0 OR @c_ErrMsg <> '')
               AND @b_Success = 0
               BEGIN
                  SET @n_Continue = 3;
                  GOTO QUIT;
               END;

               INSERT INTO dbo.INVENTORYHOLD
               (
                  InventoryHoldKey
                , Lot
                , Id
                , Loc
                , Hold
                , Status
                , DateOn
                , WhoOn
                , DateOff
                , WhoOff
                , TrafficCop
                , ArchiveCop
                , SKU
                , Storerkey
                , Lottable01
                , Lottable02
                , Lottable03
                , Lottable04
                , Lottable05
                , Remark
                , Lottable06
                , Lottable07
                , Lottable08
                , Lottable09
                , Lottable10
                , Lottable11
                , Lottable12
                , Lottable13
                , Lottable14
                , Lottable15
               )
               SELECT @c_InventoryHoldKey
                    , Lot
                    , Id
                    , Loc
                    , Hold
                    , Status
                    , DateOn
                    , @c_Username
                    , DateOff
                    , @c_Username
                    , TrafficCop
                    , ArchiveCop
                    , ISNULL(RTRIM(SKU),'')
                    , ISNULL(RTRIM(Storerkey),'')
                    , ISNULL(RTRIM(Lottable01),'')
                    , ISNULL(RTRIM(Lottable02),'')
                    , ISNULL(RTRIM(Lottable03),'')
                    , Lottable04
                    , Lottable05
                    , ISNULL(RTRIM(Remark),'')
                    , ISNULL(RTRIM(Lottable06),'')
                    , ISNULL(RTRIM(Lottable07),'')
                    , ISNULL(RTRIM(Lottable08),'')
                    , ISNULL(RTRIM(Lottable09),'')
                    , ISNULL(RTRIM(Lottable10),'')
                    , ISNULL(RTRIM(Lottable11),'')
                    , ISNULL(RTRIM(Lottable12),'')
                    , Lottable13
                    , Lottable14
                    , Lottable15
               FROM dbo.INVENTORYHOLD_STG WITH (NOLOCK)
               WHERE RowRefNo = @n_RowRefNo;

               UPDATE dbo.INVENTORYHOLD_STG WITH (ROWLOCK)
               SET STG_Status = '9'
                 , InventoryHoldKey = @c_InventoryHoldKey
                 , WhoOn = @c_Username
                 , WhoOff = @c_Username
               WHERE RowRefNo = @n_RowRefNo;
            END;
            ELSE
            BEGIN
               SET @n_Continue = 3;
               SET @n_ErrNo = 11005
               SET @c_ErrMsg = N'Invalid Proceed Flag';
               GOTO QUIT;
            --UPDATE dbo.INVENTORYHOLD_STG WITH (ROWLOCK)
            --SET STG_Status = '5'
            --  , STG_ErrMsg = @c_ttlErrMsg
            --  , WhoOn = @c_Username
            --  , WhoOff = @c_Username
            --WHERE RowRefNo = @n_RowRefNo;
            END;

            --IF @@ERROR <> 0
            --BEGIN
            --   SET @n_Continue = 3;
            --   SET @n_ErrNo = 68001;
            --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_ErrNo, 0))
            --                   + ': Insert record fail. (isp_SCE_DL_GENERIC_IH_RULES_200001_10)';
            --   ROLLBACK;
            --   GOTO STEP_999_EXIT_SP;

            --END;

            --COMMIT;

            FETCH NEXT FROM C_CHK_CONF
            INTO @n_RowRefNo
               , @c_Lot
               , @c_Loc
               , @c_Id
               , @c_Storerkey
               , @c_SKU
               , @c_Lottable01
               , @c_Lottable02
               , @c_Lottable03
               , @dt_Lottable04
               , @dt_Lottable05
               , @c_Lottable06
               , @c_Lottable07
               , @c_Lottable08
               , @c_Lottable09
               , @c_Lottable10
               , @c_Lottable11
               , @c_Lottable12
               , @dt_Lottable13
               , @dt_Lottable14
               , @dt_Lottable15;
         END;

         CLOSE C_CHK_CONF;
         DEALLOCATE C_CHK_CONF;
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3;
         SET @n_ErrNo = ERROR_NUMBER();
         SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_SCE_DL_GENERIC_IH_RULES_200001_10)';
      END CATCH;
   END;

   QUIT:

   STEP_999_EXIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT '<<SUB-SP-RULES>> - [isp_SCE_DL_GENERIC_IH_RULES_200001_10] EXIT... ErrMsg : ' + ISNULL(RTRIM(@c_ErrMsg), '');
   END;

   IF @n_Continue = 3
   BEGIN
      IF @n_ErrNo = 0
         SET @n_ErrNo = 11007

      SET @b_Success = 0;
      IF  @@TRANCOUNT = 1
      AND @@TRANCOUNT > @n_StartTCnt
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