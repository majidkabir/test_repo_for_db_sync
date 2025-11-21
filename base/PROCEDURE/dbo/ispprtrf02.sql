SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispPRTRF02                                                  */
/* Creation Date: 26-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22898 - CN - Pandora PreFinalizeSP                      */
/*                                                                      */
/* Called By: ispPreFinalizeTransferWrapper                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 26-Jun-2023  WLChooi   1.0 DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispPRTRF02]
(
   @c_Transferkey        NVARCHAR(10)
 , @b_Success            INT           OUTPUT
 , @n_Err                INT           OUTPUT
 , @c_ErrMsg             NVARCHAR(255) OUTPUT
 , @c_TransferLineNumber NVARCHAR(5) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug             INT
         , @n_Cnt               INT
         , @n_Continue          INT
         , @n_StartTCount       INT
         , @c_UDF02             NVARCHAR(60)
         , @c_UDF03             NVARCHAR(60)
         , @c_UDF04             NVARCHAR(60)
         , @c_Lottable02        NVARCHAR(60)
         , @c_ToLottable02      NVARCHAR(60)
         , @c_Storerkey         NVARCHAR(15)
         , @c_UpdateUDF02_03    NVARCHAR(50)
         , @c_Authority         NVARCHAR(50)
         , @c_Option1           NVARCHAR(50)
         , @c_Option2           NVARCHAR(50)
         , @c_Option3           NVARCHAR(50)
         , @c_Option4           NVARCHAR(50)
         , @c_Option5           NVARCHAR(4000)
         , @c_Facility          NVARCHAR(5)
         , @c_FromLoc           NVARCHAR(10)
         , @c_ToLoc             NVARCHAR(10)
         , @c_HOSTWHCode        NVARCHAR(50)
         , @c_FromLocHostWHCode NVARCHAR(50)
         , @c_ToLocHostWHCode   NVARCHAR(50)
         , @c_Type              NVARCHAR(50)

   SELECT @n_StartTCount = @@TRANCOUNT
        , @b_Success = 1
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Debug = 0
        , @n_Continue = 1

   SELECT @c_Storerkey = FromStorerKey
        , @c_Type = [Type]
   FROM TRANSFER (NOLOCK)
   WHERE TransferKey = @c_Transferkey

   IF @c_Type = 'NIF'
      GOTO QUIT_SP

   EXEC nspGetRight ''
                  , @c_Storerkey
                  , ''
                  , 'PreFinalizeTranferSP'
                  , @b_Success OUTPUT
                  , @c_Authority OUTPUT
                  , @n_Err OUTPUT
                  , @c_ErrMsg OUTPUT
                  , @c_Option1 OUTPUT
                  , @c_Option2 OUTPUT
                  , @c_Option3 OUTPUT
                  , @c_Option4 OUTPUT
                  , @c_Option5 OUTPUT

   SELECT @c_UpdateUDF02_03 = dbo.fnc_GetParamValueFromString('@c_UpdateUDF02_03', @c_Option5, @c_UpdateUDF02_03)

   IF @n_Continue IN ( 1, 2 )
   BEGIN
      DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TransferLineNumber
           , TD.UserDefine04
           , TD.LOTTABLE02
           , TD.tolottable02
           , T.Facility
           , TD.FromLoc
           , TD.ToLoc
           , LF.HOSTWHCODE
           , LT.HOSTWHCODE
      FROM TRANSFER T (NOLOCK)
      JOIN TRANSFERDETAIL TD (NOLOCK) ON T.TransferKey = TD.TransferKey
      JOIN LOC LF (NOLOCK) ON LF.Loc = TD.FromLoc AND LF.Facility = T.Facility
      JOIN LOC LT (NOLOCK) ON LT.Loc = TD.ToLoc AND LT.Facility = T.Facility
      WHERE T.TransferKey = @c_Transferkey
      ORDER BY TD.TransferLineNumber

      OPEN CUR_TRANSFER

      FETCH NEXT FROM CUR_TRANSFER
      INTO @c_TransferLineNumber
         , @c_UDF04
         , @c_Lottable02
         , @c_ToLottable02
         , @c_Facility
         , @c_FromLoc
         , @c_ToLoc
         , @c_FromLocHostWHCode
         , @c_ToLocHostWHCode

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 )
      BEGIN
         IF ISNULL(@c_UpdateUDF02_03, '') = 'Y'
         BEGIN
            SET @c_UDF02 = N''
            SET @c_UDF03 = N''

            IF @c_Lottable02 = 'ECOM'
            BEGIN
               SELECT @c_UDF02 = @c_FromLocHostWHCode
            END
            ELSE IF @c_Lottable02 = 'RETAIL'
            BEGIN
               SELECT @c_UDF02 = ISNULL(CODELKUP.Short, '')
               FROM CODELKUP (NOLOCK)
               WHERE CODELKUP.LISTNAME = 'HOSTWHCODE'
               AND   CODELKUP.Storerkey = @c_Storerkey
               AND   CODELKUP.Code = @c_FromLocHostWHCode
            END

            IF @c_ToLottable02 = 'ECOM'
            BEGIN
               SELECT @c_UDF03 = @c_ToLocHostWHCode
            END
            ELSE IF @c_ToLottable02 = 'RETAIL'
            BEGIN
               SELECT @c_UDF03 = ISNULL(CODELKUP.Short, '')
               FROM CODELKUP (NOLOCK)
               WHERE CODELKUP.LISTNAME = 'HOSTWHCODE'
               AND   CODELKUP.Storerkey = @c_Storerkey
               AND   CODELKUP.Code = @c_ToLocHostWHCode
            END

            UPDATE TRANSFERDETAIL WITH (ROWLOCK)
            SET UserDefine02 = @c_UDF02
              , UserDefine03 = @c_UDF03
              , TrafficCop = NULL
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE TransferKey = @c_Transferkey AND TransferLineNumber = @c_TransferLineNumber

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 61000
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update Transferdetail Table Failed. (ispPRTRF02)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
            END
         END
         ELSE
         BEGIN
            UPDATE TRANSFERDETAIL WITH (ROWLOCK)
            SET UserDefine02 = @c_UDF04
              , UserDefine04 = ''
              , TrafficCop = NULL
              , EditWho = SUSER_SNAME()
              , EditDate = GETDATE()
            WHERE TransferKey = @c_Transferkey AND TransferLineNumber = @c_TransferLineNumber

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 61010
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Update Transferdetail Table Failed. (ispPRTRF02)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
            END
         END

         FETCH NEXT FROM CUR_TRANSFER
         INTO @c_TransferLineNumber
            , @c_UDF04
            , @c_Lottable02
            , @c_ToLottable02
            , @c_Facility
            , @c_FromLoc
            , @c_ToLoc
            , @c_FromLocHostWHCode
            , @c_ToLocHostWHCode
      END
      CLOSE CUR_TRANSFER
      DEALLOCATE CUR_TRANSFER
   END

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_TRANSFER') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_TRANSFER
      DEALLOCATE CUR_TRANSFER
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRTRF02'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END

      RETURN
   END
END

GO