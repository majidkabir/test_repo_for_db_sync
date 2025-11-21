SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: nsp_ConfirmReplenishment                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Confirm all the outstanding replenishment                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Power Builder Replenishment Module                        */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 08-Apr-2005  Shong         Performence Tuning                        */
/* 12-Jun-2008  Shong         Include Confirmed = 'L' for  Nike Repln   */
/*                            Report                                    */
/* 16-Nov-2008  NJOW01        SOS121216 Confirmation by storerkey or ALL*/
/* 25-Aug-2010  Shong   1.3   Not allow to post is TMReplenishmentOnly  */
/*                            StorerConfig turn ON. (Shong01)           */    
/* 20-Jun-2013  YTWan   1.4   SOS#280047-Replenishment By Group.(Wan01) */
/* 26-Oct-2017  SWT01   1.5   ECOM Replenishment Confirm, Update PD UOM */
/* 12-Jun-2018  Wan02   1.1   WMS-5218 - [CN] UA Relocation Phase II -  */
/*                            Exceed Generate and Confirm Replenishment(B2C)*/
/* 10-Apr-2019  NJOW02  1.2   WMS-8705 - if have replengroup and storer */
/*                            but no replen record, still call post     */
/*                            confirm replen with replengroup only      */
/* 16-Jul-2019  NJOW03  1.3   WMS-8356 support replen by UCC. Update to */
/*                            status 6 for confirm replen.              */
/* 21-Dec-2020  WWANG01 1.4   Update MoveRefKey for ECOM replenishment  */
/************************************************************************/
CREATE PROC  [dbo].[nsp_ConfirmReplenishment]
               @c_Facility         NVARCHAR(10)
,              @c_zone02           NVARCHAR(10)
,              @c_zone03           NVARCHAR(10)
,              @c_zone04           NVARCHAR(10)
,              @c_zone05           NVARCHAR(10)
,              @c_zone06           NVARCHAR(10)
,              @c_zone07           NVARCHAR(10)
,              @c_zone08           NVARCHAR(10)
,              @c_zone09           NVARCHAR(10)
,              @c_zone10           NVARCHAR(10)
,              @c_zone11           NVARCHAR(10)
,              @c_zone12           NVARCHAR(10)
,              @c_storerkey        NVARCHAR(15) = 'ALL'  --NJOW01
,              @c_replgrp          NVARCHAR(10) = 'ALL'  --(Wan01)
,              @b_success          int OUTPUT
,              @n_err              int OUTPUT  
,              @c_errmsg           NVARCHAR(255) OUTPUT 
,              @b_Debug            INT = 0 
AS
BEGIN

   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE        
      @n_continue int          
      /* continuation flag
         1=Continue
         2=failed but continue processsing
         3=failed do not continue processing
         4=successful but skip furthur processing */
      ,@n_starttcnt   int

   DECLARE @ReplenKey           NVARCHAR(10), 
           @Counter             int,
           @cLOC                NVARCHAR(10),
           @cZone               NVARCHAR(10),
           @cLocFacility        NVARCHAR(10), 
           @nQtyInPickLoc       INT = 0 
   
   --NJOW03
   DECLARE @c_EOrderReplenByUCC NVARCHAR(30), 
           @c_RefNo             NVARCHAR(20), 
		   @c_MoveRefKey        NVARCHAR(10),  --WWANG01
           @c_Sku               NVARCHAR(20), 
           @n_UCC_RowRef        BIGINT,    
           @cur_UCC             CURSOR,
           @c_Pickdetailkey     NVARCHAR(10),
           @n_PickQty           INT,
           @n_QtyPickToMove     INT 

--(Wan01) - START
   DECLARE
          @c_SQL           NVARCHAR(MAX)
        , @c_SQLParms      NVARCHAR(MAX)

        , @c_PostReplenCfmSP NVARCHAR(30)

   --(Wan01) - END
   
   SELECT @ReplenKey = ''
   SELECT @c_MoveRefKey = 'E' + RIGHT(@c_replgrp, 9) --WWANG01
   SELECT @counter = 0 
   SELECT @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT

   --WHILE @@TRANCOUNT > 0
   --   COMMIT TRAN

   IF @c_zone02 = 'ALL' 
   BEGIN
      -- (Shong01)
      IF EXISTS(SELECT 1 FROM Replenishment (NOLOCK)
               JOIN   LOC (NOLOCK) ON ( Replenishment.ToLoc = LOC.LOC ) 
               JOIN   StorerConfig (NOLOCK) ON StorerConfig.Storerkey = Replenishment.Storerkey 
                                               AND StorerConfig.ConfigKey = 'TMReplenishmentOnly'
                         AND StorerConfig.SValue = '1' 
               WHERE  Replenishment.Confirmed IN ('N', 'L')
               AND    LOC.Facility = @c_Facility 
               AND    (Replenishment.Storerkey = @c_storerkey OR @c_Storerkey = 'ALL')
               AND    (Replenishment.Replenishmentgroup = @c_replgrp OR @c_replgrp = 'ALL'))  -- (Wan01)                  
      BEGIN
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to post TM Replenishment Only Storer. (nsp_ConfirmReplenishment)' 
                + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         GOTO QUIT_SP
      END
      
      DECLARE ReplenCur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ReplenishmentKey 
      FROM   Replenishment (NOLOCK)
      JOIN   LOC (NOLOCK) ON ( Replenishment.ToLoc = LOC.LOC )
      WHERE  Replenishment.Confirmed IN ('N', 'L')
      AND    LOC.Facility = @c_Facility 
      AND    (Replenishment.Storerkey = @c_storerkey OR @c_Storerkey = 'ALL')  -- NJOW01
      AND    (Replenishment.Replenishmentgroup = @c_replgrp OR @c_replgrp = 'ALL')  -- (Wan01)   
   END
   ELSE
   BEGIN
      -- (Shong01)
      IF EXISTS(SELECT 1 FROM Replenishment (NOLOCK)
               JOIN   LOC (NOLOCK) ON ( Replenishment.ToLoc = LOC.LOC ) 
               JOIN   StorerConfig (NOLOCK) ON StorerConfig.Storerkey = Replenishment.Storerkey 
                                               AND StorerConfig.ConfigKey = 'TMReplenishmentOnly'
                                               AND StorerConfig.SValue = '1' 
               WHERE  Replenishment.Confirmed IN ('N', 'L')
               AND    LOC.Facility = @c_Facility 
               AND    (Replenishment.Storerkey = @c_storerkey OR @c_Storerkey = 'ALL')
               AND    (Replenishment.Replenishmentgroup = @c_replgrp OR @c_replgrp = 'ALL')  -- (Wan01)                 
               AND    LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, 
                                          @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12))
               
      BEGIN
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Not allow to post TM Replenishment Only Storer. (nsp_ConfirmReplenishment)' 
                + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         GOTO QUIT_SP
      END
            
      DECLARE ReplenCur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ReplenishmentKey
      FROM   Replenishment (NOLOCK)
      JOIN   LOC (NOLOCK) ON ( Replenishment.ToLoc = LOC.LOC )
      WHERE  Replenishment.Confirmed IN ('N' ,'L')
      AND    LOC.Facility = @c_Facility 
      AND    LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, 
                                 @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12)
      AND    (Replenishment.Storerkey = @c_storerkey OR @c_Storerkey = 'ALL')  -- NJOW01
      AND    (Replenishment.Replenishmentgroup = @c_replgrp OR @c_replgrp = 'ALL')  -- (Wan01)   
   END
   
   OPEN ReplenCur 

   FETCH NEXT FROM ReplenCur INTO @ReplenKey 

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- SWT01
      SET @nQtyInPickLoc = 0 
      SELECT @nQtyInPickLoc = r.QtyInPickLoc
            ,@c_Storerkey   = r.Storerkey          --(Wan01)
            ,@c_RefNo = r.RefNo --NJOW03
            ,@C_sKU = r.Sku --NJOW03
      FROM REPLENISHMENT AS r WITH(NOLOCK) 
      WHERE r.ReplenishmentKey = @ReplenKey 
   	
      --NJOW03 S
      SET @b_success = 0
      SET @c_EOrderReplenByUCC = ''
      EXECUTE nspGetRight
               @c_facility                -- facility
            ,  @c_Storerkey               -- Storerkey
            ,  ''                         -- Sku
            ,  'EOrderReplenByUCC'          -- Configkey
            ,  @b_success           OUTPUT
            ,  @c_EOrderReplenByUCC OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 61910
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (nsp_ConfirmReplenishment)'
         BREAK      
      END
            
      IF @c_EOrderReplenByUCC = '1' AND ISNULL(RTRIM(@c_replgrp),'') NOT IN('','ALL')        
      BEGIN
      	IF EXISTS(SELECT 1 FROM PackTask AS pt WITH(NOLOCK)
                    WHERE pt.ReplenishmentGroup = @c_replgrp)
        BEGIN            
      	   SET @n_QtyPickToMove = 0
      	   
           SELECT @n_QtyPickToMove = R.Qty - (LLI.Qty - (QtyAllocated + QtyPicked)) 
           FROM REPLENISHMENT  R(NOLOCK)
           JOIN LOTXLOCXID LLI (NOLOCK) ON R.Lot = LLI.Lot AND R.FromLoc = LLI.Loc AND R.Id = LLI.Id
           WHERE R.Replenishmentkey = @Replenkey
           AND LLI.Qty - (QtyAllocated + QtyPicked) < R.Qty
                     
           IF @n_QtyPickToMove > 0
           BEGIN
              DECLARE cur_MovePick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                 SELECT PD.Pickdetailkey, PD.Qty
                 FROM PICKDETAIL PD (NOLOCK)
                 JOIN REPLENISHMENT R (NOLOCK) ON PD.Lot = R.Lot AND PD.Loc = R.FromLoc AND PD.Id = R.ID
                 LEFT JOIN UCC (NOLOCK) ON PD.DropId = UCC.UCCNo AND PD.Lot = UCC.Lot AND PD.Loc = UCC.Loc AND PD.Id = UCC.ID
                 WHERE PD.Status < '5'              
                 AND R.Replenishmentkey = @Replenkey
                 AND UCC.UCCNO IS NULL
                 ORDER BY CASE WHEN PD.UOM IN ('6','7') THEN 1 ELSE 2 END, PD.Qty 
           
              OPEN cur_MovePick
              
              FETCH FROM cur_MovePick INTO @c_Pickdetailkey, @n_PickQty 
           
              WHILE @@FETCH_STATUS = 0 AND @n_QtyPickToMove > 0
              BEGIN
                  BEGIN TRAN
                  	
              	  UPDATE PICKDETAIL WITH (ROWLOCK)
              	  SET MoveRefKey = @c_MoveRefKey, --WWANG01
              	      TrafficCop = NULL
              	  WHERE Pickdetailkey = @c_Pickdetailkey

                  IF @@ERROR <> 0 
                  BEGIN
                     IF @@TRANCOUNT > 0 
                        ROLLBACK TRAN
                        
                     SELECT @n_continue = 3 
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Pickdetail Fail. (nsp_ConfirmReplenishment)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                     BREAK 
                  END 
                  ELSE
                  BEGIN
                     IF @@TRANCOUNT > 0 
                        COMMIT TRAN
                  END
           
              	  IF @n_QtyPickToMove >= @n_PickQty           	     
              	     SET @n_QtyPickToMove = @n_QtyPickToMove - @n_PickQty
              	  ELSE
              	     SET @n_QtyPickToMove = 0
           
                 FETCH FROM cur_MovePick INTO @c_Pickdetailkey, @n_PickQty            	
              END
              CLOSE cur_MovePick
              DEALLOCATE cur_MovePick
              
              IF @n_continue IN(1,2)
              BEGIN
                 BEGIN TRAN
                 UPDATE Replenishment WITH (ROWLOCK) 
                 SET MoveRefKey = @c_MoveRefKey, --WWANG01
                     ArchiveCop = NULL
                 WHERE ReplenishmentKey = @ReplenKey
                 AND   Confirmed IN ('N', 'L')            
                 
                 IF @@ERROR <> 0 
                 BEGIN
                    IF @@TRANCOUNT > 0 
                       ROLLBACK TRAN
                       
                    SELECT @n_continue = 3 
                    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Replenishment Fail. (nsp_ConfirmReplenishment)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
                    BREAK 
                 END 
                 ELSE
                 BEGIN
                    IF @@TRANCOUNT > 0 
                       COMMIT TRAN
                 END
              END
           END
        END   
      END   	  
      --NJOW03 E
   	  
      BEGIN TRAN

      UPDATE Replenishment WITH (ROWLOCK) 
         SET Confirmed = 'Y'
      WHERE ReplenishmentKey = @ReplenKey
      AND   Confirmed IN ('N', 'L') 
   
      IF @@ERROR <> 0 
      BEGIN
         IF @@TRANCOUNT > 0 
            ROLLBACK TRAN
            
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Confirm Replenisment Fail. (nsp_ConfirmReplenishment)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
         BREAK 
      END 
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0 
            COMMIT TRAN
      END

      IF @nQtyInPickLoc > 0 AND ISNULL(RTRIM(@c_replgrp),'') <> ''
      BEGIN
         IF EXISTS(SELECT 1 FROM PackTask AS pt WITH(NOLOCK)
                   WHERE pt.ReplenishmentGroup = @c_replgrp )
         BEGIN        
            --BEGIN TRAN
               
            EXEC isp_EOrderReplenConfirm  
               @c_ReplenishmentGroup   = @c_replgrp
              ,@c_ReplenishmentKey     = @ReplenKey
              ,@b_Success = @b_Success OUTPUT
              ,@n_Err = @n_err OUTPUT
              ,@c_Errmsg = @c_errmsg OUTPUT 
              ,@b_Debug  = @b_Debug   

            --IF @@ERROR <> 0 
            --BEGIN
              -- IF @@TRANCOUNT > 0 
            --      ROLLBACK TRAN
            
            --   SELECT @n_continue = 3 
            --   BREAK 
            --END 
            --ELSE
            --BEGIN
              -- IF @@TRANCOUNT > 0 
            --      COMMIT TRAN
            --END                      
         END         
      END

      --NJOW03 S
      IF @c_EOrderReplenByUCC = '1' AND @n_continue IN(1,2)
      BEGIN
          BEGIN TRAN
      	
          UPDATE UCC WITH (ROWLOCK)
          SET Status = '6'
          WHERE UCCNo = @c_RefNo
          AND Storerkey = @c_Storerkey
          AND Sku = @c_Sku
          
          IF @@ERROR <> 0 
          BEGIN
             IF @@TRANCOUNT > 0 
                ROLLBACK TRAN
                
             SELECT @n_continue = 3 
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Confirm Replenisment Fail. (nsp_ConfirmReplenishment)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + ' ) '
             BREAK 
          END 
          ELSE
          BEGIN
             IF @@TRANCOUNT > 0 
                COMMIT TRAN
          END        
      END
      --NJOW03 E

      --(Wan02) - START
      SET @c_PostReplenCfmSP = ''
      SET @b_success = 0
      EXECUTE nspGetRight
               @c_facility                -- facility
            ,  @c_Storerkey               -- Storerkey
            ,  ''                         -- Sku
            ,  'PostReplenCfmSP'          -- Configkey
            ,  @b_success           OUTPUT
            ,  @c_PostReplenCfmSP   OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 61910
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (nsp_ConfirmReplenishment)'
         GOTO QUIT_SP      
      END

      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostReplenCfmSP AND TYPE = 'P')
      BEGIN

         SET @c_SQL = N'EXECUTE ' + @c_PostReplenCfmSP  
                     + '  @c_ReplenishmentGroup = @c_replgrp' 
                     + ', @c_ReplenishmentKey = @ReplenKey'
                     + ', @b_Success    = @b_Success     OUTPUT' 
                     + ', @n_Err        = @n_Err         OUTPUT'  
                     + ', @c_ErrMsg     = @c_ErrMsg      OUTPUT'  

         SET @c_SQLParms= N' @c_replgrp   NVARCHAR(10)'  
                        +  ',@ReplenKey   NVARCHAR(10)'  
                        +  ',@b_Success   INT OUTPUT'
                        +  ',@n_Err       INT OUTPUT'
                        +  ',@c_ErrMsg    NVARCHAR(250) OUTPUT'
                                 
         EXEC sp_ExecuteSQL @c_SQL
                        ,   @c_SQLParms
                        ,   @c_replgrp
                        ,   @ReplenKey
                        ,   @b_Success    OUTPUT
                        ,   @n_Err        OUTPUT
                        ,   @c_ErrMsg     OUTPUT 
  
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 61920    
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostReplenCfmSP 
                           + '.(nsp_ConfirmReplenishment)'
                           + CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END 
            GOTO QUIT_SP                          
         END 
      END
      --(Wan02) - END
   
      FETCH NEXT FROM ReplenCur INTO @ReplenKey 
   END -- While
   CLOSE ReplenCur
   DEALLOCATE ReplenCur 
   
   --NJOW03 S  full case
   IF @c_replgrp <> 'ALL' AND @c_Storerkey <> 'ALL' AND @n_continue IN(1,2)
   BEGIN   	   
      SET @b_success = 0
      SET @c_EOrderReplenByUCC = ''
      EXECUTE nspGetRight
               @c_facility                -- facility
            ,  @c_Storerkey               -- Storerkey
            ,  ''                         -- Sku
            ,  'EOrderReplenByUCC'          -- Configkey
            ,  @b_success           OUTPUT
            ,  @c_EOrderReplenByUCC OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 61910
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (nsp_ConfirmReplenishment)'
         GOTO QUIT_SP      
      END
      
      IF @c_EOrderReplenByUCC = '1'
      BEGIN      	
         SET @cur_UCC = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCC_RowRef  
         FROM   UCC WITH (NOLOCK)
         WHERE  UCC.Status < '6'
         AND    EXISTS( SELECT 1
                        FROM PICKDETAIL PD WITH (NOLOCK)
                        JOIN   PACKTASK   PT WITH (NOLOCK) ON (PD.PickSlipNo = PT.TaskBatchNo)
                                                           AND(PD.Orderkey   = PT.Orderkey)
                        WHERE  PT.ReplenishmentGroup = @c_replgrp
                        AND    PD.UOM = '2'
                        AND    PD.Status < '5'
                        AND    PD.ShipFlag NOT IN ('P','Y') 
                        AND    PD.DropID = UCC.UCCNo
                       )

         OPEN @cur_UCC
         
         FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            BEGIN TRAN
         	
            UPDATE UCC WITH (ROWLOCK)
            SET Status = '6'
               ,EditWho  = SUSER_SNAME()
               ,EditDate = GETDATE()
            WHERE UCC_RowRef = @n_UCC_RowRef

            IF @@ERROR <> 0 
            BEGIN
               IF @@TRANCOUNT > 0 
                  ROLLBACK TRAN
                  
               SET @n_continue = 3
               SET @n_err = 61910
               SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Update UCC Table Fail. (ispPOReplenCfm01)'
               BREAK 
            END 
            ELSE
            BEGIN
               IF @@TRANCOUNT > 0 
                  COMMIT TRAN
            END        
                 
            FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef 
         END
         CLOSE @cur_UCC
         DEALLOCATE @cur_UCC       	
      END   	
   END
   --NJOW03 E
   
   --NJOW02
   IF @c_replgrp <> 'ALL' AND @c_Storerkey <> 'ALL' AND ISNULL(@ReplenKey,'') = '' 
   BEGIN   	
      SET @c_PostReplenCfmSP = ''
      SET @b_success = 0
      EXECUTE nspGetRight
               @c_facility                -- facility
            ,  @c_Storerkey               -- Storerkey
            ,  ''                         -- Sku
            ,  'PostReplenCfmSP'          -- Configkey
            ,  @b_success           OUTPUT
            ,  @c_PostReplenCfmSP   OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 61910
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight Failed! (nsp_ConfirmReplenishment)'
         GOTO QUIT_SP      
      END   	   	

      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostReplenCfmSP AND TYPE = 'P')
      BEGIN

         SET @c_SQL = N'EXECUTE ' + @c_PostReplenCfmSP  
                     + '  @c_ReplenishmentGroup = @c_replgrp' 
                     + ', @c_ReplenishmentKey = @ReplenKey'
                     + ', @b_Success    = @b_Success     OUTPUT' 
                     + ', @n_Err        = @n_Err         OUTPUT'  
                     + ', @c_ErrMsg     = @c_ErrMsg      OUTPUT'  

         SET @c_SQLParms= N' @c_replgrp   NVARCHAR(10)'  
                        +  ',@ReplenKey   NVARCHAR(10)'  
                        +  ',@b_Success   INT OUTPUT'
                        +  ',@n_Err       INT OUTPUT'
                        +  ',@c_ErrMsg    NVARCHAR(250) OUTPUT'
                                 
         EXEC sp_ExecuteSQL @c_SQL
                        ,   @c_SQLParms
                        ,   @c_replgrp
                        ,   @ReplenKey
                        ,   @b_Success    OUTPUT
                        ,   @n_Err        OUTPUT
                        ,   @c_ErrMsg     OUTPUT 
  
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
            SET @n_Err     = 61920    
            SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC ' + @c_PostReplenCfmSP 
                           + '.(nsp_ConfirmReplenishment)'
                           + CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END 
            GOTO QUIT_SP                          
         END 
      END      
   END 

   --(Shong01)
   QUIT_SP:
   WHILE @@TRANCOUNT < @n_starttcnt
      COMMIT TRAN
   
   IF @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN
    
      
END -- Procedure

GO