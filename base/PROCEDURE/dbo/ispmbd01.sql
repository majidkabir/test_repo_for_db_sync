SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispMBD01                                                */
/* Creation Date: 26-JUN-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1916 - WMS Storerconfig for Copy totalcarton to ctncnt1 */
/*        : in mboldetail                                               */
/* Called By: MBOLDetail Add, Update, Delete                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispMBD01]
      @c_Action      NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_MBOLKey         NVARCHAR(10) 
         , @c_MBOLLineNumber  NVARCHAR(5)
         , @CUR_MBD           CURSOR
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
   --RAISERROR ('TEST', 16, 1) WITH SETERROR
   IF @c_Action IN ('DELETE')
   BEGIN 
      GOTO QUIT_SP
   END

   IF @c_Action IN ('INSERT')
   BEGIN
      SET @CUR_MBD = CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT I.MBOLKey
            ,I.MBOLLineNumber
      FROM #INSERTED I 
      JOIN MBOL      M WITH (NOLOCK) ON (I.MBOLKey = M.MBOLKey)
      JOIN ORDERS    O WITH (NOLOCK) ON (I.Orderkey = O.Orderkey)
      WHERE  O.Storerkey = @c_Storerkey
      AND M.Status < '9'
      ORDER BY I.MBOLKey, I.MBOLLineNumber
   END 
   ELSE IF @c_Action IN ('UPDATE')
   BEGIN
      SET @CUR_MBD = CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT I.MBOLKey
            ,I.MBOLLineNumber
      FROM #INSERTED I 
      JOIN #DELETED  D ON (I.MBOLKey = D.MBOLKey)
      JOIN MBOL      M WITH (NOLOCK) ON (I.MBOLKey = M.MBOLKey)
      JOIN ORDERS    O WITH (NOLOCK) ON (I.Orderkey = O.Orderkey)
      WHERE  O.Storerkey = @c_Storerkey
      AND M.Status < '9'
      AND I.TotalCartons <> D.TotalCartons
      ORDER BY I.MBOLKey, I.MBOLLineNumber
   END 

   OPEN @CUR_MBD
   
   FETCH NEXT FROM @CUR_MBD INTO @c_MBOLKey, @c_MBOLLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE MBOLDETAIL WITH (ROWLOCK)
         SET CtnCnt1 = TotalCartons
            ,EditWho = SUSER_SNAME()
            ,EditDate= GETDATE()
            ,Trafficcop = NULL
      WHERE MBOLKey = @c_MBOLKey
      AND   MBOLLineNumber = @c_MBOLLineNumber

      FETCH NEXT FROM @CUR_MBD INTO @c_MBOLKey, @c_MBOLLineNumber
   END
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispMBD01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO