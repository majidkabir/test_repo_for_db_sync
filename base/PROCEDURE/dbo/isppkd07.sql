SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPKD07                                           */
/* Creation Date: 12-APR-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22099 CN Converse Update empty refno to LF-CD           */
/*                                                                      */
/* Called By: isp_PickDetailTrigger_Wrapper from Pickdetail Trigger     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE   PROC [dbo].[ispPKD07]
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
           @n_StartTCnt    INT,
           @c_Pickslipno   NVARCHAR(10),
           @c_LabelNo      NVARCHAR(20),
           @c_LabelLine    NVARCHAR(5)

	 SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END

	 IF @c_Action = 'INSERT'
	 BEGIN	 	 
   	  DECLARE CUR_PACKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	 	     SELECT I.Pickslipno, I.LabelNo, I.LabelLine
	 	     FROM #INSERTED I
	 	     WHERE I.Storerkey = @c_Storerkey
	 	     AND ISNULL(I.RefNo,'') = ''
	 	     ORDER BY I.Pickslipno, I.Labelno
	 	     
   	  OPEN CUR_PACKD

      FETCH NEXT FROM CUR_PACKD INTO @c_Pickslipno, @c_LabelNo, @c_LabelLine

      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	 UPDATE PACKDETAIL WITH (ROWLOCK)
      	 SET Refno = 'LF-CD',
      	     ArchiveCop = NULL,
      	     EditWho = SUSER_SNAME(),
      	     EditDate = GETDATE()
      	 WHERE Pickslipno = @c_Pickslipno
      	 AND LabelNo = @c_LabelNo
      	 AND LabelLine = @c_LabelLine
      	 AND ISNULL(RefNo,'') = ''
      	 
         SET @n_Err = @@ERROR

         IF @n_Err <> 0
         BEGIN
         	  SELECT @n_Continue = 3
	          SELECT @n_Err = 35100
	          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PACKDETAIL Table Failed. (ispPKD07)'
         END

         FETCH NEXT FROM CUR_PACKD INTO @c_Pickslipno, @c_LabelNo, @c_LabelLine
      END   
      CLOSE CUR_PACKD
      DEALLOCATE CUR_PACKD
	 END

   QUIT_SP:

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
	    EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD07'
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
END

GO