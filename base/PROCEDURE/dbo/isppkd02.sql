SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPKD02                                           */  
/* Creation Date: 29-Apr-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 356566-UK-reject update short pick if the pickdetail is pack*/     
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
/* 28-Dec-2015  SHONG    1.1  SOS#359267 Not allow to Change DropID     */
/*                            after packed                              */
/************************************************************************/  
  
CREATE PROC [dbo].[ispPKD02]     
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
                                               
  SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1  
  
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')  
      GOTO QUIT_SP        
  
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL  
   BEGIN  
      GOTO QUIT_SP  
   END     
     
   IF @c_Action = 'UPDATE'      
   BEGIN      
      IF EXISTS (SELECT 1      
                 FROM #INSERTED I      
                 JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey      
                 JOIN PACKHEADER PH (NOLOCK) ON I.Orderkey = PH.Orderkey  
                 JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                 WHERE I.Storerkey = @c_Storerkey    
                 AND I.Status <> D.Status  
                 AND D.Status = '4')                  
      BEGIN      
         SELECT @n_Continue = 3       
         SELECT @n_Err = 38000      
         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update Short Pick Status Failed. The order already packed. (ispPKD02)'      
         GOTO QUIT_SP             
      END            
  
      IF EXISTS (SELECT 1      
                 FROM #INSERTED I      
                 JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey      
                 JOIN PACKHEADER PH (NOLOCK) ON I.Orderkey = PH.Orderkey  
                 JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                 WHERE I.Storerkey = @c_Storerkey    
                 AND I.Qty > D.Qty  
                 AND D.Status = '4')                  
      BEGIN      
         SELECT @n_Continue = 3       
         SELECT @n_Err = 38010      
         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update Short Pick Qty Failed. The order already packed. (ispPKD02)'      
         GOTO QUIT_SP             
      END            
      
      IF EXISTS (SELECT 1      
                 FROM #INSERTED I      
                 JOIN #DELETED D ON I.Pickdetailkey = D.Pickdetailkey      
                 JOIN PACKHEADER PH (NOLOCK) ON I.Orderkey = PH.Orderkey  
                 JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno AND D.DropID = PD.DropID 
                 WHERE I.Storerkey = @c_Storerkey    
                 AND I.DropID <> D.DropID )                  
      BEGIN      
         SELECT @n_Continue = 3       
         SELECT @n_Err = 38011      
         SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update Drop ID Failed. The order already packed. (ispPKD02)'      
         GOTO QUIT_SP             
      END                  
   END                      
        
   QUIT_SP:  
     
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
     EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPKD02'    
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