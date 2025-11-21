SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nsp_ReplenishmentRpt_RF03                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:                                                             */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Ver.  Author     Purposes                               */  
/* 24-08-2009   1.0   PHLee      Create                                 */  
/* 23-02-2010   2.0   Shong      SOS163044 - Progrom bug                */
/************************************************************************/  
CREATE PROC    [dbo].[nsp_ReplenishmentRpt_RF03]  
                @c_zone01           NVARCHAR(10)   
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
 AS  
BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    DECLARE @n_continue  INT /* continuation flag   
    1=Continue  
    2=failed but continue processsing   
    3=failed do not continue processing   
    4=successful but skip furthur processing */  
    DECLARE @b_debug     INT  
           ,@c_Packkey   NVARCHAR(10)  
           ,@c_Facility  NVARCHAR(5)  
           ,@c_UOM       NVARCHAR(5)  
      
    SELECT @n_continue = 1  
          ,@b_debug = 0  
      
    IF @c_zone12<>''  
        SELECT @b_debug = CAST(@c_zone12 AS INT)  
      
    DECLARE @c_priority NVARCHAR(5)  
    SELECT LLI.StorerKey  
          ,LLI.Sku  
          ,LLI.Loc FromLoc  
          ,LLI.Loc ToLoc  
          ,LLI.Lot  
          ,LLI.Id  
          ,LLI.Qty  
          ,LLI.Qty QtyMoved  
          ,LLI.Qty QtyInPickLoc  
          ,@c_priority Priority  
          ,LLI.Lot UOM  
          ,LLI.Lot PackKey  
          ,L.Facility  
           INTO #REPLENISHMENT  
    FROM   LOTXLOCXID LLI(NOLOCK)  
           JOIN LOC L  
                ON  (LLI.LOC=L.LOC)  
    WHERE  1 = 2  
      
    IF @n_continue=1 OR  
       @n_continue=2  
    BEGIN  
        DECLARE @c_currentsku                  NVARCHAR(20)  
               ,@c_currentstorer               NVARCHAR(15)  
               ,@c_currentloc                  NVARCHAR(10)  
               ,@c_currentpriority             NVARCHAR(5)  
               ,@n_currentfullcase             INT  
               ,@n_currentseverity             INT  
               ,@c_fromloc                     NVARCHAR(10)  
               ,@c_fromlot                     NVARCHAR(10)  
               ,@c_fromid                      NVARCHAR(18)  
               ,@n_fromqty                     INT  
               ,@n_remainingqty                INT  
               ,@n_possiblecases               INT  
               ,@n_remainingcases              INT  
       ,@n_OnHandQty                   INT  
               ,@n_fromcases                   INT  
               ,@c_ReplenishmentKey            NVARCHAR(10)  
               ,@n_numberofrecs                INT  
               ,@n_limitrecs                   INT  
               ,@c_fromlot2                    NVARCHAR(10)  
               ,@b_donecheckoverallocatedlots  INT  
               ,@n_skulocavailableqty          INT  
          
        SELECT @c_currentsku = SPACE(20)  
              ,@c_currentstorer = SPACE(15)  
              ,@c_currentloc = SPACE(10)  
              ,@c_currentpriority = SPACE(5)  
              ,@n_currentfullcase = 0  
              ,@n_currentseverity = 9999999  
              ,@n_fromqty = 0  
              ,@n_remainingqty = 0  
              ,@n_possiblecases = 0  
              ,@n_remainingcases = 0  
              ,@n_fromcases = 0  
              ,@n_numberofrecs = 0  
              ,@n_limitrecs = 5  
        /* Make a temp version of skuxloc */  
        SELECT SL.REPLENISHMENTPRIORITY  
              ,SL.REPLENISHMENTSEVERITY  
              ,SL.STORERKEY  
              ,SL.SKU  
              ,SL.LOC  
              ,SL.REPLENISHMENTCASECNT  
              ,L.Facility  
               INTO #tempskuxloc  
        FROM   SKUxLOC SL(NOLOCK)  
               JOIN LOC L  
                    ON  (SL.LOC=L.LOC)  
        WHERE  1 = 2  
          
        IF (@c_zone02='ALL')  --SOS163044 : change from zone01 to zone02
        BEGIN  
            INSERT #tempskuxloc  
            SELECT SL.replenishmentpriority  
                  ,SL.replenishmentseverity  
                  ,SL.storerkey  
                  ,SL.sku  
                  ,SL.loc  
                  ,SL.replenishmentcasecnt  
                  ,L.Facility  
            FROM   SKUxLOC SL(NOLOCK)  
                   JOIN LOC L  
                        ON  (SL.LOC=L.LOC)  
            WHERE  (SL.locationtype="PICK" OR SL.locationtype="CASE") AND  
                   SL.replenishmentseverity>0 AND  
                   SL.qty- SL.qtypicked- SL.QtyPickInProcess<SL.QtyLocationMinimum AND  
                   L.Facility = @c_zone01   
        END  
        ELSE  
        BEGIN  
            INSERT #tempskuxloc  
            SELECT replenishmentpriority  
                  ,replenishmentseverity  
                  ,storerkey  
                  ,sku  
                  ,loc.loc  
                  ,replenishmentcasecnt  
                  ,loc.Facility  
            FROM   SKUxLOC(NOLOCK)  
                  ,LOC(NOLOCK)  
            WHERE  SKUxLOC.LOC = LOC.LOC AND  
                   LOC.putawayzone IN (@c_zone02  
                                      ,@c_zone03  
                                      ,@c_zone04  
                                      ,@c_zone05  
                                      ,@c_zone06  
                                      ,@c_zone07  
                                      ,@c_zone08  
                                      ,@c_zone09  
                                      ,@c_zone10  
                                      ,@c_zone11  
                                      ,@c_zone12) AND  
                   LOC.Locationflag<>"DAMAGE" AND  
                   LOC.Locationflag<>"HOLD" AND  
                   (skuxloc.locationtype="PICK" OR skuxloc.locationtype="CASE") AND  
                   replenishmentseverity>0 AND  
                   skuxloc.qty- skuxloc.qtypicked- SKUxLOC.QtyPickInProcess<  
                   skuxloc.QtyLocationMinimum AND   
                   LOC.Facility = @c_zone01   
        END  
        -- Added By SHONG  
        -- Date: 16th JUL 2001  
        -- Purpose: To Speed up the process  
        -- Remove all the rows that got not inventory to replenish  
        DECLARE @c_StorerKey  NVARCHAR(18)  
               ,@c_SKU        NVARCHAR(20)  
               ,@c_LOC        NVARCHAR(10)  
          
        DECLARE CUR1         CURSOR FAST_FORWARD READ_ONLY   
        FOR  
            SELECT StorerKey  
                  ,SKU         
                  ,LOC         
                  ,Facility    
            FROM   #tempskuxloc  
            ORDER BY  
                   StorerKey  
                  ,SKU         
                  ,LOC         
          
        OPEN CUR1  
        FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_SKU, @c_LOC, @c_Facility                               
        WHILE @@FETCH_STATUS<>-1  
        BEGIN  
            IF NOT EXISTS(  
                   SELECT 1  
                   FROM   SKUxLOC(NOLOCK)  
                         ,LOC(NOLOCK)  
                   WHERE  StorerKey = @c_StorerKey AND  
                          SKU = @c_SKU AND  
                          SKUxLOC.LOC<>@c_LOC AND  
                          LOC.LOC = SKUxLOC.LOC AND  
                          LOC.Facility=@c_Facility AND  --SOS163044 : change from '<>' to '='
                          LOC.Locationflag<>"DAMAGE" AND  
                          LOC.Locationflag<>"HOLD" AND  
                          SKUxLOC.Qty- QtyPicked- QtyAllocated>0  
               )  
            BEGIN  
                DELETE #tempskuxloc  
                WHERE  Storerkey = @c_StorerKey AND  
                       SKU = @c_SKU  
            END  
              
            FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_SKU, @c_LOC, @c_Facility  
        END  
        DEALLOCATE CUR1  
          
        WHILE (1=1)  
        BEGIN  
            IF @c_zone02="ALL"  --SOS163044 : change from zone01 to zone02
            BEGIN  
                SET ROWCOUNT 1  
                SELECT @c_currentpriority = replenishmentpriority  
                FROM   #tempskuxloc  
                WHERE  replenishmentpriority>@c_currentpriority AND  
                       replenishmentcasecnt>0  
                ORDER BY  
                       replenishmentpriority  
            END  
            ELSE  
            BEGIN  
                SET ROWCOUNT 1  
                SELECT @c_currentpriority = replenishmentpriority  
                FROM   #tempskuxloc  
                WHERE  replenishmentpriority>@c_currentpriority AND  
                       replenishmentcasecnt>0  
                ORDER BY  
                       replenishmentpriority  
            END  
            IF @@ROWCOUNT=0  
            BEGIN  
                SET ROWCOUNT 0  
                BREAK  
            END  
              
            SET ROWCOUNT 0  
            /* Loop through skuxloc for the currentsku, current storer */  
            /* to pickup the next severity */  
            SELECT @n_currentseverity = 999999999                 
            WHILE (1=1)  
            BEGIN  
                SET ROWCOUNT 1  
                SELECT @n_currentseverity = replenishmentseverity  
                FROM   #tempskuxloc  
                WHERE  replenishmentseverity<@n_currentseverity AND  
                       replenishmentpriority = @c_currentpriority AND  
                       replenishmentcasecnt>0  
                ORDER BY  
                       replenishmentseverity DESC  
                  
                IF @@ROWCOUNT=0  
                BEGIN  
                    SET ROWCOUNT 0  
                    BREAK  
                END  
                  
                SET ROWCOUNT 0  
                /* Now - for this priority, this severity - find the next storer row */  
                /* that matches */  
                SELECT @c_currentsku = SPACE(20)  
                      ,@c_currentstorer = SPACE(15)  
                      ,@c_currentloc = SPACE(10)  
                  
                WHILE (1=1)  
                BEGIN  
                    SET ROWCOUNT 1  
                    SELECT @c_currentstorer = storerkey  
                          ,@c_Facility = Facility  
                    FROM   #tempskuxloc  
                    WHERE  storerkey>@c_currentstorer AND  
                           replenishmentseverity = @n_currentseverity AND  
                           replenishmentpriority = @c_currentpriority  
                    ORDER BY  
                           Storerkey  
                      
                    IF @@ROWCOUNT=0  
                    BEGIN  
                        SET ROWCOUNT 0  
                        BREAK  
 END  
                      
                    SET ROWCOUNT 0  
                    /* Now - for this priority, this severity - find the next sku row */  
                    /* that matches */  
                    SELECT @c_currentsku = SPACE(20)  
                          ,@c_currentloc = SPACE(10)  
                      
                    WHILE (1=1)  
                    BEGIN  
                        SET ROWCOUNT 1  
                        SELECT @c_currentstorer = storerkey  
                              ,@c_currentsku = sku  
                              ,@c_currentloc = loc  
                              ,@n_currentfullcase = replenishmentcasecnt  
                        FROM   #tempskuxloc  
                        WHERE  sku>@c_currentsku AND  
                               storerkey = @c_currentstorer AND  
                               Facility = @c_Facility AND  
                               replenishmentseverity = @n_currentseverity AND  
                               replenishmentpriority = @c_currentpriority  
                        ORDER BY  
                               sku  
                          
                        IF @@ROWCOUNT=0  
                        BEGIN  
                            SET ROWCOUNT 0  
                            BREAK  
                        END  
                          
                        SET ROWCOUNT 0  
                        /* We now have a picklocation that needs to be replenished! */  
                        /* Figure out which locations in the warehouse to pull this product from */  
                        /* End figure out which locations in the warehouse to pull this product from */                                
                        SELECT @c_fromloc = SPACE(10)  
                              ,@c_fromlot = SPACE(10)  
                              ,@c_fromid = SPACE(18)  
                              ,@n_fromqty = 0  
                              ,@n_possiblecases = 0  
                              ,@n_remainingqty = @n_currentseverity*@n_currentfullcase  
                              ,@n_remainingcases = @n_currentseverity  
                              ,@c_fromlot2 = SPACE(10)  
                              ,@b_donecheckoverallocatedlots = 0  
                          
                        WHILE (1=1)  
                        BEGIN  
                            /* See if there are any lots where the QTY is overallocated... */  
                            /* if Yes then uses this lot first... */  
                            -- That means that the last try at this section of code was successful therefore try again.  
                            IF @b_donecheckoverallocatedlots=0  
                            BEGIN  
                                IF @c_zone02="ALL"   --SOS163044 : change from zone01 to zone02
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromlot2 = LOTxLOCxID.LOT  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                          ,LOTATTRIBUTE(NOLOCK)  
                                    WHERE  LOTxLOCxID.LOT>@c_fromlot2 AND  
                                           LOTxLOCxID.storerkey = @c_currentstorer AND  
                                           LOTxLOCxID.sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qtyexpected>0 AND  
                                           LOTxLOCxID.loc = @c_currentloc AND  
                                           LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND   
                                           LOC.Facility = @c_zone01   
         ORDER BY  
                                           LOTTABLE04  
                                          ,LOTTABLE05  
                                END  
                                ELSE  
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromlot2 = LOTxLOCxID.LOT  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                          ,LOTATTRIBUTE(NOLOCK)  
                                    WHERE  LOTxLOCxID.LOT>@c_fromlot2 AND  
                                           LOTxLOCxID.storerkey = @c_currentstorer AND  
                                           LOTxLOCxID.sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qtyexpected>0 AND  
                                           LOTxLOCxID.loc = @c_currentloc AND  
                                           LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND   
                                           LOC.Facility = @c_zone01   
                                    ORDER BY  
                                           LOTTABLE04  
                                          ,LOTTABLE05  
                                END       
                                IF @@ROWCOUNT=0  
                                BEGIN  
                                    SELECT @b_donecheckoverallocatedlots = 1  
                                    SELECT @c_fromlot = ""  
                                END  
                                ELSE  
                                    SELECT @b_donecheckoverallocatedlots = 1  
                            END --IF @b_donecheckoverallocatedlots = 0  
                            /* End see if there are any lots where the QTY is overallocated... */  
                            SET ROWCOUNT 0  
                            /* If there are not lots overallocated in the candidate location, simply pull lots into the location by lot # */  
                            IF @b_donecheckoverallocatedlots=1  
                            BEGIN  
                                /* Select any lot if no lot was over allocated */        
                                IF @c_zone02="ALL"  --SOS163044 : change from zone01 to zone02
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromlot = LOTxLOCxID.LOT  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                          ,LOTATTRIBUTE(NOLOCK)  
                                    WHERE  LOTxLOCxID.LOT>@c_fromlot AND  
                                           LOTxLOCxID.storerkey = @c_currentstorer AND  
                                           LOTxLOCxID.sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qty- qtypicked-   
                                           qtyallocated>0 AND  
                                           LOTxLOCxID.qtyexpected = 0 AND  
                                           LOTxLOCxID.loc<>@c_currentloc AND  
                                           LOTATTRIBUTE.LOT = LOTxLOCxID.LOT AND   
                                           LOC.Facility = @c_zone01   
                                    ORDER BY  
                                           LOTTABLE04  
                                     ,LOTTABLE05  
                                END  
                                ELSE  
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromlot = LOTxLOCxID.LOT  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                          ,LOTATTRIBUTE(NOLOCK)  
                                    WHERE  LOTxLOCxID.LOT>@c_fromlot AND  
                                           LOTxLOCxID.storerkey = @c_currentstorer AND  
                                           LOTxLOCxID.sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qty- qtypicked-   
                                           qtyallocated>0 AND  
                                           LOTxLOCxID.qtyexpected = 0 AND  
                                           LOTxLOCxID.loc<>@c_currentloc AND  
                                           LOTxLOCxID.LOT = LOTATTRIBUTE.LOT AND   
                                           LOC.Facility = @c_zone01   
                                    ORDER BY  
                                           LOTTABLE04  
                                          ,LOTTABLE05  
                                END       
                                IF @@ROWCOUNT=0  
                                BEGIN  
                                    IF @b_debug=1  
                                        SELECT 'Not Lot Available! SKU= '+@c_currentsku   
                                              +' LOC='+@c_currentloc  
                                      
                                    SET ROWCOUNT 0  
                                    BREAK  
                                END  
                                  
                                SET ROWCOUNT 0  
                            END  
                            ELSE  
                            BEGIN  
                                SELECT @c_fromlot = @c_fromlot2  
                            END -- IF @b_donecheckoverallocatedlots = 1  
                            SET ROWCOUNT 0  
                            SELECT @c_fromloc = SPACE(10)  
                            WHILE (1=1 AND @n_remainingqty>0)  
                            BEGIN  
                                IF @c_zone02="ALL"  --SOS163044 : change from zone01 to zone02
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromloc = LOTxLOCxID.LOC  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                    WHERE  LOT = @c_fromlot AND  
                                           LOTxLOcxID.loc = LOC.loc AND  
                                           LOTxLOCxID.LOC>@c_fromloc AND  
                                           storerkey = @c_currentstorer AND  
                                           sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qty- qtypicked-   
                                           qtyallocated>0 AND  
                                           LOTxLOCxID.qtyexpected = 0 AND  
                                           LOTxLOCxID.loc<>@c_currentloc AND   
                                           LOC.Facility = @c_zone01   
                      ORDER BY  
                                           LOTxLOCxID.LOC  
                                END  
                                ELSE  
                                BEGIN  
                                    SET ROWCOUNT 1  
                                    SELECT @c_fromloc = LOTxLOCxID.LOC  
                                    FROM   LOTxLOCxID(NOLOCK)  
                                          ,LOC(NOLOCK)  
                                    WHERE  LOT = @c_fromlot AND  
                                           LOTxLOcxID.loc = LOC.loc AND  
                                           LOTxLOCxID.LOC>@c_fromloc AND  
                                           storerkey = @c_currentstorer AND  
                                           sku = @c_currentsku AND  
                                           LOTxLOCxID.Loc = LOC.LOC AND  
                                           LOC.Locationflag<>"DAMAGE" AND  
                                           LOC.Locationflag<>"HOLD" AND  
                                           LOC.Facility = @c_Facility AND  
                                           LOTxLOCxID.qty- qtypicked-   
                                           qtyallocated>0 AND  
                                           LOTxLOCxID.qtyexpected = 0 AND  
                                           LOTxLOCxID.loc<>@c_currentloc AND   
                                           LOC.Facility = @c_zone01   
                                    ORDER BY  
                                           LOTxLOCxID.LOC  
                                END  
                                IF @@ROWCOUNT=0  
                                BEGIN  
                                    SET ROWCOUNT 0  
                                    BREAK  
                                END  
                                  
                                SET ROWCOUNT 0  
                                SELECT @c_fromid = REPLICATE('Z' ,18)  
                                WHILE (1=1 AND @n_remainingqty>0)  
                                BEGIN  
                                    IF @c_zone02="ALL"  
                                    BEGIN  
                                        SET ROWCOUNT 1  
                                        SELECT @c_fromid = ID  
                                              ,@n_OnHandQty = LOTxLOCxID.QTY-   
                                               QTYPICKED- QTYALLOCATED  
                                        FROM   LOTxLOCxID(NOLOCK)  
                                              ,LOC(NOLOCK)  
                                        WHERE  LOT = @c_fromlot AND  
                                               LOTxLOcxID.loc = LOC.loc AND  
                                               LOTxLOCxID.LOC = @c_fromloc AND  
                                               id<@c_fromid AND  
                                               storerkey = @c_currentstorer AND  
                                               sku = @c_currentsku AND  
                                               LOC.Locationflag<>"DAMAGE" AND  
                                               LOC.Locationflag<>"HOLD" AND  
                                               LOC.Facility = @c_Facility AND  
                                               LOTxLOCxID.qty- qtypicked-   
                                               qtyallocated>0 AND  
                                               LOTxLOCxID.qtyexpected = 0 AND  
                                               LOTxLOCxID.loc<>@c_currentloc AND   
                                               LOC.Facility = @c_zone01   
                                        ORDER BY  
                                               ID DESC  
                                    END  
                                    ELSE  
                                    BEGIN  
                                        SET ROWCOUNT 1  
                                        SELECT @c_fromid = ID  
                                 ,@n_OnHandQty = LOTxLOCxID.QTY-   
                                               QTYPICKED- QTYALLOCATED  
                                        FROM   LOTxLOCxID(NOLOCK)  
                                              ,LOC(NOLOCK)  
                                        WHERE  LOT = @c_fromlot AND  
                                               LOTxLOcxID.loc = LOC.loc AND  
                                               LOTxLOCxID.LOC = @c_fromloc AND  
                                               id<@c_fromid AND  
                                               storerkey = @c_currentstorer AND  
                                               sku = @c_currentsku AND  
                                               LOC.Locationflag<>"DAMAGE" AND  
                                               LOC.Locationflag<>"HOLD" AND  
                                               LOC.Facility = @c_Facility AND  
                                               LOTxLOCxID.qty- qtypicked-   
                                               qtyallocated>0 AND  
                                               LOTxLOCxID.qtyexpected = 0 AND  
                                               LOTxLOCxID.loc<>@c_currentloc AND   
                                               LOC.Facility = @c_zone01   
                                        ORDER BY  
                                               ID DESC  
                                    END  
                                    IF @@ROWCOUNT=0  
                                    BEGIN  
                                        IF @b_debug=1  
                                        BEGIN  
                                            SELECT   
                                                   'Stop because No Pallet Found! Loc = '   
                                                  +@c_currentloc+' SKU = '+@c_currentsku   
                                                  +' LOT = '+@c_fromlot+  
                                                   ' From Loc = '+@c_fromloc   
                                                  +' From ID = '+@c_fromid  
                                        END  
                                          
                                        SET ROWCOUNT 0  
                                        BREAK  
                                    END  
                                      
                                    SET ROWCOUNT 0  
                                    /* We have a cANDidate FROM record */  
                                    /* Verify that the cANDidate ID is not on HOLD */  
                                    /* We could have done this in the SQL statements above */  
                                    /* But that would have meant a 5-way join.             */  
                                    /* SQL SERVER seems to work best on a maximum of a     */  
                                    /* 4-way join.                                         */  
                                    IF EXISTS(  
                                           SELECT 1  
                                           FROM   ID(NOLOCK)  
                                           WHERE  ID = @c_fromid AND  
                                                  STATUS = "HOLD"  
                                       )  
                                    BEGIN  
                                        IF @b_debug=1  
                                        BEGIN  
                                            SELECT   
                                                   'Stop because location Status = HOLD! Loc = '   
                                                  +@c_currentloc+' SKU = '+@c_currentsku   
                                                  +' ID = '+@c_fromid  
                                        END  
                                          
                                        BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                            END   
                                    /* Verify that the from location is not overallocated in skuxloc */  
                                    IF EXISTS(  
                                           SELECT 1  
                                           FROM   SKUxLOC(NOLOCK)  
                                           WHERE  STORERKEY = @c_currentstorer AND  
                                                  SKU = @c_currentsku AND  
                                                  LOC = @c_fromloc AND  
                                                  QTYEXPECTED>0  
                                       )  
                                    BEGIN  
                                        IF @b_debug=1  
                                        BEGIN  
                                            SELECT   
                                                   'Stop because Qty Expected > 0! Loc = '   
                                                  +@c_currentloc+' SKU = '+@c_currentsku  
                                        END  
                                          
                                        BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                    END  
                                    /* Verify that the FROM location is not the */  
                                    /* PIECE PICK location for this product.    */  
                                    IF EXISTS(  
                                           SELECT 1  
                                           FROM   SKUxLOC(NOLOCK)  
                                           WHERE  STORERKEY = @c_currentstorer AND  
                                                  SKU = @c_currentsku AND  
                                                  LOC = @c_fromloc AND  
                                                  LOCATIONTYPE = "PICK"  
                                       )  
                                    BEGIN  
                                        IF @b_debug=1  
                                        BEGIN  
                                            SELECT   
                                                   'Stop because location Type = PICK! Loc = '   
                                                  +@c_currentloc+' SKU = '+@c_currentsku  
                                        END  
                                          
                                        BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                    END  
                                    /* Verify that the FROM location is not the */  
                                    /* CASE PICK location for this product.     */  
                                    IF EXISTS(  
                                           SELECT 1  
                                           FROM   SKUxLOC(NOLOCK)  
                                           WHERE  STORERKEY = @c_currentstorer AND  
                                                  SKU = @c_currentsku AND  
                                                  LOC = @c_fromloc AND  
                                                  LOCATIONTYPE = "CASE"  
                                       )  
                                    BEGIN  
                                        IF @b_debug=1  
                                        BEGIN  
                                            SELECT   
                                                   'Stop because location Type = CASE! Loc = '   
                                                  +@c_currentloc+' SKU = '+@c_currentsku  
                                        END  
                                          
                                        BREAK -- Get out of loop, so that next cANDidate can be evaluated  
                                    END  
                                    /* At this point, get the available qty from */  
                                    /* the SKUxLOC record.                       */  
                                    /* If it's less than what was taken from the */  
                                    /* lotxlocxid record, then use it.           */  
                                    SELECT @n_skulocavailableqty = QTY-   
                                           QTYALLOCATED- QTYPICKED  
                                    FROM   SKUxLOC(NOLOCK)  
                                    WHERE  STORERKEY = @c_currentstorer AND  
                                           SKU = @c_currentsku AND  
                                           LOC = @c_fromloc  
                                      
                                    IF @n_skulocavailableqty<@n_OnHandQty  
                                    BEGIN  
                                        SELECT @n_OnHandQty = @n_skulocavailableqty  
                                    END  
                                    /* How many cases can I get from this record? */  
                                    SELECT @n_possiblecases = FLOOR(@n_OnHandQty/@n_currentfullcase)  
                                    /* How many do we take? */  
                                    IF @n_OnHandQty>@n_RemainingQty  
                                    BEGIN  
                                        SELECT @n_fromqty = @n_RemainingQty  
                                              ,-- @n_remainingqty = @n_remainingqty - (@n_remainingcases * @n_currentfullcase),  
                                               @n_RemainingQty = 0  
                                    END  
                                    ELSE  
                                    BEGIN  
                                        SELECT @n_fromqty = @n_OnHandQty  
                                              ,@n_remainingqty = @n_remainingqty   
                                              - @n_OnHandQty  
                                               -- @n_remainingcases =  @n_remainingcases - @n_possiblecases  
                                    END  
                                    IF @n_fromqty>0  
                                    BEGIN  
                                        SELECT @c_Packkey = PACK.PackKey  
                                              ,@c_UOM = PACK.PackUOM3  
                                        FROM   SKU(NOLOCK)  
                                              ,PACK(NOLOCK)  
                                        WHERE  SKU.PackKey = PACK.Packkey AND  
                                               SKU.StorerKey = @c_currentStorer AND  
                                               SKU.SKU = @c_currentSku  
                                          
                                        IF @n_continue=1 OR  
                                           @n_continue=2  
                                        BEGIN  
                                            INSERT #REPLENISHMENT  
                                              (  
                                                StorerKey, Sku, FromLoc, ToLoc,   
                                                Lot, Id, Qty, UOM, PackKey,   
                                                Priority, QtyMoved, QtyInPickLoc,   
                                                Facility  
                                              )  
                                            VALUES  
                                              (  
                                                @c_currentStorer, @c_currentSku,   
                                                @c_fromLoc, @c_currentLoc, @c_fromlot,   
                                                @c_fromid, @n_fromqty, @c_UOM, @c_Packkey,   
                                                @c_currentpriority, 0, 0, @c_Facility  
                                              )  
                                        END  
                                          
                                        SELECT @n_numberofrecs = @n_numberofrecs +1  
                                    END -- if from qty > 0  
                                    IF @b_debug=1  
                                    BEGIN  
                                        SELECT @c_currentsku ' sku'  
                                              ,@c_currentloc 'loc'  
                                              ,@c_currentpriority 'priority'  
                                              ,@n_currentfullcase 'full case'  
                                              ,@n_currentseverity 'severity'  
                                        -- select @n_fromqty 'qty', @c_fromloc 'fromloc', @c_fromlot 'from lot', @n_possiblecases 'possible cases'  
                                        SELECT @n_remainingqty '@n_remainingqty'  
                                              ,@c_currentloc+' SKU = '+@c_currentsku  
                                              ,@c_fromlot 'from lot'  
                                              ,@c_fromid  
                                    END  
                                      
                                    IF @c_fromid='' OR  
                                       @c_fromid IS NULL OR  
                                       dbo.fnc_RTrim(dbo.fnc_LTrim(@c_FromId))=  
                                       ''  
                                    BEGIN  
                                        -- SELECT @n_remainingqty=0  
                                        BREAK  
                                    END  
                                END -- SCAN LOT for ID  
                                SET ROWCOUNT 0  
                            END -- SCAN LOT for LOC                                     
                            SET ROWCOUNT 0  
                        END -- SCAN LOT FOR LOT  
                        SET ROWCOUNT 0  
                    END -- FOR SKU  
                    SET ROWCOUNT 0  
                END -- FOR STORER  
                SET ROWCOUNT 0  
            END -- FOR SEVERITY  
            SET ROWCOUNT 0  
        END -- (WHILE 1=1 on SKUxLOC FOR PRIORITY )  
        SET ROWCOUNT 0  
    END  
      
    IF @n_continue=1 OR  
       @n_continue=2  
    BEGIN  
        /* Update the column QtyInPickLoc in the Replenishment Table */  
        IF @n_continue=1 OR  
           @n_continue=2  
        BEGIN  
            UPDATE #REPLENISHMENT  
            SET    QtyInPickLoc = SkuxLoc.Qty- SkuxLoc.QtyPicked  
            FROM   SKUxLOC(NOLOCK)  
            WHERE  #REPLENISHMENT.Storerkey = Skuxloc.Storerkey AND  
                   #REPLENISHMENT.SKu = Skuxloc.Sku AND  
                   #REPLENISHMENT.toloc = SkuxLoc.loc  
        END  
    END  
    /*  
    SELECT R.FromLoc, R.Id, R.ToLoc, R.Sku, R.Qty, R.StorerKey, R.Lot, R.PackKey,   
    SKU.Descr, R.Priority, LOC.PutawayZone  
    FROM #REPLENISHMENT R, SKU (NOLOCK), LOC (NOLOCK)  
    WHERE SKU.Sku = R.Sku AND SKU.StorerKey = R.StorerKey  
    AND LOC.Loc = R.ToLoc  
    --    AND R.confirmed = 'N'  
    ORDER BY LOC.PutawayZone, R.Priority  
    */  
    SELECT R.FromLoc  
          ,R.Id  
          ,R.ToLoc  
          ,R.Sku  
          ,R.Qty  
          ,R.StorerKey  
          ,R.Lot  
          ,R.PackKey  
          ,SKU.Descr  
          ,R.Priority  
          ,LOC.PutawayZone  
          ,A.Lottable02  
          ,A.Lottable04  
          ,ISNULL(A.Lot2Total ,0) AvlQty  
          ,LOC.Facility  
    FROM   #REPLENISHMENT R  
           JOIN SKU(NOLOCK)  
                ON  (SKU.Sku=R.Sku AND SKU.StorerKey=R.StorerKey)  
           JOIN LOC(NOLOCK)  
                ON  (LOC.Loc=R.ToLoc)  
           LEFT OUTER JOIN (  
                    SELECT LA.StorerKey  
                          ,LA.Sku  
                          ,LA.Lottable02  
                          ,LA.Lottable04  
                          ,LLI.LOC  
                          ,LLI.LOT  
                          ,SUM(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked) Lot2Total  
                    FROM   LOTxLOCxID LLI(NOLOCK)  
                          ,LOTATTRIBUTE LA(NOLOCK)  
                    WHERE  LLI.Lot = LA.Lot  
                    GROUP BY  
                           LA.StorerKey  
                          ,LA.Sku  
                          ,LA.Lottable02  
                          ,LA.Lottable04  
                          ,LLI.LOC  
                          ,LLI.LOT  
                ) A  
                ON  (  
                        A.StorerKey=R.StorerKey AND  
                        A.Sku=R.Sku AND  
                        A.LOC=R.FromLoc AND  
                        A.LOT=R.Lot  
                )  
    WHERE LOC.Facility = @c_zone01   
    ORDER BY  
           LOC.PutawayZone  
          ,R.Priority  
END  

GO