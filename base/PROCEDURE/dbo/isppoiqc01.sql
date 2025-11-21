SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPOIQC01                                                  */
/* Creation Date: 09-NOV-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6868 - JDSPORTS post finalize iqc update id channel     */      
/*                                                                      */
/* Called By: ispPostFinalizeIQCWrapper                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPOIQC01] 
            @c_qc_key         NVARCHAR(10)
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt            INT
         , @n_Continue             INT 
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF @n_continue IN(1,2)
   BEGIN
      UPDATE ID WITH (ROWLOCK)                                                                                      
      SET ID.Channel = IQCD.Channel                                                                                       
      FROM ID                                                                                                       
      JOIN INVENTORYQCDETAIL IQCD (NOLOCK) ON IQCD.ToId = ID.ID                                                               
      WHERE IQCD.QC_Key = @c_qc_key                                                                           

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63520
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ID Table Failed! (ispPOIQC01)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END   	     	           
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOIQC01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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