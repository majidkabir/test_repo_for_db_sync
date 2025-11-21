SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : nsp_Build_LogInsert                                    */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: Wanyt                                                    */
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
/* 2005-Jun-15  June          Register PVCS : SOS18664                  */
/* 2005-Aug-10  Ong           SOS38267 : obselete sku & storerkey       */
/*                                                                      */
/************************************************************************/



CREATE PROCEDURE [dbo].[nsp_Build_LogInsert]
@c_copyto_db    NVARCHAR(50)     
,              @c_tablename    NVARCHAR(50)
,              @c_tablename2   NVARCHAR(50)
,              @c_whereclause1 NVARCHAR(255)    
,              @c_whereclause2 NVARCHAR(255) 
,              @b_archive      int             
,              @b_Success      int        OUTPUT    
,              @n_err          int        OUTPUT    
,              @c_errmsg       NVARCHAR(250)  OUTPUT    
AS

/*---------------------------------------------------------------------*/
/* 9 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters          */      
/*---------------------------------------------------------------------*/
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE        @n_continue int        ,  
      @n_starttcnt int        , -- Holds the current transaction count
      @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
      @b_debug int              -- Debug On Or Off
   DECLARE @n_rowcount          integer         
   DECLARE @n_nextrow           integer         
   DECLARE @c_msg               NVARCHAR(255)    
   DECLARE @c_field             NVARCHAR(50)     
   DECLARE @c_buildfieldstring  NVARCHAR(255)   
   DECLARE @c_buildfieldstring1 NVARCHAR(255) 
   DECLARE @c_firsttime         NVARCHAR(1)         
   DECLARE @c_one               NVARCHAR(255)    
   DECLARE @c_onea    NVARCHAR(255)
   DECLARE @c_two               NVARCHAR(255)    
   DECLARE @c_twoa              NVARCHAR(255)    
   DECLARE @c_three             NVARCHAR(255)
   DECLARE @c_threea            NVARCHAR(255)
   DECLARE @c_four              NVARCHAR(255)
   DECLARE @c_foura             NVARCHAR(255)
   DECLARE @c_five              NVARCHAR(255)
   DECLARE @c_fivea             NVARCHAR(255)
   DECLARE @c_six               NVARCHAR(255)
   DECLARE @c_sixa              NVARCHAR(255)
   DECLARE @c_seven             NVARCHAR(255)
   DECLARE @c_sevena            NVARCHAR(255)
   DECLARE @c_eight             NVARCHAR(255)
   DECLARE @c_eighta            NVARCHAR(255)
   DECLARE @c_nine              NVARCHAR(255)
   DECLARE @c_ninea             NVARCHAR(255)
   DECLARE @c_ten               NVARCHAR(255)
   DECLARE @c_tena              NVARCHAR(255)
   DECLARE @c_eleven            NVARCHAR(255)
   DECLARE @c_elevena           NVARCHAR(255)
   DECLARE @c_twelve            NVARCHAR(255)
   DECLARE @c_twelvea           NVARCHAR(255)
   DECLARE @c_thirteen          NVARCHAR(255)
   DECLARE @c_thirteena         NVARCHAR(255)
   DECLARE @c_fourteen          NVARCHAR(255)
   DECLARE @c_fourteena         NVARCHAR(255)
   DECLARE @c_fifteen           NVARCHAR(255)
   DECLARE @c_fifteena          NVARCHAR(255)
   DECLARE @c_sixteen           NVARCHAR(255)
   DECLARE @c_sixteena          NVARCHAR(255)
   DECLARE @n_messageno         int             
   DECLARE @c_comma             NVARCHAR(1)         
   DECLARE @c_parenset          NVARCHAR(1)         
   DECLARE @n_length            tinyint         
   DECLARE @c_typename          NVARCHAR(32)     
   DECLARE @c_exist             NVARCHAR(255)    
   DECLARE @c_exist1            NVARCHAR(255)
   DECLARE @c_whereclause       NVARCHAR(25)     
   DECLARE @user_type           smallint         
   DECLARE @n_first_comma_flag          int
   declare @c_detailprefix      NVARCHAR(20)
   
   SELECT @n_first_comma_flag = 0
   
   SELECT @c_comma = ''
   SELECT @c_parenset = '0'
   SELECT @n_continue = 1
   SELECT @b_debug = 0
   SELECT @n_messageno = 1
   SELECT @c_one               =  ' '
   SELECT @c_onea              =  ' '
   SELECT @c_two               =  ' '
   SELECT @c_twoa              =  ' '
   SELECT @c_three             =  ' '
   SELECT @c_threea            =  ' '
   SELECT @c_four              =  ' '
   SELECT @c_foura             =  ' '
   SELECT @c_five              =  ' '
   SELECT @c_fivea             =  ' '
   SELECT @c_six               =  ' '
   SELECT @c_sixa              =  ' '
   SELECT @c_seven             =  ' '
   SELECT @c_sevena            =  ' '
   SELECT @c_eight             =  ' '
   SELECT @c_eighta            =  ' '
   SELECT @c_nine              =  ' '
   SELECT @c_ninea             =  ' '
   SELECT @c_ten               =  ' '
   SELECT @c_tena              =  ' '
   SELECT @c_eleven            =  ' '
   SELECT @c_elevena           =  ' '
   SELECT @c_twelve            =  ' '
   SELECT @c_twelvea           =  ' '
   SELECT @c_thirteen          =  ' '
   SELECT @c_thirteena         =  ' '
   SELECT @c_fourteen          =  ' '
   SELECT @c_fourteena         =  ' '
   SELECT @c_fifteen           =  ' '
   SELECT @c_fifteena          =  ' '
   SELECT @c_sixteen           =  ' '
   SELECT @c_sixteena          =  ' '
   SELECT @c_sixteen = dbo.fnc_RTrim(@c_copyto_db) + '..' + dbo.fnc_RTrim(@c_tablename)
   
   IF  OBJECT_ID( @c_sixteen) is NULL
   BEGIN 
      SELECT @n_continue = 3  -- No need to continue if table does not exist in to database
      SELECT @n_continue = 3
      SELECT @n_err = 73500
      SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Table does not exist in Target Database " +
         @c_tablename + "(nsp_Build_LogInsert)"
   END 

   IF  dbo.fnc_RTrim(@c_tablename2) IS NOT NULL
   BEGIN
      IF  OBJECT_ID( dbo.fnc_RTrim(@c_copyto_db) + '..' + dbo.fnc_RTrim(@c_tablename2)) is NULL
      BEGIN 
         SELECT @n_continue = 3  -- No need to continue if table does not exist in to database
         SELECT @n_continue = 3
         SELECT @n_err = 73499
         SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Table does not exist in Target Database " +
            @c_tablename2 + "(nsp_Build_LogInsert)"
      END 
      ELSE
      BEGIN
      SELECT @c_tablename2 = ", " + @c_tablename2 + "(nolock)"
      SELECT @c_detailprefix = @c_tablename+"."
      END
      
   END
   ELSE
   BEGIN 
   SELECT @c_tablename2 = " "
        SELECT @c_detailprefix = " "
   END 
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_rowcount = count(syscolumns.name)
      FROM    sysobjects, syscolumns
      WHERE   sysobjects.id = syscolumns.id
         AND     sysobjects.name = @c_tablename
      IF (@n_rowcount <= 0)
      BEGIN  
         SELECT @n_continue = 3
         SELECT @n_err = 73501
         SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":No rows or columns found for " +
            dbo.fnc_RTrim(@c_tablename) + "(nsp_Build_LogInsert)"
      END    
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_nextrow = 0
      SELECT @c_firsttime = 'Y'
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN  
      select @c_sixteen = ' '
      DECLARE @b_cursoropen int
      SELECT @b_cursoropen = 0
      DECLARE CUR_INSERT_BUILD Cursor for
      SELECT syscolumns.name,  syscolumns.length, syscolumns.usertype, systypes.name 
      FROM    dbo.sysobjects  , syscolumns, systypes
      WHERE   sysobjects.id = syscolumns.id and
         syscolumns.xtype = systypes.xtype and
         sysobjects.name =  @c_tablename
      OPEN CUR_INSERT_BUILD
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN  
         SELECT @n_continue = 3
         SELECT @n_err = 73502
         SELECT @c_errmsg = CONVERT(char(250),@n_err)
            + ":  Open of cursor failed. (nsp_Build_LogInsert) " + " ( " +
            " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ")"
      END   
   
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_cursoropen = 1
      END
      WHILE @n_nextrow < @n_rowcount and (@n_continue = 1 or @n_continue = 2)
      BEGIN    
         FETCH Next from CUR_INSERT_BUILD into @c_field, @n_length, @user_type, @c_typename 
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN  
            SELECT @n_continue = 3
            SELECT @n_err = 73503
            SELECT @c_errmsg = CONVERT(char(250),@n_err)
               + ":  fetch failed. (nsp_Build_LogInsert) " + " ( " +
               " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ")"
         END   
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF (@@FETCH_STATUS <> -1)               
            BEGIN 
               IF (@@FETCH_STATUS <> -2)          
               BEGIN 
                  IF (@b_debug = 1)
                  BEGIN
                     SELECT 'in loop ',@c_buildfieldstring , @user_type, @n_nextrow
                  END
                  IF (dbo.fnc_RTrim(@c_typename) <> 'TimeStamp')
                  BEGIN
                     IF (@n_first_comma_flag = 1)
                     BEGIN
                        SELECT @c_buildfieldstring =  @c_buildfieldstring + @c_comma + dbo.fnc_RTrim(@c_detailprefix) + @c_field
                        SELECT @c_buildfieldstring1 =  @c_buildfieldstring1 + @c_comma  + @c_field
                     END
                     IF  (@n_first_comma_flag = 0)
                     BEGIN
                        SELECT @c_buildfieldstring=   dbo.fnc_RTrim(@c_detailprefix) + @c_field
                        SELECT @c_buildfieldstring1 =   @c_field
                        SELECT @n_first_comma_flag = 1
                     END
                  END
                  IF ( @c_firsttime = 'Y')
                  BEGIN 
                     SELECT @c_msg = 'insert ' + dbo.fnc_RTrim(@c_copyto_db) + '..' + dbo.fnc_RTrim(@c_tablename) + '(' + @c_buildfieldstring1
                     SELECT @c_comma = ','
                  END  
                  IF (datalength(@c_msg) > 200)
                  BEGIN 
                     SELECT @c_one   = @c_msg
                     SELECT @c_onea  = ') Select ' + @c_buildfieldstring
                     SELECT @c_firsttime = 'N'
                     SELECT @c_msg = ''
                     SELECT @c_buildfieldstring = ''
                SELECT @c_buildfieldstring1 = ''
                     IF (@b_debug = 1)
                     BEGIN
                        select 'when len > 200  should never happen '
                     END
                  END  
                  SELECT @n_nextrow = @n_nextrow + 1
                  IF (datalength (@c_buildfieldstring)  > 150)
                  BEGIN  
                     IF ( @n_messageno = 1)
                     BEGIN 
                        SELECT @c_one   = @c_msg
                        SELECT @c_onea =  ') Select ' + @c_buildfieldstring
                        IF (@b_debug = 1)
                        BEGIN
                           SELECT 'c_one', @c_one
                           SELECT 'c_one', @c_onea
                           SELECT 'n_messageno', @n_messageno
                        END
                        SELECT @c_buildfieldstring = ''
                        SELECT @c_buildfieldstring1 = ''
                        SELECT @c_firsttime = 'N'
                     END   
                     IF (@n_messageno = 2)
                     BEGIN 
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_two   = @c_buildfieldstring1
                           SELECT @c_twoa  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_two', @c_two
                              SELECT 'c_twoa', @c_twoa
                              SELECT 'n_messageno', @n_messageno
                           END
                           SELECT @c_buildfieldstring = ''
                           SELECT @c_buildfieldstring1 = ''     
                           SELECT @c_msg = ''
                        END
                     END  
                     IF (@n_messageno = 3)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_three   = @c_buildfieldstring1
                           SELECT @c_threea  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_three', @c_three
                              SELECT 'c_threea', @c_threea
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END   
                     IF (@n_messageno = 4)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_four   = @c_buildfieldstring1
                           SELECT @c_foura  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_four', @c_four
                              SELECT 'c_foura', @c_foura
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END  
                     IF (@n_messageno = 5)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_five   = @c_buildfieldstring1
                           SELECT @c_fivea  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_five', @c_five
                              SELECT 'c_fivea', @c_fivea
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END    
                     IF (@n_messageno = 6)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_six   = @c_buildfieldstring1
                           SELECT  @c_sixa  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_six', @c_six
                              SELECT 'c_sixa', @c_sixa
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END    
                     IF (@n_messageno = 7)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_seven   = @c_buildfieldstring1
                           SELECT @c_sevena  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_seven', @c_seven
                              SELECT 'c_sevena', @c_sevena
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END    
                     IF (@n_messageno = 8)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_eight   = @c_buildfieldstring1
                           SELECT  @c_eighta  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_eight', @c_eight
                              SELECT 'c_eighta', @c_eighta
                              SELECT 'n_messageno', @n_messageno
                           END
                        END
                     END     
                     IF (@n_messageno = 9)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT  @c_nine   = @c_buildfieldstring1
                           SELECT  @c_ninea  = @c_buildfieldstring
                           IF (@b_debug = 1)
                           BEGIN
                              SELECT 'c_nine', @c_nine
                              SELECT 'c_ninea', @c_ninea
                           END
                        END
                     END    
                     IF (@n_messageno = 10)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT  @c_ten   = @c_buildfieldstring1
                           SELECT @c_tena  = @c_buildfieldstring
                        END
                     END   
                     IF (@n_messageno = 11)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_eleven   = @c_buildfieldstring1
                           SELECT @c_elevena  = @c_buildfieldstring
                        END
                     END    
                     IF (@n_messageno = 12)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_twelve   = @c_buildfieldstring1
                           SELECT @c_twelvea  = @c_buildfieldstring
                        END
                     END    
                     IF (@n_messageno = 13)
                     BEGIN  
            IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_thirteen   = @c_buildfieldstring1
                           SELECT @c_thirteena  = @c_buildfieldstring
                        END
                     END    
                     IF (@n_messageno = 14)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_fourteen   = @c_buildfieldstring1
                           SELECT @c_fourteena  = @c_buildfieldstring
                        END
                     END     
                     IF (@n_messageno = 15)
                     BEGIN 
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_fifteen   = @c_buildfieldstring1
                           SELECT @c_fifteena  = @c_buildfieldstring
                        END
                     END  
                     IF (@n_messageno = 16)
                     BEGIN  
                        IF (@n_rowcount >= @n_nextrow)
                        BEGIN
                           SELECT @c_sixteen   = @c_buildfieldstring1
                           SELECT @c_sixteena  = @c_buildfieldstring
                        END
                     END    
                     SELECT @c_buildfieldstring = ''
                     SELECT @c_buildfieldstring1 = ''
                     SELECT @c_msg = ''
                     SELECT @n_messageno = @n_messageno + 1
                  END  
               END 
            END 
         END 
      END 
      IF @b_cursoropen = 1
      BEGIN
         Close CUR_INSERT_BUILD
         Deallocate CUR_INSERT_BUILD
      END
   END 
   
   IF (@b_debug = 1)
   BEGIN
      SELECT 'len =',datalength(@c_buildfieldstring), 'out of cursor ', @c_buildfieldstring
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF (datalength(@c_buildfieldstring) > 1 or @n_messageno = 1)
      BEGIN  
         IF (@b_debug = 1)
         BEGIN
            select 'len =',datalength(@c_buildfieldstring), 'out of cursor ', @c_buildfieldstring
            select '@n_messageno =', @n_messageno
         END
         IF ( @n_messageno = 1)
         BEGIN  
            SELECT @c_one   = 'insert ' + dbo.fnc_RTrim(@c_copyto_db) + '..' + dbo.fnc_RTrim(@c_tablename) + '('+
               @c_buildfieldstring1 + ')'
            SELECT @c_onea =  'SELECT ' +@c_buildfieldstring
            SELECT @c_buildfieldstring = ''
       SELECT @c_buildfieldstring1 = ''
         END    
         IF (@n_messageno = 2)
         BEGIN 
            SELECT @c_two   = @c_buildfieldstring1
            SELECT @c_twoa  = @c_buildfieldstring
         END   
         IF (@n_messageno = 3)
         BEGIN  
            SELECT @c_three   = @c_buildfieldstring1
            SELECT @c_threea  = @c_buildfieldstring
         END    
         IF (@n_messageno = 4)
         BEGIN  
            SELECT @c_four   = @c_buildfieldstring1
            SELECT @c_foura  = @c_buildfieldstring
         END    
         IF (@n_messageno = 5)
         BEGIN  
            SELECT @c_five   = @c_buildfieldstring1
            SELECT @c_fivea  = @c_buildfieldstring
         END    
         IF (@n_messageno = 6)
         BEGIN  
            SELECT @c_six   = @c_buildfieldstring1
            SELECT @c_sixa  = @c_buildfieldstring
         END    
         IF (@n_messageno = 7)
         BEGIN  
            SELECT @c_seven   = @c_buildfieldstring1
            SELECT @c_sevena  = @c_buildfieldstring
         END     
         IF (@n_messageno = 8)
         BEGIN   
            SELECT @c_eight   = @c_buildfieldstring1
            SELECT @c_eighta  = @c_buildfieldstring
         END      
         IF (@n_messageno = 9)
         BEGIN    
            SELECT @c_nine   = @c_buildfieldstring1
            SELECT @c_ninea  = @c_buildfieldstring
         END       
         IF (@n_messageno = 10)
         BEGIN  
            SELECT @c_ten   = @c_buildfieldstring1
            SELECT @c_tena  = @c_buildfieldstring
         END      
         IF (@n_messageno = 11)
         BEGIN     
            SELECT @c_eleven   = @c_buildfieldstring1
            SELECT @c_elevena  = @c_buildfieldstring
         END        
         IF (@n_messageno = 12)
         BEGIN  
            SELECT @c_twelve   = @c_buildfieldstring1
            SELECT @c_twelvea  = @c_buildfieldstring
         END      
         IF (@n_messageno = 13)
         BEGIN   
            SELECT @c_thirteen   = @c_buildfieldstring1
            SELECT @c_thirteena  = @c_buildfieldstring
         END      
         IF (@n_messageno = 14)
         BEGIN     
            SELECT @c_fourteen   = @c_buildfieldstring1
            SELECT @c_fourteena  = @c_buildfieldstring
         END        
         IF (@n_messageno = 15)
         BEGIN       
            SELECT @c_fifteen   = @c_buildfieldstring1
            SELECT @c_fifteena  = @c_buildfieldstring
         END            
         IF (@n_messageno = 16)
         BEGIN  
            SELECT @c_sixteen   = @c_buildfieldstring1
            SELECT @c_sixteena  = @c_buildfieldstring
         END      
      END 
   END
 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF (@b_archive <> 1)
      BEGIN
         Select @c_whereclause1 = ""
         Select @c_whereclause2 = ""
      END
      ELSE
      BEGIN
    Select @c_whereclause1 =  " " + @c_whereclause1 
         Select @c_whereclause2 = " " + @c_whereclause2
      END   
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_one                 = dbo.fnc_RTrim(@c_one)
      SELECT @c_two                 = dbo.fnc_RTrim(@c_two)
      SELECT @c_three               = dbo.fnc_RTrim(@c_three)
      SELECT @c_onea                = dbo.fnc_RTrim(@c_onea)
      SELECT @c_twoa                = dbo.fnc_RTrim(@c_twoa)
      SELECT @c_threea              = dbo.fnc_RTrim(@c_threea)
      SELECT @c_tablename           = dbo.fnc_RTrim(@c_tablename)
      SELECT @c_four                =  dbo.fnc_RTrim(@c_four)
      SELECT @c_foura               =  dbo.fnc_RTrim(@c_foura)
      SELECT @c_five                =  dbo.fnc_RTrim(@c_five)
      SELECT @c_fivea               =  dbo.fnc_RTrim(@c_fivea)
      SELECT @c_six                 =  dbo.fnc_RTrim(@c_six)
      SELECT @c_sixa                =  dbo.fnc_RTrim(@c_sixa)
      SELECT @c_seven               =  dbo.fnc_RTrim(@c_seven)
      SELECT @c_sevena              =  dbo.fnc_RTrim(@c_sevena)
      SELECT @c_eight               =  dbo.fnc_RTrim(@c_eight)
      SELECT @c_eighta              =  dbo.fnc_RTrim(@c_eighta)
      SELECT @c_nine                =  dbo.fnc_RTrim(@c_nine)
      SELECT @c_ninea               =  dbo.fnc_RTrim(@c_ninea)
      SELECT @c_ten                 =  dbo.fnc_RTrim(@c_ten)
      SELECT @c_tena                =  dbo.fnc_RTrim(@c_tena)
      SELECT @c_eleven              =  dbo.fnc_RTrim(@c_eleven)
      SELECT @c_elevena             =  dbo.fnc_RTrim(@c_elevena)
      SELECT @c_twelve              =  dbo.fnc_RTrim(@c_twelve)
      SELECT @c_twelvea             =  dbo.fnc_RTrim(@c_twelvea)
      SELECT @c_thirteen            =  dbo.fnc_RTrim(@c_thirteen)
      SELECT @c_thirteena           =  dbo.fnc_RTrim(@c_thirteena)
      SELECT @c_fourteen            =  dbo.fnc_RTrim(@c_fourteen)
      SELECT @c_fourteena           =  dbo.fnc_RTrim(@c_fourteena)
      SELECT @c_fifteen             =  dbo.fnc_RTrim(@c_fifteen)
      SELECT @c_fifteena            =  dbo.fnc_RTrim(@c_fifteena)
      SELECT @c_sixteen             =  dbo.fnc_RTrim(@c_sixteen)
      SELECT @c_sixteena            =  dbo.fnc_RTrim(@c_sixteena)
      IF (@b_debug = 1)
      BEGIN
         select 'one', @c_one
         select 'two', @c_two
         select 'three',@c_three
         select 'onea', @c_onea
         select 'twoa', @c_twoa
         select 'threea',@c_threea
         select 'four', @c_four
         select 'foura',@c_foura
         select 'from'
         select 'tablename',@c_tablename
         select 'whereclause',@c_whereclause1
         select 'whereclause2',@c_whereclause2
      END

      exec (@c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+
      @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen +
      @c_sixteen +  @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+
      @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +
      @c_fourteena +  @c_fifteena + @c_sixteena +
      ' From ' + @c_tablename + " (nolock) " + @c_tablename2 + @c_whereclause1 + @c_whereclause2)

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN  
         SELECT @n_continue = 3
         SELECT @n_err = 73504
         SELECT @c_errmsg = CONVERT(char(250),@n_err)
            + ":  dynamic execute failed. (nsp_Build_LogInsert) " + " ( " +
            " SQLSvr MESSAGE = " + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ")"
      END  
   END
  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_Build_LogInsert"
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
END



GO