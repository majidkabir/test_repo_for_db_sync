SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : nspArchiveGUI                                      		*/
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: ONGGB                                                    */
/*                                                                      */
/* Purpose: Housekeep nspArchiveGUI table                           		*/
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
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/*	2006-05-29	 ONG				SOS50920 - Modified from nspArchiveGUIting*/
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspArchiveGUI]        
      @c_archivekey   NVARCHAR(10)
   ,  @b_success      int        output    
   ,  @n_err          int        output    
   ,  @c_errmsg       NVARCHAR(250)  output    
AS
BEGIN -- MAIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT,  
      @n_starttcnt INT, 			-- holds the current transaction count
      @n_cnt INT, 					-- holds @@rowcount after certain operations
      @b_debug INT             	-- debug on OR off
        
   /* #include <sparpo1.sql> */     
   DECLARE @n_retain_days INT      , 		-- days to hold data
      @d_result  DATETIME     , 				-- date po_date - (getdate() - noofdaystoretain
      @c_datetype NVARCHAR(10),      			-- 1=editdate, 3=adddate
      @n_archive_GUI_records   INT, 		-- # of GUI records to be archived
      @n_archive_GUI_detail_records INT, 	-- # of GUIdetail records to be archived
      @n_default_id INT,
      @n_strlen INT,
      @local_n_err         INT,
      @local_c_errmsg    NVARCHAR(254)
   
   DECLARE @c_copyfrom_db  NVARCHAR(55),
      @c_copyto_db    NVARCHAR(55),
      @c_GUIactive NVARCHAR(2),
      @c_GUIInvoiceNoStart NVARCHAR(10),
      @c_GUIInvoiceNoEnd NVARCHAR(10),
      @c_whereclause NVARCHAR(254),
      @c_temp NVARCHAR(254),
      @c_Err NVARCHAR(254),
      @CopyRowsToArchiveDatabase NVARCHAR(1)
   
   DECLARE @c_ExecStatements NVARCHAR(max)
			 ,@cInvoiceNo NVARCHAR(10)   
          ,@cLineNumber NVARCHAR(5) 

   SELECT @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
      @b_debug = 0, @local_n_err = 0, @local_c_errmsg = ' '
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN -- 3
      SELECT  @c_copyfrom_db = LiveDatabasename,
         @c_copyto_db = ArchiveDatabasename,
         @n_retain_days = GUINumberofDaysToRetain,
         @c_GUIactive = GUIActive,
         @c_DateType = GUIDateType,
         @c_GUIInvoiceNoStart = ISNULL(GUIInvoiceNoStart,''),
         @c_GUIInvoiceNoEnd = ISNULL(GUIInvoiceNoEnd,'ZZZZZZZZZZ'),
         @CopyRowsToArchiveDatabase = CopyRowsToArchiveDatabase
      FROM ArchiveParameters (NOLOCK)
      WHERE Archivekey = @c_archivekey

		IF @b_debug = 1 
		BEGIN
			SELECT @c_copyfrom_db LiveDatabasename,
		         @c_copyto_db ArchiveDatabasename,
		         @n_retain_days GUINumberofDaysToRetain,
		         @c_GUIactive GUIActive,
		         @c_dateType GUIDateType,
		         @c_GUIInvoiceNoStart GUIInvoiceNoStart,
		         @c_GUIInvoiceNoEnd GUIInvoiceNoEnd,
		         @CopyRowsToArchiveDatabase CopyRowsToArchiveDatabase 
		END
         
      IF db_id(@c_copyto_db) IS NULL
      BEGIN
         SELECT @n_continue = 3
         SELECT @local_n_err = 77301
         SELECT @local_c_errmsg = CONVERT(CHAR(5),@local_n_err)
         SELECT @local_c_errmsg =
            ': target database ' + dbo.fnc_RTrim(@c_copyto_db) + ' does not exist ' + ' ( ' +
            ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')' + ' (nspArchiveGUI)'
      END

      SELECT @d_result = DATEADD(DAY,-@n_retain_days,getdate())
      SELECT @d_result = DATEADD(DAY,1,@d_result)

      SELECT @b_success = 1
      SELECT @c_Err = 'Archive of GUI started with parms; DateType = ' + dbo.fnc_RTrim(@c_datetype) +
         ' ; Active = '+ dbo.fnc_RTrim(@c_GUIActive)+
         ' ; InvoiceNo = '+dbo.fnc_RTrim(@c_GUIInvoiceNostart)+'-' +dbo.fnc_RTrim(@c_GUIInvoiceNoEnd)+
         ' ; Copy Rows To Archive = '+dbo.fnc_RTrim(@CopyRowsToArchiveDatabase) +
         ' ; Retain days = '+ CONVERT(CHAR(6),@n_retain_days)
   
      EXECUTE nsplogalert
         @c_modulename   = 'nspArchiveGUI',
         @c_alertmessage = @c_Err ,
         @n_severity     = 0,
         @b_success       = @b_success output,
         @n_err          = @n_err output,
         @c_errmsg       = @c_errmsg output
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END -- 3

   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN -- 4
      SELECT @c_whereclause = ' '
      SELECT @c_temp = ' '      
   
      SELECT @c_temp = 'AND GUI.InvoiceNo BETWEEN '+ 'N'''+ dbo.fnc_RTrim(@c_GUIInvoiceNostart) + ''''+ ' AND '+
         'N'''+ dbo.fnc_RTrim(@c_GUIInvoiceNoEnd)+''''
   
      IF (@b_debug =1 )
      BEGIN
         PRINT 'subsetting clauses'
         SELECT 'execute clause @c_whereclause', @c_whereclause
         SELECT 'execute clause @c_temp ', @c_temp
      END
   
      IF ((@n_continue = 1 OR @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
      BEGIN 
         IF (@b_debug =1 )
         BEGIN
            print 'starting table existence check for GUI...'
         END
         SELECT @b_success = 1
         EXEC nsp_build_archive_table 
            @c_copyfrom_db, 
            @c_copyto_db,
            'GUI',
            @b_success output , 
            @n_err output , 
            @c_errmsg output
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END   
         
      IF ((@n_continue = 1 OR @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
      BEGIN 
         IF (@b_debug =1 )
         BEGIN
            PRINT 'starting table existence check for GUIdetail...'
         END
         SELECT @b_success = 1
         EXEC nsp_build_archive_table 
            @c_copyfrom_db, 
            @c_copyto_db,
            'GUIDetail',
            @b_success output , 
            @n_err output , 
            @c_errmsg output
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END   

      IF ((@n_continue = 1 OR @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
      BEGIN
         IF (@b_debug =1 )
         BEGIN
            print 'building alter table string for GUI...'
         END
         EXECUTE nspbuildaltertablestring 
            @c_copyto_db,
            'GUI',
            @b_success output,
            @n_err output, 
            @c_errmsg output
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')
      BEGIN
         IF (@b_debug =1 )
         BEGIN
            print 'building alter table string for GUIDetail...'
         END
         execute nspbuildaltertablestring 
            @c_copyto_db,
            'GUIdetail',
            @b_success output,
            @n_err output, 
            @c_errmsg output
         IF not @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   
      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN 

      IF ((@n_continue = 1 OR @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
      BEGIN -- 5
/*		Not Required while GUI doesn't have EditDate   
         if @c_datetype = '1' -- editdate
         BEGIN
            SELECT @c_whereclause = "WHERE ( GUI.editdate <= " + '"'+ convert(CHAR(8),@d_result,112)+'"' + " ) " + @c_temp  
         END
*/
         if @c_datetype = '2' -- adddate
			BEGIN
            SELECT @c_whereclause = "WHERE ( GUI.adddate <= " + '"'+ convert(CHAR(8),@d_result,112)+'"' + " ) " + @c_temp 
			END

         SELECT @n_archive_GUI_records = 0
         SELECT @n_archive_GUI_detail_records  = 0
         
			SELECT @c_ExecStatements = ' SELECT GUI.InvoiceNo ' +
									         ' FROM GUI (NOLOCK) ' +
									          @c_WhereClause +
									         ' AND (GUI.InvoiceNo IS NULL OR GUI.InvoiceNo = '''') ' +
									         ' AND (GUI.Status = ''9'')  ' + 
									         ' ORDER BY GUI.InvoiceNo' 

			If @b_debug = 1
			begin
				PRINT 'Declare cursor C_InvoiceNo ... '
				PRINT @c_ExecStatements

				EXEC (@c_ExecStatements)
			end

         EXEC (' Declare C_InvoiceNo CURSOR FAST_FORWARD READ_ONLY FOR '
			+ @c_ExecStatements)
         
         OPEN C_InvoiceNo
         
         FETCH NEXT FROM C_InvoiceNo INTO @cInvoiceNo
         
         WHILE @@fetch_status <> -1
         BEGIN
            BEGIN TRAN 

            UPDATE GUI WITH (ROWLOCK)
               SET ArchiveCop = '9' 
            WHERE InvoiceNo = @cInvoiceNo  

            SELECT @local_n_err = @@error   --, @n_cnt = @@rowcount            
            SELECT @n_archive_GUI_records = @n_archive_GUI_records + 1            
            IF @local_n_err <> 0
            BEGIN 
               SELECT @n_continue = 3
               SELECT @local_n_err = 77302
               SELECT @local_c_errmsg = convert(CHAR(5),@local_n_err)
               SELECT @local_c_errmsg =
               ': Update of Archivecop Failed - GUI (nspArchiveGUI) ' + ' ( ' +
               ' Sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
               ROLLBACK TRAN 
            END  
            ELSE
            BEGIN
               COMMIT TRAN 
            END 

            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN   
               DECLARE C_Detail_InvoiceNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT LineNumber    
                 FROM GUIDetail (nolock)
               WHERE InvoiceNo = @cInvoiceNo 
               ORDER BY InvoiceNo        
    
               OPEN C_Detail_InvoiceNo 
            
               FETCH NEXT FROM C_Detail_InvoiceNo INTO @cLineNumber
            
               WHILE @@fetch_status <> -1
               BEGIN
                  BEGIN TRAN 

                  UPDATE GUIDetail with (ROWLOCK) 
                     Set Archivecop = '9'
                  WHERE InvoiceNo = @cInvoiceNo  
                  AND   LineNumber = @cLineNumber 
     
                  SELECT @local_n_err = @@error --, @n_cnt = @@rowcount            
                  SELECT @n_archive_GUI_detail_records  = @n_archive_GUI_detail_records  + 1                                  
                  IF @local_n_err <> 0
                  BEGIN 
                     SELECT @n_continue = 3
                     SELECT @local_n_err = 77303
                     SELECT @local_c_errmsg = convert(CHAR(5),@local_n_err)
                     SELECT @local_c_errmsg =
                     ': Update of ArchiveCop Failed - GUIdetail. (nspArchiveGUI) ' + ' ( ' +
                     ' sqlsvr message = ' + dbo.fnc_LTrim(dbo.fnc_RTrim(@local_c_errmsg)) + ')'
                     ROLLBACK TRAN 
                  END  
                  ELSE
                  BEGIN
                     COMMIT TRAN 
                  END 
 
      
                  FETCH NEXT FROM C_Detail_InvoiceNo INTO @cLineNumber
               END -- while InvoiceNo 
      
               CLOSE C_Detail_InvoiceNo 
               DEALLOCATE C_Detail_InvoiceNo               
            END -- (@n_continue = 1 OR @n_continue = 2) Detail 
          
            FETCH NEXT FROM C_InvoiceNo INTO @cInvoiceNo
         END -- while InvoiceNo 

         CLOSE C_InvoiceNo
         DEALLOCATE C_InvoiceNo

      
         IF ((@n_continue = 1 OR @n_continue = 2)  AND @CopyRowsToArchiveDatabase = 'y')
         BEGIN
            SELECT @c_Err = 'Attempting to Archive ' + dbo.fnc_RTrim(CONVERT(CHAR(6),@n_archive_GUI_records )) +
               ' GUI records and ' + dbo.fnc_RTrim(CONVERT(CHAR(6),@n_archive_GUI_detail_records )) + ' GUIdetail records'
            EXECUTE nsplogalert
               @c_modulename   = 'nspArchiveGUI',
               @c_alertmessage = @c_Err ,
               @n_severity     = 0,
               @b_success       = @b_success OUTPUT,
               @n_err          = @n_err OUTPUT,
               @c_errmsg       = @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END 

         IF ((@n_continue = 1 OR @n_continue = 2) and @CopyRowsToArchiveDatabase = 'y')
         BEGIN   
            IF (@b_debug =1 )
            BEGIN
               print 'Run nsp_build_insert for GUIdetail...'
            END
            SELECT @b_success = 1
            EXEC nsp_build_insert  
               @c_copyto_db, 
               'GUIdetail',
               1,
               @b_success output , 
               @n_err output, 
               @c_errmsg output
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END   
      
         IF ((@n_continue = 1 OR @n_continue = 2) AND @CopyRowsToArchiveDatabase = 'y')
         BEGIN   
            IF (@b_debug =1 )
            BEGIN
               PRINT 'Run nsp_build_insert for GUI...'
            END
            SELECT @b_success = 1
            EXEC nsp_build_insert  
               @c_copyto_db, 
               'GUI',
               1,
               @b_success output , 
               @n_err output, 
               @c_errmsg output
            IF not @b_success = 1
            BEGIN
               SELECT @n_continue = 3
            END
         END   
      END -- 5 
   END -- 4
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nsplogalert
         @c_modulename   = 'nspArchiveGUI',
         @c_alertmessage = 'Archive of GUI & GUIdetail ended normally.',
         @n_severity     = 0,
         @b_success       = @b_success output,
         @n_err          = @n_err output,
         @c_errmsg       = @c_errmsg output
      IF not @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   ELSE
   BEGIN
      IF @n_continue = 3
      BEGIN
         SELECT @b_success = 1
         EXECUTE nsplogalert
            @c_modulename   = 'nspArchiveGUI',
            @c_alertmessage = 'Archive of GUI & GUIdetail ended abnormally - check this log for additional messages.',
            @n_severity     = 0,
            @b_success       = @b_success OUTPUT ,
            @n_err          = @n_err OUTPUT,
            @c_errmsg       = @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
   END

   /* #include <sparpo2.sql> */     
   if @n_continue=3  -- error occured - process and return
   BEGIN
      SELECT @b_success = 0
      IF @@trancount = 1 AND @@trancount > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@trancount > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
   
      SELECT @n_err = @local_n_err
      SELECT @c_errmsg = @local_c_errmsg
      IF (@b_debug = 1)
      BEGIN
         SELECT @n_err,@c_errmsg, 'Before putting in nsp_logerr at the bottom'
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspArchiveGUI'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@trancount > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- main

GO