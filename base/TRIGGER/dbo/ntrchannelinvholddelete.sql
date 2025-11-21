SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrChannelInvHoldDelete                                     */
/* Creation Date: 29-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for Channel           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-05-10  Wan01    1.1   Fixed- Skip Archive checking              */
/************************************************************************/
CREATE TRIGGER [dbo].[ntrChannelInvHoldDelete]
ON  [dbo].[ChannelInvHold]
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

         , @n_RefID           BIGINT = 0
          
         , @CUR_DET           CURSOR

   IF (SELECT COUNT(1) FROM DELETED) = (SELECT COUNT(1) FROM DELETED WHERE DELETED.ArchiveCop = '9') -- Wan01  
   BEGIN
      SET @n_continue = 4 
      GOTO QUIT_TR
   END

   --IF UPDATE(TrafficCop)    --(Wan01)
   --BEGIN
   --   SET @n_continue = 4 
   --   GOTO QUIT_TR
   --END
 
   IF EXISTS ( SELECT 1
               FROM   DELETED
               JOIN   ChannelInvHoldDetail HD WITH (NOLOCK)
                     ON DELETED.InvHoldkey = HD.InvHoldkey
               WHERE  DELETED.Hold = '1'
            )
   BEGIN 
      SET @n_continue = 3 
      SET @n_err = 70050  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete rejected. Channel Inventory Still On Hold. (ntrChannelInvHoldDelete)'
   END   

   IF @n_Continue IN (1,2) 
   BEGIN
      SET @CUR_DET = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT HD.RefID 
      FROM DELETED
      JOIN  ChannelInvHoldDetail HD WITH (NOLOCK)
            ON DELETED.InvHoldkey = HD.InvHoldkey
      WHERE DELETED.Hold = '0'

      OPEN @CUR_DET

      FETCH NEXT FROM @CUR_DET INTO @n_RefID 

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE ChannelInvHoldDetail
         WHERE RefID = @n_RefID
         AND Hold = '0'

         SET @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3 
            SET @c_errmsg = CONVERT(char(5), @n_err)
            SET @n_err    = 70051              
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': Unable to Delete ChannelInvHoldDetail record (ntrChannelInvHoldDelete)'     
                          +' ( ' + ' SQLSvr MESSAGE='+@c_errmsg + ' ) '  
         END 
         FETCH NEXT FROM @CUR_DET INTO @n_RefID            
      END          
   END

 QUIT_TR:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ntrChannelInvHoldDelete'
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