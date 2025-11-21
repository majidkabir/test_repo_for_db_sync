SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Stored Proc : nsp_Build_Insert2                                      */    
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
/* Called By: All Archive Script                                        */    
/*                                                                      */    
/* PVCS Version: 1.9                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 2011-Jul-18  TLTING        Bug fix for new version (tlting01)        */
/************************************************************************/    
CREATE PROCEDURE [dbo].[nsp_Build_Insert2]    
@c_copyto_db    NVARCHAR(50)         
,              @c_tablename    NVARCHAR(50)    
,      @c_KeyColumn    NVARCHAR(50)              
,      @c_whereclause  NVARCHAR(255)              
,              @b_Success      int        OUTPUT        
,              @n_err          int        OUTPUT        
,              @c_errmsg       NVARCHAR(250)  OUTPUT        
AS    
BEGIN     
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
   DECLARE        @n_continue int        ,      
      @n_starttcnt int        , -- Holds the current transaction count    
      @n_cnt int              , -- Holds @@ROWCOUNT after certain operations    
      @b_debug int              -- Debug On Or Off    
   DECLARE @n_rowcount          integer             
   DECLARE @n_nextrow           integer             
   DECLARE @c_msg               NVARCHAR(512)        
   DECLARE @c_field             NVARCHAR(50)         
   DECLARE @c_buildfieldstring  NVARCHAR(255)        
   DECLARE @c_firsttime         NVARCHAR(1)             
   DECLARE @c_one               NVARCHAR(255)        
   DECLARE @c_onea              NVARCHAR(255)    
   DECLARE @c_two     NVARCHAR(255)        
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
   DECLARE @n_length            smallint             
   DECLARE @c_typename          NVARCHAR(32)         
   DECLARE @c_exist             NVARCHAR(255)        
   DECLARE @c_exist1            NVARCHAR(255)    
   --DECLARE @c_whereclause       NVARCHAR(25)         
   DECLARE @user_type           smallint             
   DECLARE @n_first_comma_flag          int    
       
   SELECT @n_first_comma_flag = 0    
   SET NOCOUNT ON    
       
   SELECT @c_comma = ''    
   SELECT @c_parenset = '0'    
   SELECT @n_continue = 1    
   SELECT @b_debug = 1    
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
   SELECT @c_sixteen = RTRIM(@c_copyto_db) + '..' + RTRIM(@c_tablename)    
       
   IF  OBJECT_ID( @c_sixteen) is NULL    
   BEGIN     
      SELECT @n_continue = 3  -- No need to continue if table does not exist in to database    
      SELECT @n_continue = 3    
      SELECT @n_err = 73500    
      SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Table does not exist in Target Database " +    
         @c_tablename + "(nsp_Build_Insert2)"    
   END       
  
   IF ISNULL(@c_whereclause, '') = ''  
   BEGIN     
      SELECT @n_continue = 3  -- No need to continue if table does not exist in to database    
      SELECT @n_continue = 3    
      SELECT @n_err = 73500    
      SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Where Clause can not be blank." +    
         @c_tablename + "(nsp_Build_Insert2)"    
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
            RTRIM(@c_tablename) + "(nsp_Build_Insert2)"    
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
      DECLARE CUR_INSERT_BUILD Cursor FAST_FORWARD READ_ONLY for    
      SELECT syscolumns.name,  syscolumns.length, syscolumns.usertype, systypes.name     
      FROM   sysobjects WITH (NOLOCK)     
         JOIN   syscolumns WITH (NOLOCK) ON sysobjects.id = syscolumns.id    
         JOIN   systypes WITH (NOLOCK) ON sys.syscolumns.xusertype = sys.systypes.xusertype
         -- tlting01  syscolumns.xtype = systypes.xtype    
      WHERE sysobjects.name =  @c_tablename    
      ORDER By syscolumns.colorder    
    
      OPEN CUR_INSERT_BUILD    
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
      IF @n_err <> 0    
      BEGIN      
         SELECT @n_continue = 3    
         SELECT @n_err = 73502    
         SELECT @c_errmsg = CONVERT(char(250),@n_err)    
            + ":  Open of cursor failed. (nsp_Build_Insert2) " + " ( " +    
            " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"    
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
               + ":  fetch failed. (nsp_Build_Insert2) " + " ( " +    
               " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"    
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
                  IF (RTRIM(@c_typename) <> 'TimeStamp')    
                  BEGIN    
                     IF (@n_first_comma_flag = 1)    
                     BEGIN    
                        SELECT @c_buildfieldstring =  @c_buildfieldstring + @c_comma + @c_field    
                     END    
                     IF  (@n_first_comma_flag = 0)    
                     BEGIN    
                        SELECT @c_buildfieldstring =  @c_field    
                        SELECT @n_first_comma_flag = 1    
                     END    
                  END    
                  IF ( @c_firsttime = 'Y')    
                  BEGIN     
                     SELECT @c_msg  = 'INSERT ' + RTRIM(@c_copyto_db) + '..' + RTRIM(@c_tablename) + '(' + @c_buildfieldstring    
                     SELECT @c_comma = ','    
                  END      
                  IF (datalength(@c_msg) > 500)    
                  BEGIN     
                     SELECT @c_one   = @c_msg    
                     SELECT @c_onea  = ') SELECT ' + @c_buildfieldstring    
                     SELECT @c_firsttime = 'N'    
                     SELECT @c_msg = ''    
                     SELECT @c_buildfieldstring = ''    
                     IF (@b_debug = 1)    
                     BEGIN    
                        select 'when len > 200  should never happen '    
                     END    
                  END      
                  SELECT @n_nextrow = @n_nextrow + 1    
                  IF (datalength (@c_buildfieldstring)  > 150)    
                  BEGIN      
                     IF (@b_debug = 1)    
                     BEGIN    
                        select 'bldstring =',@c_buildfieldstring    
                        select 'c_msg =',@c_msg    
                        select '@n_message =',@n_messageno    
                        select 'length of @c_msg =', datalength(@c_msg)    
                        select 'length of @c_buildfieldstring =', datalength(@c_buildfieldstring)    
                        select 'n_nextrow', @n_nextrow    
                        select 'n_rowcount', @n_rowcount    
                     END    
                     IF ( @n_messageno = 1)    
                     BEGIN     
                        SELECT @c_one   = @c_msg    
                        SELECT @c_onea =  ') SELECT ' + @c_buildfieldstring    
                        IF (@b_debug = 1)    
                        BEGIN    
                           SELECT 'c_one', @c_one    
                           SELECT 'c_one', @c_onea    
                           SELECT 'n_messageno', @n_messageno    
                        END    
                        SELECT @c_buildfieldstring = ''    
                        SELECT @c_firsttime = 'N'    
                     END       
                     IF (@n_messageno = 2)    
                     BEGIN     
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_two   = @c_buildfieldstring    
                           SELECT @c_twoa  = @c_buildfieldstring    
                           IF (@b_debug = 1)    
                           BEGIN    
                              SELECT 'c_two', @c_two    
                              SELECT 'c_twoa', @c_twoa    
                              SELECT 'n_messageno', @n_messageno    
                           END    
                           SELECT @c_buildfieldstring = ''    
                           SELECT @c_msg = ''    
                        END    
                     END      
                     IF (@n_messageno = 3)    
                     BEGIN      
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_three   = @c_buildfieldstring    
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
                           SELECT @c_four   = @c_buildfieldstring    
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
                           SELECT @c_five   = @c_buildfieldstring    
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
                           SELECT @c_six   = @c_buildfieldstring    
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
                           SELECT @c_seven   = @c_buildfieldstring    
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
                           SELECT @c_eight   = @c_buildfieldstring    
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
                           SELECT  @c_nine   = @c_buildfieldstring    
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
                           SELECT  @c_ten   = @c_buildfieldstring    
                           SELECT @c_tena  = @c_buildfieldstring    
                        END    
                     END       
                     IF (@n_messageno = 11)    
                     BEGIN      
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_eleven   = @c_buildfieldstring    
                           SELECT @c_elevena  = @c_buildfieldstring    
                        END    
                     END        
                     IF (@n_messageno = 12)    
                     BEGIN      
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_twelve   = @c_buildfieldstring    
                           SELECT @c_twelvea  = @c_buildfieldstring    
                        END    
                     END        
                     IF (@n_messageno = 13)    
                     BEGIN      
                     IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_thirteen   = @c_buildfieldstring    
                           SELECT @c_thirteena  = @c_buildfieldstring    
                        END    
                     END        
                     IF (@n_messageno = 14)    
                     BEGIN      
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_fourteen   = @c_buildfieldstring    
                           SELECT @c_fourteena  = @c_buildfieldstring    
                        END    
                     END         
                     IF (@n_messageno = 15)    
                     BEGIN     
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_fifteen   = @c_buildfieldstring    
                           SELECT @c_fifteena  = @c_buildfieldstring    
                        END    
                     END      
                     IF (@n_messageno = 16)    
                     BEGIN      
                        IF (@n_rowcount >= @n_nextrow)    
                        BEGIN    
                           SELECT @c_sixteen   = @c_buildfieldstring    
                           SELECT @c_sixteena  = @c_buildfieldstring    
                        END    
                     END        
                     SELECT @c_buildfieldstring = ''    
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
            SELECT @c_one   = 'INSERT ' + RTRIM(@c_copyto_db) + '..' + RTRIM(@c_tablename) + '('+    
               @c_buildfieldstring + ')'    
            SELECT @c_onea =  'SELECT ' +@c_buildfieldstring    
            SELECT @c_buildfieldstring = ''    
         END        
         IF (@n_messageno = 2)    
         BEGIN     
            SELECT @c_two   = @c_buildfieldstring    
            SELECT @c_twoa  = @c_buildfieldstring    
         END       
         IF (@n_messageno = 3)    
         BEGIN      
            SELECT @c_three   = @c_buildfieldstring    
            SELECT @c_threea  = @c_buildfieldstring    
         END        
         IF (@n_messageno = 4)    
         BEGIN      
            SELECT @c_four   = @c_buildfieldstring    
            SELECT @c_foura  = @c_buildfieldstring    
         END        
         IF (@n_messageno = 5)    
         BEGIN      
            SELECT @c_five   = @c_buildfieldstring    
            SELECT @c_fivea  = @c_buildfieldstring    
         END        
         IF (@n_messageno = 6)    
         BEGIN      
            SELECT @c_six   = @c_buildfieldstring    
            SELECT @c_sixa  = @c_buildfieldstring    
         END        
         IF (@n_messageno = 7)    
         BEGIN      
            SELECT @c_seven   = @c_buildfieldstring    
            SELECT @c_sevena  = @c_buildfieldstring    
         END         
         IF (@n_messageno = 8)    
         BEGIN       
            SELECT @c_eight   = @c_buildfieldstring    
            SELECT @c_eighta  = @c_buildfieldstring    
         END          
         IF (@n_messageno = 9)    
         BEGIN        
            SELECT @c_nine   = @c_buildfieldstring    
            SELECT @c_ninea  = @c_buildfieldstring    
         END           
         IF (@n_messageno = 10)    
         BEGIN      
            SELECT @c_ten   = @c_buildfieldstring    
            SELECT @c_tena  = @c_buildfieldstring    
         END          
         IF (@n_messageno = 11)    
         BEGIN         
            SELECT @c_eleven   = @c_buildfieldstring    
            SELECT @c_elevena  = @c_buildfieldstring    
         END            
         IF (@n_messageno = 12)    
         BEGIN      
            SELECT @c_twelve   = @c_buildfieldstring    
            SELECT @c_twelvea  = @c_buildfieldstring    
         END          
         IF (@n_messageno = 13)    
         BEGIN       
            SELECT @c_thirteen   = @c_buildfieldstring    
            SELECT @c_thirteena  = @c_buildfieldstring    
         END          
         IF (@n_messageno = 14)    
         BEGIN         
            SELECT @c_fourteen   = @c_buildfieldstring    
            SELECT @c_fourteena  = @c_buildfieldstring    
         END            
         IF (@n_messageno = 15)    
         BEGIN           
            SELECT @c_fifteen   = @c_buildfieldstring    
            SELECT @c_fifteena  = @c_buildfieldstring    
         END                
         IF (@n_messageno = 16)    
         BEGIN      
            SELECT @c_sixteen   = @c_buildfieldstring    
            SELECT @c_sixteena  = @c_buildfieldstring    
         END          
      END     
   END    
 /*      
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      IF (@b_archive = 1)    
      BEGIN    
         Select @c_whereclause = ""--" Where archivecop = '9' "    
      END    
      ELSE    
      BEGIN    
         Select @c_whereclause = ''    
      END    
   END    
   */    
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      SELECT @c_one                 = RTRIM(@c_one)    
      SELECT @c_two                 = RTRIM(@c_two)    
      SELECT @c_three               = RTRIM(@c_three)    
      SELECT @c_onea                = RTRIM(@c_onea)    
      SELECT @c_twoa                = RTRIM(@c_twoa)    
      SELECT @c_threea              = RTRIM(@c_threea)    
      SELECT @c_tablename           = RTRIM(@c_tablename)    
      SELECT @c_four                =  RTRIM(@c_four)    
      SELECT @c_foura               =  RTRIM(@c_foura)    
      SELECT @c_five                =  RTRIM(@c_five)    
      SELECT @c_fivea               =  RTRIM(@c_fivea)    
      SELECT @c_six                 =  RTRIM(@c_six)    
      SELECT @c_sixa                =  RTRIM(@c_sixa)    
      SELECT @c_seven               =  RTRIM(@c_seven)    
      SELECT @c_sevena              =  RTRIM(@c_sevena)    
      SELECT @c_eight               =  RTRIM(@c_eight)    
      SELECT @c_eighta              =  RTRIM(@c_eighta)    
      SELECT @c_nine                =  RTRIM(@c_nine)    
      SELECT @c_ninea               =  RTRIM(@c_ninea)    
      SELECT @c_ten                 =  RTRIM(@c_ten)    
      SELECT @c_tena                =  RTRIM(@c_tena)    
      SELECT @c_eleven              =  RTRIM(@c_eleven)    
      SELECT @c_elevena             =  RTRIM(@c_elevena)    
      SELECT @c_twelve              =  RTRIM(@c_twelve)    
      SELECT @c_twelvea             =  RTRIM(@c_twelvea)    
      SELECT @c_thirteen            =  RTRIM(@c_thirteen)    
      SELECT @c_thirteena           =  RTRIM(@c_thirteena)    
      SELECT @c_fourteen            =  RTRIM(@c_fourteen)    
      SELECT @c_fourteena           =  RTRIM(@c_fourteena)    
      SELECT @c_fifteen             =  RTRIM(@c_fifteen)    
      SELECT @c_fifteena            =  RTRIM(@c_fifteena)    
      SELECT @c_sixteen             =  RTRIM(@c_sixteen)    
      SELECT @c_sixteena            =  RTRIM(@c_sixteena)    
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
         select 'whereclause',@c_whereclause    
      END    
    
      DECLARE @cPrimaryKey NVARCHAR(128),    
              @cSQL1       NVARCHAR(max),    
              @cSQL2       NVARCHAR(max),    
              @cSQL3       NVARCHAR(max),    
              @nRowId      int,    
              @cFetchSQL   NVARCHAR(max),    
              @cWhereSQL   NVARCHAR(max)                  
    
--      IF OBJECT_ID('tempdb..#PrimaryKey') IS NOT NULL     
--         DROP TABLE #PrimaryKey    
    
--      CREATE TABLE #PrimaryKey (ColName sysname, SeqNo int, RowID int IDENTITY )    
          
--      INSERT INTO #PrimaryKey (ColName, SeqNo)    
--      EXEC ispPrimaryKeyColumns @c_tablename    
    
--      IF EXISTS(SELECT 1 FROM #PrimaryKey)     
      BEGIN    
         SELECT @cSQL1 = ' SET NOCOUNT ON ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key1 NVARCHAR(20), @key2 NVARCHAR(20), @key3 NVARCHAR(20), @key4 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key5 NVARCHAR(20), @key6 NVARCHAR(20), @key7 NVARCHAR(20), @key8 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + ' DECLARE C_RECORDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + '    SELECT '     
         SELECT @cFetchSQL = ' FETCH NEXT FROM C_RECORDS INTO '  + '@Key1 ' + master.dbo.fnc_GetCharASCII(13)   
         SELECT @cWhereSQL = ' WHERE ' + @c_KeyColumn + ' = @Key1 '     
  
         SELECT @cSQL1 = @cSQL1 + @c_KeyColumn + master.dbo.fnc_GetCharASCII(13)    
  
 --        SELECT @cWhereSQL = @cWhereSQL + @c_KeyColumn + ' = @Key1 '     
  
    
         SELECT @cSQL1 = @cSQL1 + ' FROM ' + RTRIM(@c_tablename) + ' (NOLOCK) WHERE ' + @c_whereclause  + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + ' OPEN C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)                   
         SELECT @cSQL1 = @cSQL1 + ' WHILE @@FETCH_STATUS <> -1 ' + master.dbo.fnc_GetCharASCII(13)             
         SELECT @cSQL1 = @cSQL1 + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)          
         SELECT @cSQL1 = @cSQL1 + '    IF NOT EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.dbo.'     
                + RTRIM(@c_tablename)  + ' (NOLOCK) '   
         SELECT @cSQL1 = @cSQL1 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)          
         SELECT @cSQL1 = @cSQL1 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL1 = @cSQL1 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)      
    
         SELECT @cSQL2 =          '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)     
----    
         SELECT @cSQL2 = @cSQL2 + '    IF EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.dbo.' + RTRIM(@c_tablename)  + ' (NOLOCK) '     
         SELECT @cSQL2 = @cSQL2 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)       
         SELECT @cSQL2 = @cSQL2 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + '       DELETE FROM ' + RTRIM(@c_tablename) + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)       
         SELECT @cSQL2 = @cSQL2 + '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)              
---     
         SELECT @cSQL2 = @cSQL2 + '   ' + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)     
         SELECT @cSQL2 = @cSQL2 + ' END ' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + ' CLOSE C_RECORDS' + master.dbo.fnc_GetCharASCII(13)      
         SELECT @cSQL2 = @cSQL2 + ' DEALLOCATE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)     
  
      
         EXEC( @cSQL1 +     
               '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+    
               @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen +     
               '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+    
               @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +    
               @c_fourteena +  @c_fifteena + @c_sixteena +    
               ' FROM ' + @c_tablename + ' (NOLOCK) ' + @cWhereSQL +     
               @cSQL2 )    
    
    
         IF (@b_debug = 1)    
         BEGIN    
            print @cSQL1 + master.dbo.fnc_GetCharASCII(13) +     
                  '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+    
                  @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen + master.dbo.fnc_GetCharASCII(13) +     
                  '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+    
                 @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +    
                  @c_fourteena +  @c_fifteena + @c_sixteena +    
                  ' FROM ' + RTRIM(@c_tablename) + ' (NOLOCK) ' + @cWhereSQL + master.dbo.fnc_GetCharASCII(13) +    
                  @cSQL2     
         END    
      END -- Primary Key Exists    
  
    
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
      IF @n_err <> 0    
      BEGIN      
         SELECT @n_continue = 3    
         SELECT @n_err = 73504    
         SELECT @c_errmsg = CONVERT(char(250),@n_err)    
            + ":  dynamic execute failed. (nsp_Build_Insert2) " + " ( " +    
            " SQLSvr MESSAGE = " + LTRIM(RTRIM(@c_errmsg)) + ")"    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_Build_Insert2"    
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