SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Trigger: ntrPackQRFDelete                                            */        
/* Creation Date:                                                       */        
/* Copyright: IDS                                                       */        
/* Written by: Wan                                                      */        
/*                                                                      */        
/* Purpose: WMS-14315 - [CN] NIKE_O2_Ecom Packing_CR                    */        
/*                                                                      */        
/* Usage:                                                               */        
/*                                                                      */        
/* Called By: When records delete from PackDetail                       */        
/*                                                                      */        
/* PVCS Version: 2.0                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Modifications:                                                       */        
/* Date         Author     Ver.  Purposes                               */    
/************************************************************************/        
CREATE TRIGGER [ntrPackQRFDelete] ON [PackQRF]      
FOR  DELETE      
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
          
 DECLARE @b_Success     INT = 1 -- Populated by calls to stored procedures - was the proc successful?      
       , @n_err         INT = 0 -- Error number returned by stored procedure or this trigger      
       , @c_errmsg      NVARCHAR(250) = ''-- Error message returned by stored procedure or this trigger      
       , @n_continue    INT = 1     
       , @n_starttcnt   INT = @@TRANCOUNT  -- Holds the current transaction count      
  
       , @n_ExternOrdersKey         BIGINT = 0  
       , @n_ExternOrderDetailKey    BIGINT = 0

       , @c_Facility                NVARCHAR(5) = ''     
       , @c_Storerkey               NVARCHAR(15)= ''  
       
       , @c_PickSlipNo              NVARCHAR(10)= ''          
       , @c_Orderkey                NVARCHAR(10)= ''   
         
       , @cur_PQRF                  CURSOR 
       , @cur_EOD                   CURSOR        
                  
   IF (SELECT COUNT(1) FROM   DELETED) =      
      (SELECT COUNT(1) FROM   DELETED WHERE  DELETED.ArchiveCop = '9')      
   BEGIN      
      SET @n_continue = 4      
   END       
   
   --(Wan01) - START PackQRF
   IF @n_continue=1 OR @n_continue=2   
   BEGIN
      SET @cur_PQRF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT DISTINCT D.PickSlipNo
            , PH.Orderkey
            , EO.ExternOrdersKey
      FROM DELETED D
      JOIN PACKHEADER   PH WITH (NOLOCK) ON D.PickSlipNo= PH.PickSlipNo 
      JOIN EXTERNORDERS EO WITH (NOLOCK) ON EO.Orderkey = PH.Orderkey 
      LEFT OUTER JOIN PACKQRF PQRF WITH (NOLOCK) ON D.PickSlipNo= PQRF.PickSlipNo
      WHERE PH.[Status] < '9'
      AND   PH.Orderkey <> ''
      AND   PQRF.PackQRFKey IS NULL
      ORDER BY D.PickSlipNo

      OPEN @cur_PQRF  
          
      FETCH NEXT FROM @cur_PQRF INTO   @c_PickSlipNo
                                    ,  @c_Orderkey
                                    ,  @n_ExternOrdersKey  
        
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         DELETE ExternOrders 
         WHERE ExternOrdersKey = @n_ExternOrdersKey    

         SET @n_err = @@ERROR      
         
         IF @n_err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 62010
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table ExternOrders. (ntrPackQRFDelete)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
            BREAK
         END 

         SET @cur_EOD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT EOD.ExternOrderDetailKey
         FROM ExternOrdersDetail EOD WITH (NOLOCK)
         WHERE EOD.Orderkey = @c_Orderkey

         OPEN @cur_EOD

         FETCH NEXT FROM @cur_EOD INTO @n_ExternOrderDetailKey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE ExternOrdersDetail 
            WHERE ExternOrderDetailKey = @n_ExternOrderDetailKey  

            SET @n_err = @@ERROR      
         
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(char(250),@n_err)
               SET @n_err = 62020
               SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table ExternOrdersDetail. (ntrPackQRFDelete)' 
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
               BREAK
            END     

            FETCH NEXT FROM @cur_EOD INTO @n_ExternOrderDetailKey
         END
         CLOSE @cur_EOD
         DEALLOCATE @cur_EOD

         FETCH NEXT FROM @cur_PQRF INTO   @c_PickSlipNo
                                       ,  @c_Orderkey
                                       ,  @n_ExternOrdersKey 
      END
      CLOSE @cur_PQRF
      DEALLOCATE @cur_PQRF
   END
   --(Wan01) - END PackQRF
 
   IF @n_continue=3 -- Error Occured - Process And Return      
   BEGIN      
      IF @@TRANCOUNT = 1      
      AND @@TRANCOUNT >= @n_starttcnt      
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPackQRFDelete"       
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012       
      RETURN      
   END      
   ELSE      
   BEGIN      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         COMMIT TRAN      
      END       
      RETURN      
   END      
END 


GO