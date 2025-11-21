SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: ispRLKIT02                                          */  
/* Creation Date: 23-Apr-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8402 CN Nivea Kitting allocate and release replen        */
/*                                                                       */  
/* Called By: Kitting RCM Release pick task                              */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLKIT02]      
  @c_kitkey       NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_err          int        OUTPUT  
 ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_continue int,    
            @n_starttcnt int,         -- Holds the current transaction count  
            @n_debug int,
            @n_cnt int
                
    SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
    SELECT  @n_debug = 0

    DECLARE @c_Storerkey        NVARCHAR(15), 
            @c_Sku              NVARCHAR(20), 
            @c_Lot              NVARCHAR(10),
            @c_Loc              NVARCHAR(10), 
            @c_ID               NVARCHAR(18), 
            @c_ToLoc            NVARCHAR(10), 
            @c_Packkey          NVARCHAR(10),
            @c_UOM              NVARCHAR(10),
            @n_Qty              INT,
            @n_ShortQty         INT,
            @n_RequireQty       INT,
            @c_SourceType       NVARCHAR(30),    
            @c_Priority         NVARCHAR(10),
            @c_ReplenishmentKey NVARCHAR(10),
            @c_kitLineNumber    NVARCHAR(5),
            @c_LocationType     NVARCHAR(10),
            @n_Casecnt          INT,
            @n_FullPackQty      INT,
            @n_QtyAvailable     INT,
            @n_RoundUpQty       INT,
            @c_FinalLoc         NVARCHAR(10),
            @c_Lottable01       NVARCHAR(18),    
            @c_Lottable02       NVARCHAR(18),    
            @c_Lottable03       NVARCHAR(18),    
            @d_Lottable04       DATETIME,    
            @d_Lottable05       DATETIME,  
            @c_Lottable06       NVARCHAR(30),       
            @c_Lottable07       NVARCHAR(30),       
            @c_Lottable08       NVARCHAR(30),       
            @c_Lottable09       NVARCHAR(30),       
            @c_Lottable10       NVARCHAR(30),       
            @c_Lottable11       NVARCHAR(30),       
            @c_Lottable12       NVARCHAR(30),       
            @d_Lottable13       DATETIME,     
            @d_Lottable14       DATETIME,     
            @d_Lottable15       DATETIME    
                                        
    SET @c_SourceType = 'ispRLKIT02'    
    SET @c_Priority = '1'

    -----Kit Validation-----                 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
        IF EXISTS (SELECT 1 FROM REPLENISHMENT R (NOLOCK) 
                   WHERE R.ReplenishmentGroup = @c_Kitkey
                   AND R.OriginalFromLoc = @c_SourceType)
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 83010    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Kit has beed released. (ispRLKIT02)'       
           GOTO RETURN_SP
        END                 

        IF NOT EXISTS (SELECT 1 FROM KITDETAIL KD (NOLOCK) 
                        WHERE KD.KITKey = @c_Kitkey
                        AND (KD.Lot = '' OR KD.Lot IS NULL)
                        AND KD.Type = 'F')
        BEGIN
           SELECT @n_continue = 3  
           SELECT @n_err = 83020    
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Kit has nothing to allocate/release. (ispRLKIT02)'       
           GOTO RETURN_SP
        END              

    	 SET @c_Toloc = ''
    	                                          
    	 SELECT @c_ToLoc = CL.Code  
    	 FROM CODELKUP CL (NOLOCK)
    	 JOIN LOC (NOLOCK) ON CL.Code = LOC.Loc
    	 WHERE CL.Listname = 'NVALOC'
    	 AND CL.Short = 'STAGE'
    	     	 
    	 IF ISNULL(@c_Toloc,'') = ''
    	 BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 83030    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid to location setup at listname NVALOC. (ispRLKIT02)'           	 	
          GOTO RETURN_SP
    	 END         
    	 
    	 SELECT @c_FinalLoc  = F.Userdefine04
    	 FROM KIT  K (NOLOCK)
    	 JOIN FACILITY F (NOLOCK) ON K.Facility = F.Facility
    	 WHERE K.Kitkey = @c_Kitkey
    	 

    	 IF ISNULL(@c_Finalloc,'') = ''
    	 BEGIN
          SELECT @n_continue = 3  
          SELECT @n_err = 830345    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid to Final location setup at facility.userdefine04. (ispRLKIT02)'           	 	
          GOTO RETURN_SP
    	 END               	     	 
    END

    IF @@TRANCOUNT = 0
       BEGIN TRAN
       	

    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       SELECT TOP 1 @c_Lottable01 = Lottable01
                   ,@c_Lottable02 = Lottable02
                   ,@c_Lottable03 = Lottable03
                   ,@d_Lottable04 = Lottable04
                   ,@d_Lottable05 = Lottable05
                   ,@c_Lottable06 = Lottable06
                   ,@c_Lottable07 = Lottable07
                   ,@c_Lottable08 = Lottable08
                   ,@c_Lottable09 = Lottable09
                   ,@c_Lottable10 = Lottable10
                   ,@c_Lottable11 = Lottable11
                   ,@c_Lottable12 = Lottable12
                   ,@d_Lottable13 = Lottable13
                   ,@d_Lottable14 = Lottable14
                   ,@d_Lottable15 = Lottable15       
       FROM KITDETAIL (NOLOCK)
       WHERE Kitkey = @c_KitKey
       AND Type = 'T'              
       
       DECLARE CUR_KITDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT KD.KITLineNumber
          FROM KIT K (NOLOCK)
          JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
          WHERE K.Kitkey = @c_KitKey
          AND KD.Type = 'F'
          AND ISNULL(KD.Lot,'') = ''
          ORDER BY KD.KitLineNumber

       OPEN CUR_KITDET  
       
       FETCH NEXT FROM CUR_KITDET INTO @c_kitLineNumber
                     
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  UPDATE KITDETAIL WITH (ROWLOCK)
       	  SET Lottable01 = @c_Lottable01,
       	      Lottable02 = @c_Lottable02,
       	      Lottable03 = @c_Lottable03,
       	      Lottable04 = NULL, --@d_Lottable04
       	      Lottable05 = NULL, --@d_Lottable05
       	      Lottable06 = @c_Lottable06,
       	      Lottable07 = @c_Lottable07,
       	      Lottable08 = @c_Lottable08,
       	      Lottable09 = @c_Lottable09,
       	      Lottable10 = @c_Lottable10,
       	      Lottable11 = @c_Lottable11,
       	      Lottable12 = @c_Lottable12,
       	      Lottable13 = @d_Lottable13,
       	      Lottable14 = @d_Lottable14,
       	      Lottable15 = @d_Lottable15
       	  WHERE Kitkey = @c_KItKey
       	  AND KitLineNumber = @c_KitLineNumber
       	  AND Type = 'F'

          SELECT @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83047
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Kitdetail Failed. (ispRLKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          END   
       	  
          FETCH NEXT FROM CUR_KITDET INTO @c_kitLineNumber
       END  
       CLOSE CUR_KITDET
       DEALLOCATE CUR_KITDET                         
    END    
          
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	  
       EXEC isp_Kit_Allocation  
           @c_KitKey              = @c_Kitkey
          ,@c_AllocateStrategykey = 'NEVIAKIT'              
          ,@b_Success             = @b_Success OUTPUT
          ,@n_err                 = @n_err     OUTPUT
          ,@c_errmsg              = @c_errmsg  OUTPUT    
                
       IF @b_Success <> 1  
       BEGIN  
          SELECT @n_continue = 3  
       END 
       ELSE
       BEGIN
       	  SET @c_Sku = ''
       	  
       	  SELECT TOP 1 @c_Sku = SKU, 
       	               @n_ShortQty = SUM(CASE WHEN ISNULL(Lot,'') = '' THEN ExpectedQty ELSE 0 END),
       	               @n_RequireQty = SUM(ExpectedQty)
          FROM KITDETAIL (NOLOCK)
          WHERE Kitkey = @c_Kitkey
          AND Type = 'F'
          AND EXISTS (SELECT 1 FROM KITDETAIL KD (NOLOCK) 
                      WHERE ISNULL(KD.Lot, '') = ''
                      AND KD.Kitkey = KITDETAIL.Kitkey
                      AND KD.Storerkey = KITDETAIL.Storerkey
                      AND KD.Sku = KITDETAIL.Sku
                      AND KD.Type = 'F')
          GROUP BY Sku            
          ORDER BY Sku
          
          IF ISNULL(@c_Sku,'') <> ''
          BEGIN
             SELECT @n_continue = 3  
             SELECT @n_err = 83040    
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. The Sku ''' +  RTRIM(@c_Sku) + ''' has insufficient stock. Require Qty: ' + RTRIM(CAST(@n_RequireQty AS NVARCHAR)) +  
              ' Short Qty: ' +  RTRIM(CAST(@n_ShortQty AS NVARCHAR)) + ' (ispRLKIT02)'       
          END
       END       
    END                    

    --Generete replenishment records for the kit 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	     	 
       DECLARE CUR_KIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
          SELECT KD.Storerkey, KD.Sku, KD.Lot, KD.Loc, KD.ID, SUM(KD.ExpectedQty),PACK.Packkey, PACK.PackUOM3, MAX(KD.KitLineNumber), ISNULL(SL.LocationType,''), PACK.Casecnt 
          FROM KIT K (NOLOCK)
          JOIN KITDETAIL KD (NOLOCK) ON K.KITKey = KD.KITKey
          JOIN SKU (NOLOCK) ON KD.Storerkey = SKU.Storerkey AND KD.Sku = SKU.Sku
          JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
          LEFT JOIN SKUXLOC SL (NOLOCK) ON SKU.Storerkey = SL.Storerkey AND SKU.Sku = SL.Sku AND KD.Loc = SL.Loc
          WHERE K.Kitkey = @c_KitKey
          AND KD.Type = 'F'
          GROUP BY KD.Storerkey, KD.Sku, KD.Lot, KD.Loc, KD.ID, PACK.Packkey, PACK.PackUOM3, ISNULL(SL.LocationType,''), PACK.Casecnt 
       
       OPEN CUR_KIT  
       
       FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty, @c_Packkey, @c_UOM, @c_KitLineNumber, @c_LocationType, @n_Casecnt
                     
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
       BEGIN
       	  --Round up to full carton if get from bulk       	
       	  IF @c_LocationType NOT IN ('PICK','CASE') AND @n_Casecnt > 0
       	  BEGIN
       	  	  SET @n_FullPackQty = CEILING(@n_Qty / (@n_Casecnt * 1.00)) * @n_Casecnt
       	  	  SET @n_RoundUpQty = @n_FullPackQty - @n_Qty 
       	  	  
              SELECT @n_QtyAvailable = SUM(Qty - QtyAllocated - QtyPicked - QtyReplen) 
              FROM LOTXLOCXID (NOLOCK)           
              WHERE Storerkey = @c_Storerkey
              AND Sku = @c_Sku
              AND Lot = @c_Lot 
              AND Loc = @c_Loc
              AND ID = @c_ID      		
              
              IF (@n_QtyAvailable - @n_Qty) >= @n_RoundUpQty
              BEGIN
                 SET @n_Qty = @n_FullPackQty              
              END       	  	
       	  END
       	
          EXECUTE nspg_getkey
             'REPLENISHKEY'
             , 10
             , @c_ReplenishmentKey OUTPUT
             , @b_success OUTPUT
             , @n_err OUTPUT
             , @c_errmsg OUTPUT
          
          IF NOT @b_success = 1
          BEGIN
             SELECT @n_continue = 3
          END

          INSERT INTO REPLENISHMENT (ReplenishmentKey, ReplenishmentGroup,
                         StorerKey,      SKU,         FromLOC,         ToLOC,
                         Lot,            Id,          Qty,             UOM,
                         PackKey,        Priority,    QtyMoved,        QtyInPickLOC,
                         RefNo,          Confirmed,   ReplenNo,        Wavekey,
                         Remark,         OriginalQty, OriginalFromLoc, ToID,
                         PendingMoveIn,	 QtyReplen)
                     VALUES (
                         @c_ReplenishmentKey,         @c_KitKey,
                         @c_StorerKey,   @c_Sku,      @c_Loc,          @c_ToLoc,
                         @c_Lot,         @c_Id,       @n_Qty,          @c_UOM,
                         @c_Packkey,     @c_Priority, 0,               0,
                         @c_Kitkey,      'N',         @c_KitLineNumber,	'',
                         '',    				 @n_Qty,      @c_SourceType,    '',
                         0,							 @n_Qty)
          
          SELECT @n_err = @@ERROR
          
          IF @n_err <> 0
          BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Replenishment Failed. (ispRLKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          END   
       
          FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Sku, @c_Lot, @c_Loc, @c_ID, @n_Qty, @c_Packkey, @c_UOM, @c_KitLineNumber, @c_LocationType, @n_Casecnt
       END           
       CLOSE CUR_KIT
       DEALLOCATE CUR_KIT       
    END

    --Update kit from loc to the stage
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	     	
    	 UPDATE KITDETAIL WITH (ROWLOCK) 
    	 SET Loc = @c_Toloc,
    	     ID = '',
    	     Qty = ExpectedQty,
    	     TrafficCop = NULL
    	 WHERE Kitkey = @c_KitKey
       AND Type = 'F'

       SELECT @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Kitdetail Failed. (ispRLKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
       END       
    END     

    --Update kit to loc to the final loc
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN    	     	
    	 SET @d_Lottable04 = NULL
    	 
    	 SELECT TOP 1 @d_Lottable04 = KF.Lottable04
    	 FROM KITDETAIL KF (NOLOCK)
    	 JOIN KITDETAIL KT (NOLOCK) ON KF.KITKey = KT.KITKey AND KF.LOTTABLE02 = KT.LOTTABLE02
    	 WHERE KT.KITKey = @c_Kitkey
    	 AND KF.Type = 'F'
    	 AND KT.Type = 'T'
    	 AND KT.Lottable02 IS NOT NULL 
    	 AND KT.Lottable02 <> ''
    	 ORDER BY KF.Lottable04 DESC    	 
    	
    	 UPDATE KITDETAIL WITH (ROWLOCK) 
    	 SET Loc = @c_Finalloc,
    	     Lottable04 = CASE WHEN ISNULL(@d_Lottable04,'19000101') <> '19000101' THEN @d_Lottable04 ELSE Lottable04 END,
    	     Lottable05 = GETDATE(),
    	     Qty = ExpectedQty,    	     
    	     TrafficCop = NULL
    	 WHERE Kitkey = @c_KitKey
       AND Type = 'T'

       SELECT @n_err = @@ERROR
       
       IF @n_err <> 0
       BEGIN
           SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83070
           SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Kitdetail Failed. (ispRLKIT02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
       END       
    END     
               
RETURN_SP:
    
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
       execute nsp_logerror @n_err, @c_errmsg, "ispRLKIT02"  
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