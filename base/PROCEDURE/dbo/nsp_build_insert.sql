SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc : nsp_Build_Insert                                       */  
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
/* 2005-Aug-15  Shong         add nolock when building the insert       */  
/*                            statement.                                */  
/* 2005-Nov-16  Shong         Build Insert String to insert only when   */  
/*                            Records not Exists in Archive Table       */  
/*                            Pls deploy together with SP               */  
/*                            ispPrimaryKeyColumns                      */  
/* 2005-Dec-01  Shong         Delete the Records when record sucessfully*/  
/*                            inserted into Archive DB                  */  
/* 2005-Dec-12  Shong         Increase Variable @c_msg to 512 chars     */  
/* 2011-Jul-18  TLTING        Bug fix for new version (tlting01)        */  
/* 2012-May-29  TLTING        Perormance Tune (tlting02)                */   
/* 2014-Dec-29  TLTING        Bug fix (tlting03)                        */   
/* 2015-Jun-25  KHLim         increase 255 to 500; 150 to 300 (KHLim01) */   
/* 2015-Oct-13  SHONG         Change fnc_Rtrim back to RTRIM            */
/************************************************************************/  
CREATE PROCEDURE [dbo].[nsp_Build_Insert]  
               @c_copyto_db    NVARCHAR(50)       
,              @c_tablename    NVARCHAR(50)       
,              @b_archive      int               
,              @b_Success      int           OUTPUT      
,              @n_err          int           OUTPUT      
,              @c_errmsg       NVARCHAR(250) OUTPUT      
AS  
BEGIN   
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE @n_continue  int        ,    
           @n_starttcnt int        , -- Holds the current transaction count  
           @n_cnt       int        , -- Holds @@ROWCOUNT after certain operations  
           @b_debug     int          -- Debug On Or Off  
   DECLARE @n_rowcount          INTEGER           
   DECLARE @n_nextrow           INTEGER           
   DECLARE @c_msg               NVARCHAR(512)      
   DECLARE @c_field             NVARCHAR(50)       
   DECLARE @c_buildfieldstring  NVARCHAR(500)    --KHLim01  
   DECLARE @c_firsttime         NVARCHAR(1)           
   DECLARE @c_one               NVARCHAR(500)      
   DECLARE @c_onea              NVARCHAR(500)  
   DECLARE @c_two               NVARCHAR(500)      
   DECLARE @c_twoa              NVARCHAR(500)      
   DECLARE @c_three             NVARCHAR(500)  
   DECLARE @c_threea            NVARCHAR(500)  
   DECLARE @c_four              NVARCHAR(500)  
   DECLARE @c_foura             NVARCHAR(500)  
   DECLARE @c_five              NVARCHAR(500)  
   DECLARE @c_fivea             NVARCHAR(500)  
   DECLARE @c_six               NVARCHAR(500)  
   DECLARE @c_sixa              NVARCHAR(500)  
   DECLARE @c_seven             NVARCHAR(500)  
   DECLARE @c_sevena            NVARCHAR(500)  
   DECLARE @c_eight             NVARCHAR(500)  
   DECLARE @c_eighta            NVARCHAR(500)  
   DECLARE @c_nine              NVARCHAR(500)  
   DECLARE @c_ninea             NVARCHAR(500)  
   DECLARE @c_ten               NVARCHAR(500)  
   DECLARE @c_tena              NVARCHAR(500)  
   DECLARE @c_eleven            NVARCHAR(500)  
   DECLARE @c_elevena           NVARCHAR(500)  
   DECLARE @c_twelve            NVARCHAR(500)  
   DECLARE @c_twelvea           NVARCHAR(500)  
   DECLARE @c_thirteen          NVARCHAR(500)  
   DECLARE @c_thirteena         NVARCHAR(500)  
   DECLARE @c_fourteen          NVARCHAR(500)  
   DECLARE @c_fourteena         NVARCHAR(500)  
   DECLARE @c_fifteen           NVARCHAR(500)  
   DECLARE @c_fifteena          NVARCHAR(500)  
   DECLARE @c_sixteen           NVARCHAR(500)  
   DECLARE @c_sixteena          NVARCHAR(500)  
   DECLARE @n_messageno         int               
   DECLARE @c_comma             NVARCHAR(1)           
   DECLARE @c_parenset          NVARCHAR(1)           
   DECLARE @n_length            smallint          -- tltig01 tinyint           
   DECLARE @c_typename          NVARCHAR(32)       
   DECLARE @c_exist             NVARCHAR(500)      
   DECLARE @c_exist1            NVARCHAR(500)  
   DECLARE @c_SQL               NVARCHAR(MAX)   --KHLim01  
   DECLARE @c_whereclause       NVARCHAR(25)       
   DECLARE @user_type           smallint           
   DECLARE @n_first_comma_flag  int  
     
   SELECT @n_first_comma_flag = 0  
   SET NOCOUNT ON  
     
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
   SELECT @c_sixteen = ISNULL(RTRIM(@c_copyto_db),'') + '..' + ISNULL(RTRIM(@c_tablename),'')  
     
   IF  OBJECT_ID( @c_sixteen) is NULL  
   BEGIN   
      SELECT @n_continue = 3  -- No need to continue if table does not exist in to database  
      SELECT @n_continue = 3  
      SELECT @n_err = 73500  
      SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":Table does not exist in Target Database " +  
         @c_tablename + "(nsp_Build_Insert)"  
   END     
     
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @n_rowcount = count(sys.syscolumns.name)  
      FROM    sys.sysobjects, sys.syscolumns  
      WHERE   sys.sysobjects.id = sys.syscolumns.id  
         AND     sys.sysobjects.name = @c_tablename  
      IF (@n_rowcount <= 0)  
      BEGIN    
         SELECT @n_continue = 3  
         SELECT @n_err = 73501  
         SELECT @c_errmsg = "NSQL " + CONVERT(char(5),@n_err)+":No rows or columns found for " +  
            ISNULL(RTRIM(@c_tablename),'') + "(nsp_Build_Insert)"  
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
      SELECT sys.syscolumns.name,  sys.syscolumns.length, sys.syscolumns.usertype, sys.systypes.name   
      FROM   sys.sysobjects WITH (NOLOCK)   
      JOIN   sys.syscolumns WITH (NOLOCK) ON sys.sysobjects.id = sys.syscolumns.id  
      JOIN   sys.systypes WITH (NOLOCK) ON sys.syscolumns.xusertype = sys.systypes.xusertype   
      WHERE sys.sysobjects.name =  @c_tablename  
      ORDER By sys.syscolumns.colorder  
  
      OPEN CUR_INSERT_BUILD  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN    
         SELECT @n_continue = 3  
         SELECT @n_err = 73502  
         SELECT @c_errmsg = CONVERT(char(250),@n_err)  
            + ":  Open of cursor failed. (nsp_Build_Insert) " + " ( " +  
            " SQLSvr MESSAGE = " + ISNULL(RTRIM(@c_errmsg),'') + ")"  
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
               + ":  fetch failed. (nsp_Build_Insert) " + " ( " +  
               " SQLSvr MESSAGE = " + ISNULL(RTRIM(@c_errmsg),'') + ")"  
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
                  IF (ISNULL(RTRIM(@c_typename),'') <> 'TimeStamp')  
                  BEGIN  
                     IF (@n_first_comma_flag = 1)  
                     BEGIN  
                        SELECT @c_buildfieldstring =  @c_buildfieldstring + @c_comma + '[' + @c_field + ']'   -- tlting03  
                     END  
                     IF  (@n_first_comma_flag = 0)  
                     BEGIN  
                        SELECT @c_buildfieldstring =  '[' + @c_field + ']'   -- tlting03  
                        SELECT @n_first_comma_flag = 1  
                     END  
                  END  
                  IF ( @c_firsttime = 'Y')  
                  BEGIN   
                     SELECT @c_msg  = 'INSERT ' + ISNULL(RTRIM(@c_copyto_db),'') + '..' + ISNULL(RTRIM(@c_tablename),'') + '(' + @c_buildfieldstring  
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
                        select 'when len > 500  should never happen '  
                     END  
                  END    
                  SELECT @n_nextrow = @n_nextrow + 1  
                  IF (datalength (@c_buildfieldstring)  > 300) --KHLim01  
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
            SELECT @c_one   = 'INSERT ' + ISNULL(RTRIM(@c_copyto_db),'') + '..' + ISNULL(RTRIM(@c_tablename),'') + '('+  
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
     
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF (@b_archive = 1)  
      BEGIN  
         Select @c_whereclause = " Where archivecop = '9' "  
      END  
      ELSE  
      BEGIN  
         Select @c_whereclause = ''  
      END  
   END  
     
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      SELECT @c_one                 =  ISNULL(RTRIM(@c_one),'')  
      SELECT @c_two                 =  ISNULL(RTRIM(@c_two),'')  
      SELECT @c_three               =  ISNULL(RTRIM(@c_three),'')  
      SELECT @c_onea                =  ISNULL(RTRIM(@c_onea),'')  
      SELECT @c_twoa                =  ISNULL(RTRIM(@c_twoa),'')  
      SELECT @c_threea              =  ISNULL(RTRIM(@c_threea),'')  
      SELECT @c_tablename           =  ISNULL(RTRIM(@c_tablename),'')  
      SELECT @c_four                =  ISNULL(RTRIM(@c_four),'')  
      SELECT @c_foura               =  ISNULL(RTRIM(@c_foura),'')  
      SELECT @c_five                =  ISNULL(RTRIM(@c_five),'')  
      SELECT @c_fivea               =  ISNULL(RTRIM(@c_fivea),'')  
      SELECT @c_six                 =  ISNULL(RTRIM(@c_six),'')  
      SELECT @c_sixa                =  ISNULL(RTRIM(@c_sixa),'')  
      SELECT @c_seven               =  ISNULL(RTRIM(@c_seven),'')  
      SELECT @c_sevena              =  ISNULL(RTRIM(@c_sevena),'')  
      SELECT @c_eight               =  ISNULL(RTRIM(@c_eight),'')  
      SELECT @c_eighta              =  ISNULL(RTRIM(@c_eighta),'')  
      SELECT @c_nine                =  ISNULL(RTRIM(@c_nine),'')  
      SELECT @c_ninea               =  ISNULL(RTRIM(@c_ninea),'')  
      SELECT @c_ten                 =  ISNULL(RTRIM(@c_ten),'')  
      SELECT @c_tena                =  ISNULL(RTRIM(@c_tena),'')  
      SELECT @c_eleven              =  ISNULL(RTRIM(@c_eleven),'')  
      SELECT @c_elevena             =  ISNULL(RTRIM(@c_elevena),'')  
      SELECT @c_twelve              =  ISNULL(RTRIM(@c_twelve),'')  
      SELECT @c_twelvea             =  ISNULL(RTRIM(@c_twelvea),'')  
      SELECT @c_thirteen            =  ISNULL(RTRIM(@c_thirteen),'')  
      SELECT @c_thirteena           =  ISNULL(RTRIM(@c_thirteena),'')  
      SELECT @c_fourteen            =  ISNULL(RTRIM(@c_fourteen),'')  
      SELECT @c_fourteena           =  ISNULL(RTRIM(@c_fourteena),'')  
      SELECT @c_fifteen             =  ISNULL(RTRIM(@c_fifteen),'')  
      SELECT @c_fifteena            =  ISNULL(RTRIM(@c_fifteena),'')  
      SELECT @c_sixteen             =  ISNULL(RTRIM(@c_sixteen),'')  
      SELECT @c_sixteena            =  ISNULL(RTRIM(@c_sixteena),'')  
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
  
      IF OBJECT_ID('tempdb..#PrimaryKey') IS NOT NULL   
         DROP TABLE #PrimaryKey  
  
      CREATE TABLE #PrimaryKey (ColName sysname, SeqNo int, RowID int IDENTITY )  
        
      INSERT INTO #PrimaryKey (ColName, SeqNo)  
      EXEC ispPrimaryKeyColumns @c_tablename  
  
      IF EXISTS(SELECT 1 FROM #PrimaryKey)   
      BEGIN  
         SELECT @cSQL1 = ' SET NOCOUNT ON ' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key1 NVARCHAR(20), @key2 NVARCHAR(20), @key3 NVARCHAR(20), @key4 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key5 NVARCHAR(20), @key6 NVARCHAR(20), @key7 NVARCHAR(20), @key8 NVARCHAR(20)' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + ' DECLARE C_RECORDS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + '    SELECT '   
         SELECT @cFetchSQL = ' FETCH NEXT FROM C_RECORDS INTO '  
         SELECT @cWhereSQL = ' WHERE '   
  
         DECLARE C_PrimaryKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT ColName, RowID    
         FROM   #PrimaryKey   
         ORDER BY RowID   
  
         OPEN C_PrimaryKey   
     
         FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
  
            SELECT @cSQL1 = @cSQL1 + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + ' ' + ISNULL(RTRIM(@cPrimaryKey),'')     
            SELECT @cFetchSQL = @cFetchSQL + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + '@Key' + RTRIM(CAST(@nRowId as NVARCHAR(2)))   
                    
  
            SELECT @cWhereSQL = @cWhereSQL + CASE WHEN @nRowId > 1 THEN ' AND ' ELSE '' END  + ISNULL(RTRIM(@cPrimaryKey),'') + ' = @Key'   
               + RTRIM(CAST(@nRowId as NVARCHAR(2)))   
                    
            FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId   
         END   
           
         CLOSE C_PrimaryKey  
         DEALLOCATE C_PrimaryKey   
  
         SELECT @cSQL1 = @cSQL1 + ' FROM ' + ISNULL(RTRIM(@c_tablename),'') + ' (NOLOCK) ' + @c_whereclause  + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + ' OPEN C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)  
         SELECT @cSQL1 = @cSQL1 + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)                 
         SELECT @cSQL1 = @cSQL1 + ' WHILE @@FETCH_STATUS <> -1 ' + master.dbo.fnc_GetCharASCII(13)           
         SELECT @cSQL1 = @cSQL1 + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)        
         SELECT @cSQL1 = @cSQL1 + '    IF NOT EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@c_copyto_db),'') + '.dbo.'   
                + ISNULL(RTRIM(@c_tablename),'')  + ' (NOLOCK) '     --tlting02  
         SELECT @cSQL1 = @cSQL1 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)        
         SELECT @cSQL1 = @cSQL1 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL1 = @cSQL1 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)    
  
         SELECT @cSQL2 =          '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)   
----  
         SELECT @cSQL2 = @cSQL2 + '    IF EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@c_copyto_db),'') + '.dbo.' + ISNULL(RTRIM(@c_tablename),'') + ' (NOLOCK) '     --tlting02  
         SELECT @cSQL2 = @cSQL2 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)     
         SELECT @cSQL2 = @cSQL2 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + '       DELETE FROM ' + ISNULL(RTRIM(@c_tablename),'') + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)     
         SELECT @cSQL2 = @cSQL2 + '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)            
---   
         SELECT @cSQL2 = @cSQL2 + '   ' + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)   
         SELECT @cSQL2 = @cSQL2 + ' END ' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + ' CLOSE C_RECORDS' + master.dbo.fnc_GetCharASCII(13)    
         SELECT @cSQL2 = @cSQL2 + ' DEALLOCATE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)   
     
         --KHLim01  
         SELECT @c_SQL =          '        ' + @c_one +@c_two +@c_three +@c_four +@c_five +@c_six +@c_seven +  
                        @c_eight +@c_nine +@c_ten +@c_eleven +@c_twelve +@c_thirteen +@c_fourteen +@c_fifteen +@c_sixteen  
         SELECT @c_SQL = @c_SQL + '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+  
                        @c_eighta+@c_ninea+@c_tena+@c_elevena+@c_twelvea+@c_thirteena+@c_fourteena+@c_fifteena+@c_sixteena  
         SELECT @c_SQL = @c_SQL + ' FROM ' + @c_tablename + ' (NOLOCK) ' + @cWhereSQL +   
                        @cSQL2  
  
         EXEC( @cSQL1 + @c_SQL )  
  
  
         IF (@b_debug = 1)  
         BEGIN  
            print @cSQL1 + master.dbo.fnc_GetCharASCII(13) + @c_SQL  
         END  
      END -- Primary Key Exists  
      ELSE  
      BEGIN  
         SELECT @c_SQL = @c_one +@c_two +@c_three +@c_four +@c_five +@c_six +@c_seven +  
                         @c_eight +@c_nine +@c_ten +@c_eleven +@c_twelve +@c_thirteen +@c_fourteen +@c_fifteen +@c_sixteen  
         SELECT @c_SQL = @c_SQL + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+  
                         @c_eighta+@c_ninea+@c_tena+@c_elevena+@c_twelvea+@c_thirteena+@c_fourteena+@c_fifteena+@c_sixteena  
         SELECT @c_SQL = @c_SQL + ' From ' + @c_tablename + ' (NOLOCK) '  + @c_whereclause  
  
         EXEC( @c_SQL )    
  
         IF (@b_debug = 1)  
         BEGIN  
            print @c_SQL   
         END   
      END  
  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      IF @n_err <> 0  
      BEGIN    
         SELECT @n_continue = 3  
         SELECT @n_err = 73504  
         SELECT @c_errmsg = CONVERT(char(250),@n_err)  
            + ":  dynamic execute failed. (nsp_Build_Insert) " + " ( " +  
            " SQLSvr MESSAGE = " + ISNULL(RTRIM(@c_errmsg),'') + ")"  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_Build_Insert"  
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