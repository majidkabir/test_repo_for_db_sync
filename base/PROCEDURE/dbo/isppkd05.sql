SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPKD05                                           */
/* Creation Date: 15-JUL-2022                                           */
/* Copyright: LF                                                        */
/* Written by:CHONGCS                                                   */
/*                                                                      */
/* Purpose: WMS-20235-[KR] SS_Exceed_UnallocateOrderValidation_NEW      */
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-JUL-2022  CSCHONG  1.0  Devops Scripts Combine                    */
/************************************************************************/

CREATE PROC [dbo].[ispPKD05]
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT,
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT,
           @n_StartTCnt    INT

  --PRINT '123'

  SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

    DECLARE @n_IsRDT INT                        
    EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT      

 
    IF @n_IsRDT = 1
    GOTO QUIT_SP

--PRINT '@c_Action : ' + @c_Action

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

     -- WHILE @@TRANCOUNT > 0
     -- BEGIN
     --  COMMIT TRAN
     -- END

     BEGIN TRAN

   IF @c_Action = 'UPDATE'
   BEGIN
      -- PRINT 'DELETE'
      IF EXISTS (SELECT 1
                 FROM #INSERTED I
                 JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey
                 JOIN PACKHEADER PH (NOLOCK) ON I.Orderkey = PH.Orderkey
                 WHERE I.Storerkey = @c_Storerkey)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 38000
         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': pack exists, please unpack (ispPKD05)'
         ROLLBACK TRAN
         GOTO QUIT_SP
      END

     
   END

   IF @c_Action = 'DELETE'
   BEGIN

      IF EXISTS (SELECT 1
                 FROM #DELETED D
                 --JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey
                 JOIN PACKHEADER PH (NOLOCK) ON D.Orderkey = PH.Orderkey
                 WHERE D.Storerkey = @c_Storerkey)
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 38010
         SELECT @c_Errmsg=' NSQL'+CONVERT(varchar(5),@n_Err)+': pack exists, please unpack (ispPKD05)'
         ROLLBACK TRAN
         GOTO QUIT_SP
      END
 END
   QUIT_SP:

   -- SELECT @c_Errmsg ='testing'

      --WHILE @@TRANCOUNT > 0
      --BEGIN
      -- COMMIT TRAN
      --END 

   IF OBJECT_ID('tempdb..#DELETED_ID') IS NOT NULL
   BEGIN
      DROP TABLE #DELETED_ID
   END

  IF @n_Continue=3  -- Error Occured - Process AND Return
  BEGIN
     SELECT @b_Success = 0
     IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
     EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD05'
     --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
  END
  ELSE
  BEGIN
     SELECT @b_Success = 1
     WHILE @@TRANCOUNT > @n_StartTCnt
     BEGIN
         COMMIT TRAN
     END
     RETURN
  END

     --WHILE @@TRANCOUNT < @n_StartTCnt
     --BEGIN
     --    BEGIN TRAN
     --END
END

GO