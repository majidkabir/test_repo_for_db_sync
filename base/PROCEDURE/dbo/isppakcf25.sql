SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Stored Procedure: ispPAKCF25                                            */  
/* Creation Date: 10-JUL-2023                                              */  
/* Copyright: MAERSK                                                       */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-23042 - SG - RTFKT - ECOM Exceed Packing Module            */  
/*                                                                         */  
/* Called By: PostPackConfirmSP                                            */  
/*                                                                         */  
/* GitLab Version: 1.0                                                     */  
/*                                                                         */  
/* Version: 7.0                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author     Ver   Purposes                                  */  
/* 10-JUL-2023  CSCHONG    1.0   DevOps Combine Script                     */  
/* 23-AUG-2023  CSCHONG     1.1  WMS-23042 Fix packinfo trackingno         */
/*                               not update (CS01)                         */
/***************************************************************************/    
CREATE    PROC [dbo].[ispPAKCF25]    
(     @c_PickSlipNo  NVARCHAR(10)     
  ,   @c_Storerkey   NVARCHAR(15)  
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug           INT    
         , @n_Continue        INT     
         , @n_StartTCnt       INT     
     
   DECLARE @c_Orderkey        NVARCHAR(10)    
         , @c_Country         NVARCHAR(30)    
         , @c_TrackingNo      NVARCHAR(30)    
         , @c_M_Company       NVARCHAR(45)   
         , @n_CartonNo        INT  
                
   SET @b_Success= 1     
   SET @n_Err    = 0      
   SET @c_ErrMsg = ''    
   SET @b_Debug  = 0     
   SET @n_Continue = 1      
   SET @n_StartTCnt = @@TRANCOUNT      
      
   IF @@TRANCOUNT = 0    
      BEGIN TRAN    
    
   SELECT @c_TrackingNo = O.TrackingNo,    
          @c_Country = ISNULL(O.c_Country,''),    
          @c_Storerkey = O.Storerkey,    
          @c_Orderkey = O.Orderkey,    
          @c_M_Company = ISNULL(O.M_Company,'')   
   FROM PICKHEADER PH (NOLOCK)    
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey    
   WHERE PH.Pickheaderkey = @c_Pickslipno  
      
   IF @c_Country <> 'SG'  
   BEGIN  
         IF @n_continue IN(1,2)  
         BEGIN  
            UPDATE ORDERS WITH (ROWLOCK)  
            SET SOStatus = '5'  
            WHERE Orderkey = @c_Orderkey  
  
            SET @n_Err = @@ERROR  
  
            IF @n_Err <> 0  
            BEGIN  
                SELECT @n_Continue = 3  
                SELECT @n_Err = 38010  
                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Failed. (ispPAKCF25)'  
            END  
         END  
  
         IF @n_continue IN(1,2)  
         BEGIN  
            EXEC dbo.ispGenTransmitLog2 'WSSOCFMLOG', @c_OrderKey, '0', @c_StorerKey, ''  
                , @b_success OUTPUT  
                , @n_err OUTPUT  
                , @c_errmsg OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
                SELECT @n_Continue = 3  
                SELECT @n_Err = 38020  
                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Generate pack confirm transmitlog2 Failed. (ispPAKCF25)'  
            END  
         END  
  
         IF @n_continue IN(1,2)  
         BEGIN              UPDATE PACKDETAIL WITH (ROWLOCK)  
            SET RefNo = @c_TrackingNo,  
                RefNo2 = RTRIM(@c_country) + @c_M_Company,  --NJOW01  
                ArchiveCop = NULL  
            WHERE Pickslipno = @c_Pickslipno  
  
            SET @n_Err = @@ERROR  
  
             IF @n_Err <> 0  
            BEGIN  
                SELECT @n_Continue = 3  
                SELECT @n_Err = 38030  
                SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PACKDETAIL Table Failed. (ispPAKCF25)'  
            END  
         END  
   END  
   ELSE  
   BEGIN  
  
            IF @n_continue IN(1,2)  
            BEGIN    
               UPDATE ORDERS WITH (ROWLOCK)    
               SET SOStatus = '5'    
                  ,TrackingNo = @c_PickSlipNo  
               WHERE Orderkey = @c_Orderkey    
          
               SET @n_Err = @@ERROR    
                              
               IF @n_Err <> 0    
               BEGIN    
                   SELECT @n_Continue = 3     
                   SELECT @n_Err = 38040    
                   SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Failed. (ispPAKCF25)'    
               END           
            END         
       
            IF @n_continue IN(1,2)    
            BEGIN    
               EXEC dbo.ispGenTransmitLog2 'WSSOCFMLOG', @c_OrderKey, '0', @c_StorerKey, ''    
                   , @b_success OUTPUT    
                   , @n_err OUTPUT    
                   , @c_errmsg OUTPUT    
              
               IF @b_success <> 1    
               BEGIN    
                   SELECT @n_Continue = 3     
                   SELECT @n_Err = 38050    
                   SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Generate pack confirm transmitlog2 Failed. (ispPAKCF25)'    
               END                
            END    
  
            IF @n_continue IN(1,2)    
            BEGIN  
               DECLARE cur_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT DISTINCT PD.CartonNo                           --CS01
               FROM dbo.PackDetail PD (NOLOCK)  
               WHERE PD.PickSlipNo = @c_PickSlipNo  
               ORDER BY PD.CartonNo  
  
               OPEN cur_PACKDETAIL  
  
               FETCH NEXT FROM cur_PACKDETAIL INTO @n_CartonNo  
  
               WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
               BEGIN  
  
                     UPDATE PACKDETAIL WITH (ROWLOCK)    
                     SET RefNo =  @c_PickSlipNo + CAST(@n_CartonNo AS NVARCHAR(5)),    
                           RefNo2 = RTRIM(@c_country) + @c_M_Company,   
                           ArchiveCop = NULL    
                     WHERE Pickslipno = @c_Pickslipno    
                     AND cartonno = @n_CartonNo   
                      
             
                       SET @n_err = @@ERROR  
             
                        IF @n_err <> 0   
                        BEGIN    
                           SET @n_continue = 3    
                           SET @n_Err = 38060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                           SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)     
                                             + ': Update Packdetail Table Failed. (ispPAKCF25) ( SQLSvr MESSAGE='     
                                               + @c_errmsg + ' ) '   
                           GOTO QUIT_SP                       
                        END                      
  
                       UPDATE PACKINFO WITH (ROWLOCK)  
                       SET TrackingNo = @c_PickSlipNo + CAST(@n_CartonNo AS NVARCHAR(5)),--@c_TrackingNo,    --CS01
                           TrafficCop = NULL  
                       WHERE Pickslipno = @c_Pickslipno     
                       AND cartonno = @n_CartonNo                          
  
                       SET @n_err = @@ERROR  
             
                     IF @n_err <> 0   
                     BEGIN    
                        SET @n_continue = 3    
                        SET @n_Err = 38070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                        SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)     
                                          + ': Update PackInfo Table Failed. (ispPAKCF25) ( SQLSvr MESSAGE='     
                                            + @c_errmsg + ' ) '   
                        GOTO QUIT_SP                       
                     END                      
               FETCH NEXT FROM cur_PACKDETAIL INTO @n_CartonNo  
               END  
               CLOSE cur_PACKDETAIL  
               DEALLOCATE cur_PACKDETAIL    
             END         
    END  
QUIT_SP:  
 IF CURSOR_STATUS('LOCAL', 'cur_PACKDETAIL') IN (0 , 1)  
   BEGIN  
      CLOSE cur_PACKDETAIL  
      DEALLOCATE cur_PACKDETAIL  
   END  
  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF25'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
        COMMIT TRAN  
      END   
      RETURN  
   END   
END  

GO