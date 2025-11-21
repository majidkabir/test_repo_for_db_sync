SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispArchiveDailyInv                              			*/
/* Creation Date: 05.Dec.2006                                           */
/* Copyright: IDS                                                       */
/* Written by: June                                                     */
/*                                                                      */
/* Purpose: Housekeeping DailyInventory table                           */
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
/* Called By: SQL Schedule Task                                         */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author	Ver     Purposes                                */
/* 25 Sep 2009  TLTING  1.1     Performance Tune (tlting01)             */
/* 16 Dec 2010  TLTING  1.2     Commit ALL Tran (TLTING02)              */
/************************************************************************/

CREATE PROC  [dbo].[ispArchiveDailyInv]
					@c_archivekey  NVARCHAR(10)             
,              @b_Success      INT        OUTPUT    
,              @n_err          INT        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT    
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_continue                   INT
           ,@n_starttcnt                  INT	-- Holds the current transaction count
           ,@n_cnt                        INT	-- Holds @@ROWCOUNT after certain operations
           ,@b_debug                      INT -- Debug On OR Off
    
    /* #INCLUDE <SPACC1.SQL> */     
    DECLARE @n_retain_days                INT	-- days to hold data
           ,@d_result                     DATETIME	-- date (GETDATE() - noofdaystoretain)
           ,@c_datetype                   NVARCHAR(10)	-- 1=EditDate, 2=AddDate
           ,@n_archive_records            INT	-- No. of records to be archived
           ,@local_n_err                  INT
           ,@local_c_errmsg               NVARCHAR(254)
    
    DECLARE @c_StorerkeyStart             NVARCHAR(15)
           ,@c_StorerkeyEnd               NVARCHAR(15)
           ,@c_whereclause                NVARCHAR(254)
           ,@c_temp                       NVARCHAR(254)
           ,@c_CopyRowsToArchiveDatabase  NVARCHAR(1)
           ,@c_copyfrom_db                NVARCHAR(30)
           ,@c_copyto_db                  NVARCHAR(30)
           ,@d_InvDate                    DATETIME
           ,@c_storerkey                  NVARCHAR(15)
           ,@c_sku                        NVARCHAR(20)
           ,@c_lot                        NVARCHAR(10)
           ,@c_loc                        NVARCHAR(10)
           ,@c_id                         NVARCHAR(18)				 				 				 
    
    SELECT @n_starttcnt = @@TRANCOUNT
          ,@n_continue = 1
          ,@b_success = 0
          ,@n_err = 0
          ,@c_errmsg = ""
          ,@b_debug = 0
          ,@local_n_err = 0
          ,@local_c_errmsg = ' '
    
    SELECT @c_copyfrom_db = livedatabasename
          ,@c_copyto_db = archivedatabasename
          ,@n_retain_days = DailyInvNoofDaysToRetain
          ,@c_datetype = DailyInvDateType
          ,@c_StorerkeyStart = ISNULL(DailyInvStart ,'')
          ,@c_StorerkeyEnd = ISNULL(DailyInvEnd ,'ZZZZZZZZZZ')
          ,@c_CopyRowsToArchiveDatabase = copyrowstoarchivedatabase
    FROM   ArchiveParameters(NOLOCK)
    WHERE  Archivekey = @c_archivekey
    
    IF DB_ID(@c_copyto_db) IS NULL
    BEGIN
        SELECT @n_continue = 3
        SELECT @local_n_err = 77100
        SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
        SELECT @local_c_errmsg = ": Target Database "+@c_copyto_db+
               " Does NOT exist "+" ( "+
               " SQLSvr MESSAGE = "+LTRIM(RTRIM(@local_c_errmsg))+")"+
               ' (ispArchiveDailyInv) '
    END
    
    IF (@n_continue=1 OR @n_continue=2)
    BEGIN
        DECLARE @d_today DATETIME
        SELECT @d_today = CONVERT(DATETIME ,CONVERT(CHAR(11) ,GETDATE() ,106))
        SELECT @d_result = DATEADD(DAY ,(-@n_retain_days) ,@d_today)
        SELECT @d_result = DATEADD(DAY ,1 ,@d_result)
    END
    
    IF (@n_continue=1 OR @n_continue=2)
    BEGIN
        SELECT @b_success = 1
        SELECT @c_temp = 
               "Archive Of IDS DailyInventory Started with Parms; Datetype = "+
               RTRIM(@c_datetype)+
               ' ; Storerkey = '+RTRIM(@c_StorerkeyStart)+'-'+RTRIM(@c_StorerkeyEnd)
              +
               ' ; Copy Rows to Archive = '+RTRIM(@c_CopyRowsToArchiveDatabase)+
               ' ; Retain Days = '+CONVERT(CHAR(6) ,@n_retain_days)
        
        EXECUTE nspLogAlert
        @c_ModuleName="ispArchiveDailyInv",
        @c_AlertMessage=@c_temp,
        @n_Severity=0,
        @b_success=@b_success OUTPUT,
        @n_err=@n_err OUTPUT,
        @c_errmsg=@c_errmsg OUTPUT
        IF NOT @b_success=1
        BEGIN
            SELECT @n_continue = 3
        END
    END
    
    IF (@n_continue=1 OR @n_continue=2)
    BEGIN
        SET @c_temp = ''
        
        IF (
               RTRIM(@c_StorerkeyStart) IS NOT NULL
               AND RTRIM(@c_StorerkeyEnd) IS NOT NULL
           )
        BEGIN
            SELECT @c_temp = ' AND Storerkey BETWEEN '+'N'''+RTRIM(@c_StorerkeyStart) 
                  +''''+' AND '+
                   'N'''+RTRIM(@c_StorerkeyEnd)+''''
        END
        
        IF (
               (@n_continue=1 OR @n_continue=2)
               AND @c_CopyRowsToArchiveDatabase='Y'
           )
        BEGIN
            SELECT @b_success = 1
            EXEC nsp_BUILD_ARCHIVE_TABLE @c_copyfrom_db
                ,@c_copyto_db
                ,'DailyInventory'
                ,@b_success OUTPUT
                ,@n_err OUTPUT
                ,@c_errmsg OUTPUT
            
            IF NOT @b_success=1
            BEGIN
                SELECT @n_continue = 3
            END
        END   
        
        IF (
               (@n_continue=1 OR @n_continue=2)
               AND @c_CopyRowsToArchiveDatabase='Y'
           )
        BEGIN
            EXECUTE nspBuildAlterTableString @c_copyto_db,'DailyInventory',@b_success 
            OUTPUT,@n_err OUTPUT, @c_errmsg OUTPUT
            IF NOT @b_success=1
            BEGIN
                SELECT @n_continue = 3
            END
        END
        
        WHILE @@TRANCOUNT > 0 -- TLTING02
              COMMIT TRAN   
        
        IF (
               (@n_continue=1 OR @n_continue=2)
               AND @c_CopyRowsToArchiveDatabase='Y'
           )
        BEGIN
            IF (@n_continue=1 OR @n_continue=2)
            BEGIN
                IF @c_datetype="1" -- EditDate
                BEGIN
                    SELECT @c_whereclause = "WHERE EditDate  <= "+'"'+CONVERT(CHAR(20) ,@d_result ,106)
                          +'"'
                          +@c_temp
                END
                
                IF @c_datetype="2" -- AddDate
                BEGIN
                    SELECT @c_whereclause = "WHERE AddDate  <= "+'"'+CONVERT(CHAR(20) ,@d_result ,106) 
                          +'"' 
                          +@c_temp
                END
                
                IF @c_datetype="3" -- InventoryDate
                BEGIN
                    SELECT @c_whereclause = "WHERE InventoryDate <= "+'"'+
                           CONVERT(CHAR(20) ,@d_result ,106)+'"' 
                          +@c_temp
                END
                
                SELECT @n_archive_records = 0
                -- tlting01
                EXEC (
                         ' DECLARE Cur_DailyInv CURSOR FAST_FORWARD READ_ONLY FOR ' 
                        +
                         ' SELECT InventoryDate, Storerkey, Sku, lot, loc, ID FROM DailyInventory (NOLOCK) ' 
                        +@c_whereclause+
                         ' AND ISNULL(ArchiveCop,'''') <> ''9''  '+
                         ' ORDER BY InventoryDate, Storerkey '
                     ) 
                
                IF @b_debug=1
                BEGIN
                    PRINT 
                    ' SELECT InventoryDate, Storerkey, Sku, lot, loc, ID FROM DailyInventory (NOLOCK) ' 
                   +@c_whereclause+
                    ' AND ISNULL(ArchiveCop,'''') <> ''9''  '+
                    ' ORDER BY InventoryDate, Storerkey '
                END
                
                OPEN Cur_DailyInv 
                
                FETCH NEXT FROM Cur_DailyInv INTO @d_invDate, @c_storerkey, @c_sku, 
                @c_lot, @c_loc, @c_ID 	
                
                WHILE @@fetch_status<>-1
                BEGIN
                    BEGIN TRAN -- tlting01
                    UPDATE DailyInventory WITH (ROWLOCK)
                    SET    ArchiveCop = '9'
                    WHERE  InventoryDate = @d_invDate
                           AND Storerkey = @c_storerkey
                           AND SKU = @c_sku -- tlting01
                           AND LOT = @c_lot
                           AND LOC = @c_loc
                           AND ID = @c_ID 	
                    
                    SELECT @local_n_err = @@error
                          ,@n_cnt = @@rowcount
                    
                    SELECT @n_archive_records = @n_archive_records+1                                  
                    
                    IF @local_n_err<>0
                    BEGIN
                        SELECT @n_continue = 3
                        SELECT @local_n_err = 77101
                        SELECT @local_c_errmsg = CONVERT(CHAR(5) ,@local_n_err)
                        SELECT @local_c_errmsg = 
                               ": Update of Archivecop failed - CC Table. (ispArchiveDailyInv) " 
                              +" ( "+
                               " SQLSvr MESSAGE = "+LTRIM(RTRIM(@local_c_errmsg)) 
                              +")"
                        
                        ROLLBACK TRAN
                    END
                    ELSE
                    BEGIN
                        COMMIT TRAN -- tlting01
                    END
                    
                    FETCH NEXT FROM Cur_DailyInv INTO @d_invDate, @c_storerkey, 
                    @c_sku, @c_lot, @c_loc, @c_ID
                END -- while 
                
                CLOSE Cur_DailyInv
                DEALLOCATE Cur_DailyInv
                /* END (SOS38267) UPDATE*/
            END 
            
            IF (
                   (@n_continue=1 OR @n_continue=2)
                   AND @c_CopyRowsToArchiveDatabase='Y'
               )
            BEGIN
                SELECT @c_temp = "Attempting to Archive "+RTRIM(CONVERT(CHAR(6) ,@n_archive_records)) 
                      +
                       " DailyInventory records and "+RTRIM(CONVERT(CHAR(6) ,@n_archive_records)) 
                      +" DailyInventory records"
                
                EXECUTE nspLogAlert
                @c_ModuleName="ispArchiveDailyInv",
                @c_AlertMessage=@c_Temp ,
                @n_Severity=0,
                @b_success=@b_success OUTPUT,
                @n_err=@n_err OUTPUT,
                @c_errmsg=@c_errmsg OUTPUT
                IF NOT @b_success=1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            
            IF (@n_continue=1 OR @n_continue=2)
            BEGIN
                WHILE @@TRANCOUNT > 0 -- tlting
                      COMMIT TRAN   
                
                SELECT @b_success = 1
                EXEC nsp_BUILD_INSERT @c_copyto_db
                    ,'DailyInventory'
                    ,1
                    ,@b_success OUTPUT
                    ,@n_err OUTPUT
                    ,@c_errmsg OUTPUT
                
                IF NOT @b_success=1
                BEGIN
                    SELECT @n_continue = 3
                END
            END
        END
    END
    
    IF (@n_continue=1 OR @n_continue=2)
    BEGIN
        SELECT @b_success = 1
        EXECUTE nspLogAlert
        @c_ModuleName="ispArchiveDailyInv",
        @c_AlertMessage="Archive Of DailyInventory Ended Normally.",
        @n_Severity=0,
        @b_success=@b_success OUTPUT,
        @n_err=@n_err OUTPUT,
        @c_errmsg=@c_errmsg OUTPUT
        IF NOT @b_success=1
        BEGIN
            SELECT @n_continue = 3
        END
    END
    ELSE
    BEGIN
        IF @n_continue=3
        BEGIN
            SELECT @b_success = 1
            EXECUTE nspLogAlert
            @c_ModuleName="ispArchiveDailyInv",
            @c_AlertMessage=
            "Archive Of DailyInventory Ended Abnormally - Check This Log For Additional Messages.",
            @n_Severity=0,
            @b_success=@b_success OUTPUT,
            @n_err=@n_err OUTPUT,
            @c_errmsg=@c_errmsg OUTPUT
            IF NOT @b_success=1
            BEGIN
                SELECT @n_continue = 3
            END
        END
    END
    
    WHILE @@TRANCOUNT<@n_starttcnt -- tlting
    BEGIN TRAN 
    
    
    /* #INCLUDE <SPACC2.SQL> */     
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        SELECT @b_success = 0
        IF @@TRANCOUNT=1
           AND @@TRANCOUNT>@n_starttcnt
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_starttcnt
            BEGIN
                COMMIT TRAN
            END
        END
        
        SELECT @n_err = @local_n_err
        SELECT @c_errmsg = @local_c_errmsg
        IF (@b_debug=1)
        BEGIN
            SELECT @n_err
                  ,@c_errmsg
                  ,'before putting in nsp_logerr at the bottom'
        END
        
        EXECUTE nsp_logerror @n_err, @c_errmsg, "ispArchiveDailyInv"
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
    END
    ELSE
    BEGIN
        SELECT @b_success = 1
        WHILE @@TRANCOUNT>@n_starttcnt
        BEGIN
            COMMIT TRAN
        END
        RETURN
    END
END

GO