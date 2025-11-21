SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/************************************************************************************/  
/* Stored Proc : dbo.nsp_Build_Insert_GENERIC                                       */  
/* Creation Date:  2 August 2016                                                    */  
/* Copyright: IDS                                                                   */  
/* Written by:  JayLim                                                              */  
/*                                                                                  */  
/* Purpose:                                                                         */  
/*                                                                                  */  
/* Called By: All Archive Script                                                    */  
/*                                                                                  */  
/* Data Modifications:                                                              */  
/*                                                                                  */  
/* Updates:                                                                         */  
/* Date         Author            Purposes                                          */  
/* 21-Dec-2018  TLTING01      1.1 Increase variable length for more column          */  
/* 24-Mar-2019  TLTING02      1.2 datalength bug fix                                */  
/* 24-Mar-2020  TLTING03      1.3 key datalength data type uniqueidentifier         */  
/* 2023-03-19   kelvinongcy   1.4 syntax error fix support square bracket (kocy01)  */  
/* 2023-03-19   kelvinongcy   1.5 support alternative target tablename (kocy02)     */  
/* 2023-07-20   kelvinongcy   1.6 add (nolock)	(kocy03)										*/ 
/************************************************************************************/  
CREATE    PROCEDURE [dbo].[nsp_Build_Insert_GENERIC]    
(    
@c_schema         NVARCHAR(10),              
@c_copyto_db      NVARCHAR(50),                        
@c_SrcTableName   NVARCHAR(150),      
@c_TgtTableName   NVARCHAR(150),         --kocy02      
@b_archive        int,                            
@b_Success        int            OUTPUT,                           
@n_err            int            OUTPUT,                            
@c_errmsg         NVARCHAR(250)  OUTPUT    
)    
AS                
BEGIN                 
   SET NOCOUNT ON                
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                 
   DECLARE  @n_continue int        ,                  
            @n_starttcnt int       , -- Holds the current transaction count                
            @n_cnt int             , -- Holds @@ROWCOUNT after certain operations                
            @b_debug int           -- Debug On Or Off                
        
   DECLARE @n_rowcount          integer                         
   DECLARE @n_nextrow           integer                         
   DECLARE @c_msg               NVARCHAR(1024)                    
   DECLARE @c_field             NVARCHAR(100)                     
   DECLARE @c_buildfieldstring  NVARCHAR(4000)                    
   DECLARE @c_firsttime         NVARCHAR(1)                         
   DECLARE @c_one               NVARCHAR(1000)                    
   DECLARE @c_onea              NVARCHAR(1000)                
   DECLARE @c_two               NVARCHAR(1000)                    
   DECLARE @c_twoa              NVARCHAR(1000)                    
   DECLARE @c_three             NVARCHAR(1000)                
   DECLARE @c_threea            NVARCHAR(1000)                
   DECLARE @c_four              NVARCHAR(1000)                
   DECLARE @c_foura             NVARCHAR(1000)                
   DECLARE @c_five              NVARCHAR(1000)                
   DECLARE @c_fivea             NVARCHAR(1000)                
   DECLARE @c_six NVARCHAR(1000)                
   DECLARE @c_sixa              NVARCHAR(1000)                
   DECLARE @c_seven             NVARCHAR(1000)                
   DECLARE @c_sevena            NVARCHAR(1000)                
   DECLARE @c_eight             NVARCHAR(1000)                
   DECLARE @c_eighta            NVARCHAR(1000)                
   DECLARE @c_nine              NVARCHAR(1000)                
   DECLARE @c_ninea             NVARCHAR(1000)                
   DECLARE @c_ten               NVARCHAR(1000)                
   DECLARE @c_tena              NVARCHAR(1000)                
   DECLARE @c_eleven            NVARCHAR(1000)                
   DECLARE @c_elevena           NVARCHAR(1000)                
   DECLARE @c_twelve            NVARCHAR(1000)                
   DECLARE @c_twelvea           NVARCHAR(1000)                
   DECLARE @c_thirteen          NVARCHAR(1000)                
   DECLARE @c_thirteena         NVARCHAR(1000)                
   DECLARE @c_fourteen          NVARCHAR(1000)                
   DECLARE @c_fourteena         NVARCHAR(1000)                
   DECLARE @c_fifteen           NVARCHAR(1000)                
   DECLARE @c_fifteena          NVARCHAR(1000)                
   DECLARE @c_sixteen           NVARCHAR(1000)                
   DECLARE @c_sixteena          NVARCHAR(1000)             
               
   DECLARE @n_messageno         int                             
   DECLARE @c_comma             NVARCHAR(1)                         
   DECLARE @c_parenset          NVARCHAR(1)                         
   DECLARE @n_length            int                                   
   DECLARE @c_typename          NVARCHAR(32)                     
   DECLARE @c_exist             NVARCHAR(255)                    
   DECLARE @c_exist1            NVARCHAR(255)                
   DECLARE @c_whereclause       NVARCHAR(255)                     
   DECLARE @user_type           smallint                         
   DECLARE @n_first_comma_flag          int,              
           @c_FulltableName     NVARCHAR(100)              
                         
                           
   SET @c_FulltableName = RTRIM(@c_schema) + '.' + RTRIM(@c_SrcTableName)              
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
   SELECT @c_sixteena     =  ' '             
            
   SELECT @c_sixteen = rtrim(@c_copyto_db) + '.' +rtrim(@c_schema)+ '.' + rtrim(@c_TgtTableName)    --kocy02                
                   
   IF  OBJECT_ID( @c_sixteen) is NULL                
   BEGIN                 
 SELECT @n_continue = 3  -- No need to continue if table does not exist in to database                
      SELECT @n_continue = 3                
      SELECT @n_err = 73500                
      SELECT @c_errmsg = 'NSQL ' + CONVERT(char(5),@n_err)+':Table does not exist in Target Database ' +                
         @c_TgtTableName + '(dbo.nsp_Build_Insert_GENERIC)'    --kocy02      
   END                   
                   
   IF @n_continue = 1 or @n_continue = 2                
   BEGIN                
      SELECT @n_rowcount = count(sys.syscolumns.name)                
      FROM sys.sysobjects, sys.syscolumns                
      WHERE sys.sysobjects.id = sys.syscolumns.id                
         AND sys.sysobjects.name = @c_SrcTableName                
         AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName)         
               
      IF (@n_rowcount <= 0)                
      BEGIN                  
         SELECT @n_continue = 3                
         SELECT @n_err = 73501                
         SELECT @c_errmsg = 'NSQL ' + CONVERT(char(5),@n_err)+':No rows or columns found for ' +                
            rtrim(@c_SrcTableName) + '(dbo.nsp_Build_Insert_GENERIC)'              
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
      -- tlting01 -- sys.syscolumns.xtype = sys.systypes.xtype                
      WHERE sys.sysobjects.name =  @c_SrcTableName                
      AND sys.sysobjects.id = OBJECT_ID(@c_FulltableName)              
      ORDER By sys.syscolumns.colorder                
              
      OPEN CUR_INSERT_BUILD                
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                
      IF @n_err <> 0                
      BEGIN                  
         SELECT @n_continue = 3                
         SELECT @n_err = 73502                
         SELECT @c_errmsg = CONVERT(char(250),@n_err)                
            + ':  Open of cursor failed. (dbo.nsp_Build_Insert_GENERIC) ' + ' ( ' +                
            ' SQLSvr MESSAGE = ' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ')'                 
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
      + ':  fetch failed. (dbo.nsp_Build_Insert_GENERIC) ' + ' ( ' +                
               ' SQLSvr MESSAGE = ' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ')'                
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
                  IF (rtrim(@c_typename) <> 'TimeStamp')           
                  BEGIN                
                     IF (@n_first_comma_flag = 1)                
                     BEGIN                
                        SELECT @c_buildfieldstring =  @c_buildfieldstring + @c_comma + '[' + @c_field + ']'  --kocy01                
                     END                
                     IF  (@n_first_comma_flag = 0)                
                     BEGIN                
                      SELECT @c_buildfieldstring =  '[' + @c_field + ']'       --kocy01         
                        SELECT @n_first_comma_flag = 1                
                     END                
                  END                
                  IF ( @c_firsttime = 'Y')                
                  BEGIN                 
                     SELECT @c_msg  = 'INSERT ' + rtrim(@c_copyto_db) + '.' + rtrim(@c_schema)+ '.' + rtrim(@c_TgtTableName) + '(' + @c_buildfieldstring       --kocy02         
                     SELECT @c_comma = ','                
                  END                  
                  IF (datalength(@c_msg) > 2000)     --tlting02            
                  BEGIN                 
                     SELECT @c_one   = @c_msg                
                     SELECT @c_onea  = ') SELECT ' + @c_buildfieldstring                
                     SELECT @c_firsttime = 'N'                
                     SELECT @c_msg = ''                
                     SELECT @c_buildfieldstring = ''                
                     IF (@b_debug = 1)                
                     BEGIN                
                         select 'when len > 2000  should never happen '                
                     END                
                  END                  
                  SELECT @n_nextrow = @n_nextrow + 1                
                  IF (datalength (@c_buildfieldstring)  > 900)                
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
                     BEGIN                                        IF (@n_rowcount >= @n_nextrow)                
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
            SELECT @c_one   = 'INSERT ' + rtrim(@c_copyto_db) + '.' + rtrim(@c_schema) + '.' + rtrim(@c_TgtTableName) + '('+     --kocy02              
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
         Select @c_whereclause = ' Where archivecop = ''9'' '               
      END                
      ELSE                
      BEGIN                
         Select @c_whereclause = ''                
      END                
   END                
                   
   IF @n_continue = 1 or @n_continue = 2                
   BEGIN                
      SELECT @c_one                 = rtrim(@c_one)                
      SELECT @c_two                 = rtrim(@c_two)                
      SELECT @c_three               = rtrim(@c_three)                
      SELECT @c_onea                = rtrim(@c_onea)                
      SELECT @c_twoa                = rtrim(@c_twoa)                
      SELECT @c_threea              = rtrim(@c_threea)                
      SELECT @c_SrcTableName        = rtrim(@c_SrcTableName)        
      SELECT @c_TgtTableName        = rtrim(@c_TgtTableName)   --kocy02      
      SELECT @c_four                =  rtrim(@c_four)                
      SELECT @c_foura               =  rtrim(@c_foura)                
      SELECT @c_five                =  rtrim(@c_five)                
      SELECT @c_fivea               =  rtrim(@c_fivea)                
      SELECT @c_six                 =  rtrim(@c_six)                
      SELECT @c_sixa                =  rtrim(@c_sixa)                
      SELECT @c_seven               =  rtrim(@c_seven)                
      SELECT @c_sevena              =  rtrim(@c_sevena)                
      SELECT @c_eight               =  rtrim(@c_eight)                
      SELECT @c_eighta              =  rtrim(@c_eighta)                
      SELECT @c_nine                =  rtrim(@c_nine)                
      SELECT @c_ninea               =  rtrim(@c_ninea)                
      SELECT @c_ten                 =  rtrim(@c_ten)                
      SELECT @c_tena                =  rtrim(@c_tena)                
      SELECT @c_eleven              =  rtrim(@c_eleven)                
      SELECT @c_elevena           =  rtrim(@c_elevena)                
      SELECT @c_twelve              =  rtrim(@c_twelve)                
      SELECT @c_twelvea             =  rtrim(@c_twelvea)                
      SELECT @c_thirteen            =  rtrim(@c_thirteen)                
      SELECT @c_thirteena           =  rtrim(@c_thirteena)                
      SELECT @c_fourteen            =  rtrim(@c_fourteen)                
      SELECT @c_fourteena           =  rtrim(@c_fourteena)                
      SELECT @c_fifteen             =  rtrim(@c_fifteen)                
      SELECT @c_fifteena            =  rtrim(@c_fifteena)                
      SELECT @c_sixteen             =  rtrim(@c_sixteen)                
      SELECT @c_sixteena            =  rtrim(@c_sixteena)              
                                      
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
         select 'tablename',@c_SrcTableName                
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
      EXEC ispPrimaryKeyColumns @c_FulltableName                
                
      IF EXISTS(SELECT 1 FROM #PrimaryKey)                 
      BEGIN                
         SELECT @cSQL1 = ' SET NOCOUNT ON ' + master.dbo.fnc_GetCharASCII(13)                
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key1 NVARCHAR(50), @key2 NVARCHAR(50), @key3 NVARCHAR(50), @key4 NVARCHAR(50)' + master.dbo.fnc_GetCharASCII(13)                
         SELECT @cSQL1 = @cSQL1 + ' DECLARE @key5 NVARCHAR(50), @key6 NVARCHAR(50), @key7 NVARCHAR(50), @key8 NVARCHAR(50)' + master.dbo.fnc_GetCharASCII(13)                
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
                
            SELECT @cSQL1 = @cSQL1 + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + ' ' + RTRIM(@cPrimaryKey)                   
            SELECT @cFetchSQL = @cFetchSQL + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + '@Key' + RTRIM(CAST(@nRowId as NVARCHAR(2)))                 
                                  
                
            SELECT @cWhereSQL = @cWhereSQL + CASE WHEN @nRowId > 1 THEN ' AND ' ELSE '' END  + RTRIM(@cPrimaryKey) + ' = @Key'                 
               + RTRIM(CAST(@nRowId as NVARCHAR(2)))                 
                                  
            FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId                 
      END                 
                         
         CLOSE C_PrimaryKey                
         DEALLOCATE C_PrimaryKey                 
                
         SELECT @cSQL1 = @cSQL1 + ' FROM '+rtrim(@c_schema)+'.' + RTRIM(@c_SrcTableName) + ' (NOLOCK) ' + @c_whereclause  + master.dbo.fnc_GetCharASCII(13)                
         SELECT @cSQL1 = @cSQL1 + ' OPEN C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)                
         SELECT @cSQL1 = @cSQL1 + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)                               
         SELECT @cSQL1 = @cSQL1 + ' WHILE @@FETCH_STATUS <> -1 ' + master.dbo.fnc_GetCharASCII(13)                         
         SELECT @cSQL1 = @cSQL1 + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)                      
         SELECT @cSQL1 = @cSQL1 + '    IF NOT EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.' +rtrim(@c_schema) +'.' + RTRIM(@c_TgtTableName)  + ' (NOLOCK) '  --kocy01 --kocy03              
         SELECT @cSQL1 = @cSQL1 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)                      
         SELECT @cSQL1 = @cSQL1 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL1 = @cSQL1 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)                  
                
         SELECT @cSQL2 =          '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)                 
             
         SELECT @cSQL2 = @cSQL2 + '    IF EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.' +rtrim(@c_schema)+ '.' + RTRIM(@c_TgtTableName)  + ' (NOLOCK) '   --kocy01 --kocy03             
         SELECT @cSQL2 = @cSQL2 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)                   
         SELECT @cSQL2 = @cSQL2 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + '       DELETE FROM '+rtrim(@c_schema)+'.' + RTRIM(@c_SrcTableName) + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)                   
         SELECT @cSQL2 = @cSQL2 + '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)                          
                
         SELECT @cSQL2 = @cSQL2 + '   ' + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)                 
         SELECT @cSQL2 = @cSQL2 + ' END ' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + ' CLOSE C_RECORDS' + master.dbo.fnc_GetCharASCII(13)                  
         SELECT @cSQL2 = @cSQL2 + ' DEALLOCATE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)                 
                
         EXEC( @cSQL1 +                 
               '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+                
               @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen +                
               '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+                
               @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +                
               @c_fourteena +  @c_fifteena + @c_sixteena  +            
               ' FROM '+@c_schema+'.' + @c_SrcTableName + ' (NOLOCK) ' + @cWhereSQL +                 
               @cSQL2 )                
                
                
         IF (@b_debug = 1)                
         BEGIN                
            print @cSQL1 + master.dbo.fnc_GetCharASCII(13) +                 
                  '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+                
                  @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen + master.dbo.fnc_GetCharASCII(13) +                 
                  '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+                
                  @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +                
               @c_fourteena +  @c_fifteena + @c_sixteena +                
                  ' FROM '+rtrim(@c_schema)+'.' + RTRIM(@c_SrcTableName) + ' (NOLOCK) ' + @cWhereSQL + master.dbo.fnc_GetCharASCII(13) +                
                  @cSQL2                 
         END                
      END -- Primary Key Exists                
      ELSE                
      BEGIN                
                
         exec (@c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+                
         @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen +                
         @c_sixteen +  @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+                
         @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +                
         @c_fourteena +  @c_fifteena + @c_sixteena +                
         ' From '+@c_schema+'.' + @c_SrcTableName + ' (NOLOCK) '  + @c_whereclause)                  
                
         IF (@b_debug = 1)                
         BEGIN                
            print @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+                
            @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen +                
            @c_sixteen +  @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+                
            @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +                
            @c_fourteena +  @c_fifteena + @c_sixteena +                
            ' From '+@c_schema+ '.' + @c_SrcTableName + ' (NOLOCK) '  + @c_whereclause                  
         END                 
      END                
                
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT                
      IF @n_err <> 0                
      BEGIN                  
         SELECT @n_continue = 3                
         SELECT @n_err = 73504             
         SELECT @c_errmsg = CONVERT(char(250),@n_err)                
            + ':  dynamic execute failed. (dbo.nsp_Build_Insert_GENERIC) ' + ' ( ' +                
            ' SQLSvr MESSAGE = ' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ')'                
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'dbo.nsp_Build_Insert_GENERIC'                
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