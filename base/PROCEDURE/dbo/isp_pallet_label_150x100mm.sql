SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PALLET_LABEL_150X100mm                              */
/* Creation Date: 15-JAN-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Select data from standard stored procedure                  */
/*          isp_INSERT_PALLET_LABEL                                     */
/*                                                                      */
/* Called By: r_dw_pallet_label_150x100mm                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 24-AUG-2022 LZG      1.1   JSM-90463 - Extended to 10 chars (ZG01)   */
/************************************************************************/

CREATE PROC [dbo].[isp_PALLET_LABEL_150X100mm]
         @n_Qty         INT
      ,  @c_Prefix      NVARCHAR(10)          -- ZG01
      ,  @c_Title       NVARCHAR(30)
      ,  @c_StorerKey   NVARCHAR(15)
      ,  @c_Udf01       NVARCHAR(30)
      ,  @c_Udf02       NVARCHAR(30)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_ErrMsg      NVARCHAR(255)
         ,  @b_Success     INT
         ,  @n_Err         INT
         ,  @n_Continue    INT = 1

   DECLARE @n_Cnt          INT = 0
         , @c_CfgUdf01     NVARCHAR(60)   = ''
         , @c_CfgUdf02     NVARCHAR(60)   = ''

   CREATE TABLE #TMP_PALLET
      ( Title        NVARCHAR(30)
      , PalletID     NVARCHAR(10)
      , StorerKey    NVARCHAR(15)
      , [Date]       DATETIME
      , [Count]      INT
      , Qty          INT
      , udf01        NVARCHAR(30)
      , udf02        NVARCHAR(30)
      , udf03        NVARCHAR(30)
      , udf04        NVARCHAR(30)
      , udf05        NVARCHAR(30)
      )

   IF ISNULL(@c_StorerKey,'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 500101
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                     + ': Storerkey is required.'
      GOTO QUIT_SP
   END

   SELECT @c_CfgUdf01 = ISNULL(UDF01, '')
        , @c_CfgUdf02 = ISNULL(UDF02, '')
        , @n_Cnt = 1
   FROM  CODELKUP WITH (NOLOCK)
   WHERE CODELKUP.ListName  = 'RPTTYPECFG'
   AND   CODELKUP.Code      = 'PRNPLTLBL'
   AND   CODELKUP.StorerKey = @c_Storerkey

   IF @n_Cnt > 0
   BEGIN
      IF @c_CfgUdf01 = 'Y' AND ISNULL(@c_Udf01,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 500102
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                        + '. TRUCK/CONT# is required.'
         GOTO QUIT_SP
      END

      IF @c_CfgUdf02 = 'Y' AND ISNULL(@c_Udf02,'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 500103
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                        + '. TRUCK/CONTSEQ is required.'
         GOTO QUIT_SP
      END
   END

   INSERT INTO #TMP_PALLET
   EXEC   isp_INSERT_PALLET_LABEL
             @n_Qty       = @n_Qty
           , @c_Prefix    = @c_Prefix
           , @c_Title     = @c_Title
           , @c_StorerKey = @c_StorerKey
           , @c_Udf01     = @c_Udf01
           , @c_Udf02     = @c_Udf02
           , @c_ErrMsg    = @c_ErrMsg  OUTPUT
           , @b_Success   = @b_Success OUTPUT
           , @n_Err       = @n_Err     OUTPUT

QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_INSERT_PALLET_LABEL'
      RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR
   END

   SELECT Title
        , PalletID
        , StorerKey
        , [Date]
        , [Count]
        , Qty
        , udf01
        , udf02
   FROM #TMP_PALLET

END

SET QUOTED_IDENTIFIER OFF

GO