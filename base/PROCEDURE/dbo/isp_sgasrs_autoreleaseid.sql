SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_SGASRS_AutoReleaseID                            */  
/* Creation Date: 10-Apr-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-12416 & WMS-18772 - SG ASRS AutoReleaseID                */
/*                                                                       */  
/* Called By: Schedule Job                                               */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/* 10-Apr-2020  WLChooi  1.0  DevOps Combine Script                      */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[isp_SGASRS_AutoReleaseID]      
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_continue INT,    
           @n_starttcnt INT,         -- Holds the current transaction count  
           @n_debug INT,
           @n_cnt INT,
           @b_success INT,
           @n_err INT,
           @c_errmsg NVARCHAR(255)
            
   SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT  @n_debug = 0

   DECLARE @c_Storerkey           NVARCHAR(15)
          ,@c_Facility            NVARCHAR(5)
          ,@c_ID                  NVARCHAR(18)

   --BEGIN TRAN

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT IH.ID
   FROM INVENTORYHOLD IH (NOLOCK)
   WHERE LEN(IH.ID) = 8
   AND ISNUMERIC(IH.ID) = 1
   AND IH.Hold = '1'

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_ID

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM Lotxlocxid LLI (NOLOCK) WHERE LLI.ID = @c_ID AND LLI.Qty > 0)
      BEGIN
         EXEC nspInventoryHoldWrapper
              '',               -- lot
              '',               -- loc
              @c_ID,             -- id
              '',               -- storerkey
              '',               -- sku
              '',               -- lottable01
              '',               -- lottable02
              '',               -- lottable03
              NULL,             -- lottable04
              NULL,             -- lottable05
              '',               -- lottable06
              '',               -- lottable07
              '',               -- lottable08
              '',               -- lottable09
              '',               -- lottable10
              '',               -- lottable11
              '',               -- lottable12
              NULL,             -- lottable13
              NULL,             -- lottable14
              NULL,             -- lottable15
              'SYSUNHOLD',      -- status
              '0',              -- hold  0=unhold 1=hold
              @b_success OUTPUT,
              @n_err OUTPUT,
              @c_errmsg OUTPUT,
              ''                -- reason

         IF @n_err <> 0  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 61010  
            SET @c_ErrMsg= 'NSQL'+CONVERT(char(5),@n_err)+': Unhold Failed. (isp_SGASRS_AutoReleaseID)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '  
            GOTO QUIT_SP   
         END  
      END
      FETCH NEXT FROM CUR_LOOP INTO @c_ID
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'isp_SGASRS_AutoReleaseID'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END          
END --sp end

GO