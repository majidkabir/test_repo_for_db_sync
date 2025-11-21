SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_INSERT_PALLET_LABEL                                 */
/* Creation Date: 21-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CZTENG/WAN                                               */
/*                                                                      */
/* Purpose: Return a temporary table contain pallet id records          */
/*                                                                      */
/*                                                                      */
/* Called By:                                                           */
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

CREATE PROC [dbo].[isp_INSERT_PALLET_LABEL]
         @n_Qty         INT            = 1
      ,  @c_Prefix      NVARCHAR(10)          -- ZG01
      ,  @c_Title       NVARCHAR(30)
      ,  @c_StorerKey   NVARCHAR(15)   = ''
      ,  @c_Udf01       NVARCHAR(30)   = ''
      ,  @c_Udf02       NVARCHAR(30)   = ''
      ,  @c_Udf03       NVARCHAR(30)   = ''
      ,  @c_Udf04       NVARCHAR(30)   = ''
      ,  @c_Udf05       NVARCHAR(30)   = ''
      ,  @c_ErrMsg      NVARCHAR(255)  OUTPUT
      ,  @b_Success     INT            OUTPUT
      ,  @n_Err         INT            OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Count       INT = 1
         , @n_StringLen   INT
         , @n_Continue    INT
         , @c_Pallet_Id   NVARCHAR(10)
         , @c_Key         NVARCHAR(8)

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

   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @c_ErrMsg   = ''
   SET @n_Err = 0



   SET @n_StringLen = 10 - LEN(TRIM(@c_Prefix))

   EXEC dbo.nspg_getkey
         @KeyName     = 'PALLETID'
      ,  @fieldlength = @n_StringLen
      ,  @b_Success   = @b_Success     OUTPUT
      ,  @keystring   = @c_Key         OUTPUT
      ,  @n_err       = @n_err         OUTPUT
      ,  @c_errmsg    = @c_errmsg      OUTPUT
      ,  @n_batch     = @n_Qty

   IF(ISNULL(@c_Key, '') = '')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 554853
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                        + ': Generate Pallet ID Failed! (isp_INSERT_PALLET_LABEL)'

      GOTO EXIT_SP
   END

   WHILE @n_Count <= @n_Qty
   BEGIN
      SET @c_Pallet_Id = TRIM(@c_Prefix) + @c_Key

      IF(@c_Pallet_Id <> '')
      BEGIN
         INSERT INTO #TMP_PALLET
         VALUES
         ( @c_Title
         , @c_Pallet_Id
         , @c_StorerKey
         , GETDATE()
         , @n_Count
         , @n_Qty
         , @c_Udf01
         , @c_Udf02
         , @c_Udf03
         , @c_Udf04
         , @c_Udf05
         )
      END

      SET @c_Key  = RIGHT('00000000' + CONVERT(NVARCHAR(8), CONVERT(INT, @c_Key) + 1), @n_StringLen)

      SET @n_Count = @n_Count + 1
   END

   EXIT_SP:

   IF @n_Continue = 3
   BEGIN
      SELECT @b_success = 0
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_INSERT_PALLET_LABEL'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SELECT @b_success = 1

      SELECT Title
           , PalletID
           , StorerKey
           , [Date]
           , [Count]
           , Qty
           , udf01
           , udf02
           , udf03
           , udf04
           , udf05
      FROM #TMP_PALLET
   END
END -- procedure

GO