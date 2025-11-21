SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Trigger: ntrPackInfoDelete                                           */          
/* Creation Date:                                                       */          
/* Copyright: LFL                                                       */          
/* Written by:                                                          */          
/*                                                                      */          
/* Purpose:                                                             */          
/*                                                                      */          
/* Usage:                                                               */          
/*                                                                      */          
/* Called By: When records delete from Packinfo                         */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Modifications:                                                       */          
/* Date         Author     Ver.  Purposes                               */      
/* 14-Jul-2011  KHLim02    1.0   GetRight for Delete log                */  
/* 30-Jul-2021  NJOW01     1.1   WMS-17609 - call custom stored proc to */  
/*                               remove packinfo trackingno             */  
/************************************************************************/     
  
CREATE TRIGGER dbo.ntrPackInfoDelete  
ON dbo.PackInfo  
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
  
   DECLARE  @b_Success     int,       -- Populated by calls to stored procedures - was the proc successful?  
            @n_err         int,       -- Error number returned by stored procedure or this trigger  
            @c_errmsg      NVARCHAR(250), -- Error message returned by stored procedure or this trigger  
            @n_continue    int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing  
            @n_starttcnt   int,       -- Holds the current transaction count  
            @n_cnt         INT,       -- Holds the number of rows affected by the DELETE statement that fired this trigger.  
            @c_authority   NVARCHAR(1),  -- KHLim02  
            @c_Storerkey   NVARCHAR(15),  
            @c_Facility    NVARCHAR(5),  
            @c_PackinfoDelTrackingNo_SP NVARCHAR(30),  
            @c_Pickslipno  NVARCHAR(10),  
            @n_Cartonno    INT,  
            @c_TrackingNo  NVARCHAR(40)  
             
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
   IF (SELECT count(*) FROM DELETED) =  
   (SELECT count(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN  
      SELECT @n_continue = 4  
   END  
        
      /* #INCLUDE <TRCONHD1.SQL> */       
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @b_success = 0         --    Start (KHLim02)  
      EXECUTE nspGetRight  NULL,             -- facility    
                           NULL,             -- Storerkey    
                           NULL,             -- Sku    
                           'DataMartDELLOG', -- Configkey    
                           @b_success     OUTPUT,   
                           @c_authority   OUTPUT,   
                           @n_err         OUTPUT,   
                           @c_errmsg      OUTPUT    
      IF @b_success <> 1  
      BEGIN  
         SELECT @n_continue = 3  
               ,@c_errmsg = 'ntrPackInfoDelete' + dbo.fnc_RTrim(@c_errmsg)  
      END  
      ELSE   
      IF @c_authority = '1'         --    End   (KHLim02)  
      BEGIN  
         INSERT INTO dbo.PackInfo_DELLOG ( PickSlipNo, CartonNo )  
         SELECT PickSlipNo, CartonNo FROM DELETED  
  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PackInfo Failed. (ntrPackInfoDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '  
         END  
      END  
   END  
     
   --NJOW01  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @c_Storerkey = ORDERS.StorerKey,  
             @c_Facility = ORDERS.Facility  
      FROM DELETED   
      JOIN PICKHEADER (NOLOCK) ON DELETED.PickSlipNo = PICKHEADER.Pickheaderkey  
      JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey   
        
      IF(ISNULL(@c_Storerkey,'') = '')  
      BEGIN  
         SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,  
                      @c_Facility = ORDERS.Facility  
         FROM DELETED  
         JOIN PICKHEADER (NOLOCK) ON DELETED.PickSlipNo = PICKHEADER.Pickheaderkey   
         JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.LOADKEY = PICKHEADER.ExternOrderkey  
         JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      END   
      
      --For ECOM having temporary pickslipno, starts with T
      IF(ISNULL(@c_Storerkey,'') = '')  
      BEGIN  
         SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey,  
                      @c_Facility = ORDERS.Facility  
         FROM DELETED  
         JOIN PACKHEADER (NOLOCK) ON DELETED.PickSlipNo = PACKHEADER.PickSlipNo   
         JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
      END      

      EXEC nspGetRight    
           @c_Facility  = @c_Facility,    
           @c_StorerKey = @c_StorerKey,    
           @c_sku       = NULL,    
           @c_ConfigKey = 'PackinfoDelTrackingNo_SP',     
           @b_Success   = @b_Success                  OUTPUT,    
           @c_authority = @c_PackinfoDelTrackingNo_SP OUTPUT,     
           @n_err       = @n_err                      OUTPUT,     
           @c_errmsg    = @c_errmsg                   OUTPUT    
              
      IF EXISTS(SELECT 1 FROM sys.Objects WHERE NAME = @c_PackinfoDelTrackingNo_SP AND TYPE = 'P')     
      BEGIN    
        DECLARE CUR_PKINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
           SELECT Pickslipno, CartonNo, TrackingNo  
           FROM DELETED   
           
         OPEN CUR_PKINFO     
           
         FETCH NEXT FROM CUR_PKINFO INTO @c_Pickslipno, @n_Cartonno, @c_TrackingNo  
  
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)             
         BEGIN                                                           
            SET @b_Success = 0    
              
            EXECUTE isp_PackinfoDelTrackingNo_Wrapper   
                    @c_Pickslipno = @c_Pickslipno  
                  , @n_CartonNo  = @n_CartonNo  
                  , @c_TrackingNo = @c_TrackingNo  
                  , @c_PackinfoDelTrackingNo_SP = @c_PackinfoDelTrackingNo_SP    
                  , @b_Success = @b_Success     OUTPUT    
                  , @n_Err     = @n_err         OUTPUT     
                  , @c_ErrMsg  = @c_errmsg      OUTPUT    
              
            IF @b_Success <> 1  
            BEGIN    
               SELECT @n_continue = 3    
            END    
              
            FETCH NEXT FROM CUR_PKINFO INTO @c_Pickslipno, @n_Cartonno, @c_TrackingNo    
         END           
         CLOSE CUR_PKINFO  
         DEALLOCATE CUR_PKINFO        
      END     
   END  
  
      /* #INCLUDE <TRCOND2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackInfoDelete'  
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