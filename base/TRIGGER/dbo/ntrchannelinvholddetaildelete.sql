SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrChannelInvHoldDetailDelete                               */
/* Creation Date: 29-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for Channel           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-05-10  Wan01    1.1   Fixed- Skip Archive checking              */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrChannelInvHoldDetailDelete]
ON  [dbo].[ChannelInvHoldDetail]
FOR DELETE   
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END 

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         , @n_err             INT = 0
         , @c_errmsg          NVARCHAR(255) = ''

         , @CUR_HOLD          CURSOR

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9') -- Wan01     
   BEGIN
      SET @n_continue = 4 
      GOTO QUIT_TR
   END

   --IF UPDATE(TrafficCop)
   --BEGIN
   --   SET @n_continue = 4 
   --   GOTO QUIT_TR
   --END
 
   IF EXISTS ( SELECT 1
               FROM   DELETED
               WHERE  DELETED.Hold = '1'
            )
   BEGIN 
      SET @n_continue = 3 
      SET @n_err = 70100  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete rejected. Channel Inventory Still On Hold. (ntrChannelInvHoldDetailDelete)'
   END   

 QUIT_TR:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ntrChannelInvHoldDetailDelete'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO