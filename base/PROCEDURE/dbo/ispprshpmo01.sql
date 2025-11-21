SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRSHPMO01                                          */
/* Creation Date: 16-May-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-22547 - [AU] Levis Pre MBOL Ship Stamp CustomerASN Counter */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 16-May-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[ispPRSHPMO01]
(
   @c_MBOLkey   NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(255) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Debug     INT
         , @n_Continue  INT
         , @n_StartTCnt INT

   DECLARE @c_ExecStatements   NVARCHAR(MAX)
         , @c_ExecArguments    NVARCHAR(MAX)
         , @c_ColName          NVARCHAR(100)
         , @c_ColData          NVARCHAR(100)
         , @c_Table            NVARCHAR(100)
         , @c_Column           NVARCHAR(100)
         , @c_BillToKey        NVARCHAR(50)
         , @c_SeqNo            NVARCHAR(10)

   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Debug = '1'
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT

   SELECT @c_Storerkey = OH.StorerKey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.MBOLKey = @c_MBOLkey

   --Main Process
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DECLARE CUR_CLK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT 
             ISNULL(CL.Long, '') AS ColName
           , ISNULL(CL.Code, '') AS BillToKey
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'LVSCUSTNUM' AND CL.Storerkey = @c_Storerkey
      AND CL.Code IN (SELECT DISTINCT BillToKey FROM ORDERS (NOLOCK) WHERE MBOLKey = @c_MBOLkey)

      OPEN CUR_CLK

      FETCH NEXT FROM CUR_CLK
      INTO @c_ColName
         , @c_BillToKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_Table = 'ORDERS'
         SET @c_Column = @c_ColName

         IF NOT EXISTS (  SELECT 1
                          FROM INFORMATION_SCHEMA.COLUMNS
                          WHERE TABLE_NAME = @c_Table AND COLUMN_NAME = @c_Column)
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 35100
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(VARCHAR(5), @n_Err) + ': ORDERS.' + @c_ColName
                               + ' is not a valid column. (ispPRSHPMO01)'
            GOTO QUIT_SP
         END

         SET @c_ExecStatements = N' DECLARE CUR_ORD CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                               + N' SELECT DISTINCT ORDERS.' + TRIM(@c_ColName) + CHAR(13) 
                               + N' FROM ORDERS WITH (NOLOCK) ' + CHAR(13)
                               + N' WHERE ORDERS.MbolKey = @c_MBOLkey ' + CHAR(13)
                               + N' AND ORDERS.BillToKey = @c_BillToKey ' + CHAR(13) 
                               + N' AND (ORDERS.PmtTerm = '''' OR ORDERS.PmtTerm IS NULL) ' + CHAR(13) 

         SET @c_ExecArguments = N'  @c_MBOLkey         NVARCHAR(10)  ' 
                              + N', @c_BillToKey       NVARCHAR(100) '

         EXEC sp_executesql @c_ExecStatements
                          , @c_ExecArguments
                          , @c_MBOLkey
                          , @c_BillToKey

         OPEN CUR_ORD

         FETCH NEXT FROM CUR_ORD
         INTO @c_ColData

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            EXEC dbo.nspg_GetKeyMinMax @keyname = N'LVSCUSTASNNO' -- nvarchar(18)
                                     , @fieldlength = 6 -- int
                                     , @Min = 100001 -- bigint
                                     , @Max = 999999 -- bigint
                                     , @keystring = @c_SeqNo OUTPUT -- nvarchar(25)
                                     , @b_Success = @b_Success OUTPUT -- int
                                     , @n_err = @n_err OUTPUT -- int
                                     , @c_errmsg = @c_errmsg OUTPUT -- nvarchar(250)
                                     , @b_resultset = 0 -- int
                                     , @n_batch = 1 -- int

            IF @b_Success <> 1
            BEGIN
               SELECT @n_Continue = 3
               GOTO QUIT_SP
            END
            ELSE
            BEGIN
               SET @c_ExecStatements = N' UPDATE ORDERS WITH (ROWLOCK) ' + CHAR(13)
                                     + N' SET PmtTerm = @c_SeqNo ' + CHAR(13)
                                     + N' WHERE MBOLKey = @c_MBOLkey ' + CHAR(13)
                                     + N' AND BillToKey = @c_BillToKey ' + CHAR(13)
                                     + N' AND ' + TRIM(@c_ColName) + ' = @c_ColData '

               SET @c_ExecArguments = N'  @c_MBOLkey         NVARCHAR(10)  ' 
                                    + N', @c_BillToKey       NVARCHAR(100) '
                                    + N', @c_ColData         NVARCHAR(100) '
                                    + N', @c_SeqNo           NVARCHAR(10) '
                                    
               EXEC sp_executesql @c_ExecStatements
                                , @c_ExecArguments
                                , @c_MBOLkey
                                , @c_BillToKey
                                , @c_ColData
                                , @c_SeqNo
            END

            FETCH NEXT FROM CUR_ORD
            INTO @c_ColData
         END
         CLOSE CUR_ORD
         DEALLOCATE CUR_ORD

         FETCH NEXT FROM CUR_CLK
         INTO @c_ColName
            , @c_BillToKey
      END
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END
   --Main Process End

   QUIT_SP:
   IF CURSOR_STATUS('GLOBAL', 'CUR_ORD') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_CLK') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_CLK
      DEALLOCATE CUR_CLK
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPRSHPMO01'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO