SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store Procedure:  rdt_TMTask                                          	*/  
/* Creation Date:                                                       	*/  
/* Copyright: IDS                                                       	*/  
/* Written by: ChewKP                                                     	*/  
/*                                                                      	*/  
/* Purpose:  Insert Record to TaskDetail                                  	*/  
/*                                                                      	*/  
/* Input Parameters:                                                    	*/  
/*                                                                      	*/  
/* Output Parameters:  None                                             	*/  
/*                                                                      	*/  
/* Return Status:  None                                                 	*/  
/*                                                                      	*/  
/* Usage:                                                               	*/  
/*                                                                      	*/  
/* Local Variables:                                                     	*/  
/*                                                                      	*/  
/* Called By:                                                           	*/  
/*                                                                      	*/  
/* PVCS Version: 1.3                                                   		*/  
/*                                                                      	*/  
/* Version: 5.4                                                         	*/  
/*                                                                      	*/  
/* Data Modifications:                                                  	*/  
/*                                                                      	*/  
/* Updates:                                                             	*/  
/* Date         Author    Ver.  	Purposes                                	*/
/* 01-06-2010   ChewKP    1.1    Add In AreaKey Parameters (ChewKP01)      */
/* 21-06-2010   ChewKP    1.1    Add In CaseID Parameters (ChewKP02)       */
/***************************************************************************/  
CREATE PROC  [RDT].[rdt_TMTask] 
             @c_TaskKey       NVARCHAR(10)       
            ,@c_TaskType      NVARCHAR(10)
            ,@c_RefTaskkey    NVARCHAR(10)     
            ,@c_storerkey     NVARCHAR(15)      
            ,@c_sku           NVARCHAR(20)
            ,@c_lot           NVARCHAR(10)
            ,@c_Fromloc       NVARCHAR(10)
            ,@c_FromID        NVARCHAR(18)
            ,@c_ToLoc         NVARCHAR(10)
            ,@c_Toid          NVARCHAR(18)            
            ,@c_UOM           NVARCHAR(5)  
            ,@n_UOMQTY        INT
            ,@n_QTY           INT
            ,@c_sourcekey     NVARCHAR(20) 
            ,@c_sourcetype    NVARCHAR(30)    
            ,@c_Taskstatus    NVARCHAR(10)
            ,@c_TaskFlag      NVARCHAR(1) -- 'A' Insert , 'D' Delete
            ,@c_UserName      NVARCHAR(18)
            ,@b_Success       INT       = 1   OUTPUT      
            ,@c_errmsg        NVARCHAR(250) = 1   OUTPUT   
            ,@c_Areakey       NVARCHAR(10) = '' -- (ChewKP01)
            ,@c_CaseID        NVARCHAR(8) = ''  -- (ChewKP02)
               
 AS      
 BEGIN      
  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_NULLS OFF  
   
   DECLARE
    @n_continue         INT 
   ,@c_newtaskdetailkey NVARCHAR(10) 
   ,@n_starttcnt        INT         -- Holds the current transaction count   
   ,@n_err             INT               -- For Additional Error Detection 
	,@c_loadkey          NVARCHAR(10)

   IF Len(@c_caseID) = ''
   BEGIN
		SET @c_loadkey = @c_sourcekey
	END
	ELSE
	BEGIN
		SET @c_loadkey = ''
	END

   SET @n_continue = 1
   SET @n_starttcnt= @@TRANCOUNT 
   BEGIN TRAN   
                   
   IF @n_continue = 1  And @c_TaskFlag = 'A'
   BEGIN      
      INSERT dbo.TASKDETAIL WITH (ROWLOCK)     
         (      
         TaskDetailKey  
         ,RefTaskkey     
         ,TaskType         
         ,Storerkey             
         ,Sku                        
         ,Lot              
         ,FromLoc          
         ,FromID                   
         ,ToLoc      
         ,ToId      
         ,UOM      
         ,UOMQTY      
         ,QTY      
         ,Status
         ,Sourcekey      
         ,Sourcetype    
         ,Priority    
         ,userkey  
         ,Loadkey
         ,Areakey -- (ChewKP01)
         ,CaseID -- (ChewKP02)
         )      
      VALUES      
         (      
         @c_TaskKey   
         ,@c_RefTaskkey   
         ,@c_TaskType      
         ,@c_storerkey      
         ,@c_sku      
         ,@c_lot   
         ,@c_Fromloc      
         ,@c_FromID
         ,@c_ToLoc -- pick and drop loc      
         ,@c_TOID      
         ,@c_UOM
         ,@n_UOMQTY      
         ,@n_QTY  
         ,@c_TaskStatus
         ,@c_sourcekey      
         ,@c_sourcetype      
         ,'9'  
         ,@c_Username
         ,@c_loadkey 
         ,@c_Areakey   -- (ChewKP01)
         ,@c_CaseID		-- (ChewKP02)
         )      

      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
         SELECT @n_continue = 3       
         /* Trap SQL Server Error */      
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=60029 -- 65132   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On TaskDetail. (rdt_TMTask)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '      
         /* End Trap SQL Server Error */ 
         GOTO QUIT    
      END
   END   
   ELSE IF @n_continue = 1  And @c_TaskFlag = 'D'   
   BEGIN
                        
      DELETE FROM dbo.TASKDETAIL WITH (ROWLOCK)
      WHERE TaskDetailKey = @c_TaskKey

      SELECT @n_err = @@ERROR      
      IF @n_err <> 0      
      BEGIN      
         SELECT @n_continue = 3       
         /* Trap SQL Server Error */      
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=60030 -- 65132   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Failed On TaskDetail. (rdt_TMTask)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '      
         /* End Trap SQL Server Error */ 
         GOTO QUIT    
      END

   END

   QUIT:                   
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
        execute nsp_logerror @n_err, @c_errmsg, 'rdt_TMTask'      
        RAISERROR (@n_err, 10, 1) WITH SETERROR   
      END      
      ELSE      
      BEGIN      
        /* Error Did Not Occur , Return Normally */      
        SELECT @b_success = 1      
        WHILE @@TRANCOUNT > @n_starttcnt       
        BEGIN      
             COMMIT TRAN      
        END                
        RETURN      
       END      
      /* End Return Statement */   
      /* End Return Statement */           
 END

GO