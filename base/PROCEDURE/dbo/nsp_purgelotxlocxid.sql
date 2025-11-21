SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc : nsp_PurgeLotxLocxID                                    */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Input Parameters: NONE                                               */    
/*                                                                      */    
/* Output Parameters: NONE                                              */    
/*                                                                      */    
/* Return Status: NONE                                                  */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: Job                                                       */    
/*                                                                      */    
/* PVCS Version: 1.15                                                   */    
/*                                                                      */    
/* Version: 6.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author     Purposes                                     */    
/************************************************************************/    
    
CREATE PROC    [dbo].[nsp_PurgeLotxLocxID]          
AS    
/*-------------------------------------------------------------    
THIS WILL PURGE RECORDS IN THE FF TABLES IF ALL QTY = 0    
  LOT    
  LOTxLOCxID    
  SKUXLOC    
  ID    
---------------------------------------------------------------*/    
BEGIN      
   /* BEGIN 2005-Aug-18 (SOS38267) */    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
   /* END 2005-Aug-18 (SOS38267) */    
       
 DECLARE @n_continue int        ,      
    @n_StartTCnt int        , -- Holds the current transaction count    
    @n_cnt int              , -- Holds @@ROWCOUNT after certain operations    
    @b_debug int             -- Debug On OR Off    
        
 /* #INCLUDE <SPARPO1.SQL> */         
      DECLARE @cLOT NVARCHAR(10),    
            @cLOC NVARCHAR(10),    
            @cID  NVARCHAR(18),  
            @local_n_err INT,  
            @local_c_errmsg NVARCHAR(255)     
    
 SELECT @n_StartTCnt=@@TRANCOUNT , @n_continue=1, --@b_success=0, @n_err=0, @c_errmsg='',    
          @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '    
    
    
 IF @n_continue = 1 OR @n_continue = 2    
 BEGIN    
  BEGIN TRAN    
      
   ALTER TABLE PICKDETAIL NOCHECK CONSTRAINT ALL    
            
  IF @n_continue = 1 OR @n_continue = 2    
  BEGIN      
     DECLARE C_ARC_LOTxLOCxID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
       SELECT LOT, LOC, ID     
        FROM LOTxLOCxID WITH (NOLOCK)    
       WHERE Qty = 0    
         AND QtyAllocated = 0    
         AND QtyPicked = 0    
         AND PendingMoveIn = 0 -- (Vicky01)    
         AND NOT EXISTS ( SELECT 1 FROM PICKDETAIL PD with (NOLOCK)   -- tlting01  
                              LEFT JOIN ( SELECT DISTINCT StorerKey FROM StorerConfig SC (NOLOCK)   
                                 WHERE SC.ConfigKey = 'OWITF' AND SC.svalue= '1' ) As TSC ON TSC.Storerkey = PD.storerkey   
            WHERE  PD.LOT =   LOTxLOCxID.LOT   
            AND TSC.StorerKey IS NULL)   
                     
     OPEN C_ARC_LOTxLOCxID      
         
     FETCH NEXT FROM C_ARC_LOTxLOCxID INTO @cLOT, @cLOC, @cID     
         
     WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 OR @n_continue = 2 )    
     BEGIN    
        BEGIN TRAN     
               
        DELETE LOTxLOCxID     
         WHERE LOT = @cLOT    
           AND LOC = @cLOC    
           AND ID  = @cID    
            
        IF @@error <> 0     
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @local_n_err = 77303    
               SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)    
               SELECT @local_c_errmsg = ': Deleting LOTxLOCxID failed (nsp_PurgeLotxLocxID) ' + ' ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
            ROLLBACK    
            GOTO QUIT    
            END     
            ELSE    
            BEGIN    
               WHILE @@TRANCOUNT > 0    
                  COMMIT TRAN     
            END     
            
        IF (@n_continue = 1 OR @n_continue = 2)    
        BEGIN    
           IF NOT EXISTS(SELECT ID FROM LOTxLOCxID (NOLOCK) WHERE LOTxLOCxID.ID = @cID)    
           BEGIN    
              BEGIN TRAN     
                     
              DELETE ID WHERE ID = @cID     
              IF @@error <> 0     
              BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @local_n_err = 77303    
                  SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)    
                  SELECT @local_c_errmsg = ': Deleting ID failed (nsp_PurgeLotxLocxID) ' + ' ( ' +    
                   ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
                  ROLLBACK    
                  GOTO QUIT                     
              END     
                  ELSE    
                  BEGIN    
                     WHILE @@TRANCOUNT > 0    
                        COMMIT TRAN     
                  END                   
           END    
          END     
             
        FETCH NEXT FROM C_ARC_LOTxLOCxID INTO @cLOT, @cLOC, @cID     
     END -- WHILE    
     CLOSE C_ARC_LOTxLOCxID    
     DEALLOCATE C_ARC_LOTxLOCxID     
    END    
        
     ALTER TABLE PICKDETAIL CHECK CONSTRAINT ALL    
                
   
  -- SOS33899, Remove the remark by June 31.Mar.2005    
  -- Delete Lot after LOTxLOCxID     
  IF @n_continue = 1 OR @n_continue = 2    
  BEGIN    
     DECLARE C_ARC_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
     SELECT LOT.LOT      
       FROM LOT (NOLOCK)    
      WHERE LOT.Qty = 0    
        AND LOT.QtyAllocated = 0    
        AND LOT.QtyPicked = 0    
        AND NOT EXISTS ( SELECT 1 FROM  LOTxLOCxID WITH (NOLOCK)   
               WHERE  LOTxLOCxID.LOT = LOT.LOT  ) -- tlting   
      
     OPEN C_ARC_LOT      
         
     FETCH NEXT FROM C_ARC_LOT INTO @cLOT    
         
     WHILE @@FETCH_STATUS <> -1 AND ( @n_continue = 1 OR @n_continue = 2 )    
     BEGIN    
        BEGIN TRAN     
               
        DELETE LOT     
        WHERE LOT = @cLOT     
            
        IF @@error <> 0     
            BEGIN     
               SELECT @n_continue = 3    
         SELECT @local_n_err = 77303    
         SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)    
         SELECT @local_c_errmsg = ': Deleting LOT failed (nsp_PurgeLotxLocxID) ' + ' ( ' +    
             ' SQLSvr MESSAGE = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'    
            ROLLBACK    
            GOTO QUIT                     
          END     
            ELSE    
            BEGIN    
               WHILE @@TRANCOUNT > 0    
                  COMMIT TRAN     
            END    
            
        FETCH NEXT FROM C_ARC_LOT INTO @cLOT     
     END -- WHILE    
     CLOSE C_ARC_LOT    
     DEALLOCATE C_ARC_LOT        
      END     
      
  IF @n_continue = 1 OR @n_continue = 2    
  BEGIN    
   WHILE @@TRANCOUNT > 0    
     BEGIN    
      COMMIT TRAN    
     END    
  END    
  ELSE    
  BEGIN    
   ROLLBACK TRAN    
  END    
 END    
    
   
    
 /* #INCLUDE <SPARPO2.SQL> */         
QUIT:    
     
 IF @n_continue=3  -- Error Occured - Process AND Return    
 BEGIN    
  --SELECT @b_success = 0    
  IF @@TRANCOUNT > 0     
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
    
   
  IF (@b_debug = 1)    
  BEGIN    
   SELECT   'before putting in nsp_logerr at the bottom'    
  END    
    
  EXECUTE dbo.nsp_logerror @local_n_err, @local_c_errmsg, 'nsp_PurgeLotxLocxID'  -- (YokeBeen01)    
  RAISERROR (@local_c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
  RETURN    
 END    
 ELSE    
 BEGIN    
 -- SELECT @b_success = 1    
  WHILE @@TRANCOUNT > @n_StartTCnt    
  BEGIN    
   COMMIT TRAN    
  END    
  RETURN    
 END    
     
END -- main     
   

GO