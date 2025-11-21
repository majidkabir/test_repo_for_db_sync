SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : nsp_Move_From_Archive                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Move those data which are more than the date parsed in      */
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
/* 22-Feb-2008  June				SOS99065 : Add ArchiveOpenBal Table			*/
/*										Update OpenBal when ITRN trx is moved 		*/
/*										from Live Archive db								*/
/* 21-Oct-2009  TLTING        delete from archive (tlting01)            */
/* 23-Feb-2010  Leong         Use DatePart to specify Year and Month    */
/*                            in @c_DateToDelete (leong01)              */
/* 16-Jun-2011  KHLim         remove OBJECTPROPERTY(Id, N'IsTrigger')=1 */
/* 11-Jun-2012  KHLim01       increase storage size & add CopyFromDB    */
/* 18-May-2016  JayLim        Add on table schema                       */
/*                            & default parse in value   (Jay01)        */
/*                            & SQL 2012 compatibility enhancement      */
/*                            & Replace " to '                          */
/* 07-Mar-2017  JayLim        Script enhancement (Jay02)                */
/* 09-Mar-2017  JayLim	      Increase Parameter size 					*/
/*							  & Add '[]' to field						*/
/*							  & Close cursor (Jay03)					*/
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_Move_From_Archive]
     @c_copyto_db    NVARCHAR(128)            -- KHLim01
   , @c_tableschema  NVARCHAR(10)              --(Jay01)  
   , @c_tablename    NVARCHAR(128)            -- KHLim01
   , @c_DateToDelete NVARCHAR(10)  -- YYYYMMDD
   , @c_DateField    NVARCHAR(128) -- KHLim01
   , @c_ArchiveDB	   NVARCHAR(128) -- KHLim01 CopyFromDB
   , @b_archive      int
   , @b_Success      int        OUTPUT
   , @n_err          int        OUTPUT
   , @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue          int
         , @n_starttcnt         int         -- Holds the current transaction count
         , @n_cnt               int         -- Holds @@ROWCOUNT after certain operations
         , @b_debug             int       -- Debug On Or Off
         , @n_rowcount          integer
, @n_nextrow           integer
         , @c_msg               NVARCHAR(1024) --Jay03
         , @c_field             NVARCHAR(128)  -- KHLim01
         , @c_buildfieldstring  NVARCHAR(512)  --Jay03
         , @c_firsttime         NVARCHAR(1)
         , @c_one               NVARCHAR(512)  --Jay03
         , @c_onea              NVARCHAR(512)  --Jay03
		 , @c_two               NVARCHAR(512)  --Jay03
         , @c_twoa              NVARCHAR(512)  --Jay03
         , @c_three             NVARCHAR(512)  --Jay03
         , @c_threea            NVARCHAR(512)  --Jay03
         , @c_four              NVARCHAR(512)  --Jay03
         , @c_foura             NVARCHAR(512)  --Jay03
         , @c_five              NVARCHAR(512)  --Jay03
         , @c_fivea             NVARCHAR(512)  --Jay03
         , @c_six               NVARCHAR(512)  --Jay03
         , @c_sixa              NVARCHAR(512)  --Jay03
         , @c_seven             NVARCHAR(512)  --Jay03
         , @c_sevena            NVARCHAR(512)  --Jay03
         , @c_eight             NVARCHAR(512)  --Jay03
         , @c_eighta            NVARCHAR(512)  --Jay03
         , @c_nine              NVARCHAR(512)  --Jay03
         , @c_ninea             NVARCHAR(512)  --Jay03
         , @c_ten               NVARCHAR(512)  --Jay03
         , @c_tena              NVARCHAR(512)  --Jay03
         , @c_eleven            NVARCHAR(512)  --Jay03
         , @c_elevena           NVARCHAR(512)  --Jay03
         , @c_twelve            NVARCHAR(512)  --Jay03
         , @c_twelvea           NVARCHAR(512)  --Jay03
         , @c_thirteen          NVARCHAR(512)  --Jay03
         , @c_thirteena         NVARCHAR(512)  --Jay03
         , @c_fourteen          NVARCHAR(512)  --Jay03
         , @c_fourteena         NVARCHAR(512)  --Jay03
         , @c_fifteen           NVARCHAR(512)  --Jay03
         , @c_fifteena          NVARCHAR(512)  --Jay03
         , @c_sixteen           NVARCHAR(512)  --Jay03
         , @c_sixteena          NVARCHAR(512)  --Jay03
         , @n_messageno         int
         , @c_comma             NVARCHAR(1)
         , @c_parenset          NVARCHAR(1)
         , @n_length            int          -- KHLim01
         , @c_typename          NVARCHAR(128) -- KHLim01
         , @c_exist             NVARCHAR(512) --Jay03
         , @c_exist1            NVARCHAR(512) --Jay03
         , @c_whereclause       NVARCHAR(512) --Jay03
         , @user_type           smallint
         , @n_first_comma_flag  int
         , @c_RecordDate        NVARCHAR(10)

	-- Start : SOS99065
	DECLARE @t_OpenBal TABLE
			( 	Storerkey NVARCHAR(15),
				SKU       NVARCHAR(20),
				OpenBal   int
			 )
	DECLARE @c_ExecStatements Nvarchar(max) --Jay03
			, @Storerkey        NVARCHAR(15)
			, @SKU		        NVARCHAR(20)
			, @Qty		        int
			, @n_count          int
   -- End : SOS99065

   SELECT @n_first_comma_flag = 0
   SET NOCOUNT ON

   SELECT @c_comma     = ''
   SELECT @c_parenset  = '0'
   SELECT @n_continue  = 1
   SELECT @b_debug     = 0
   SELECT @n_messageno = 1
   SELECT @c_one       =  ' '
   SELECT @c_onea      =  ' '
   SELECT @c_two       =  ' '
   SELECT @c_twoa      =  ' '
   SELECT @c_three     =  ' '
   SELECT @c_threea    =  ' '
   SELECT @c_four      =  ' '
   SELECT @c_foura     =  ' '
   SELECT @c_five      =  ' '
   SELECT @c_fivea     =  ' '
   SELECT @c_six       =  ' '
   SELECT @c_sixa      =  ' '
   SELECT @c_seven     =  ' '
   SELECT @c_sevena    =  ' '
   SELECT @c_eight     =  ' '
   SELECT @c_eighta    =  ' '
   SELECT @c_nine      =  ' '
   SELECT @c_ninea     =  ' '
   SELECT @c_ten       =  ' '
   SELECT @c_tena      =  ' '
   SELECT @c_eleven    =  ' '
   SELECT @c_elevena   =  ' '
   SELECT @c_twelve    =  ' '
   SELECT @c_twelvea   =  ' '
   SELECT @c_thirteen  =  ' '
   SELECT @c_thirteena =  ' '
   SELECT @c_fourteen  =  ' '
   SELECT @c_fourteena =  ' '
   SELECT @c_fifteen   =  ' '
   SELECT @c_fifteena  =  ' '
   SELECT @c_sixteen   =  ' '
   SELECT @c_sixteena  =  ' '
   SELECT @c_sixteen = RTRIM(@c_copyto_db) + '..' + RTRIM(@c_tablename)

   ------------------------------------------------------------------------- (Jay01) Default parse in value
   IF (@c_ArchiveDB IS NULL OR @c_ArchiveDB = '')
   BEGIN
   PRINT 'DB Source Name Parameter Needed'
       SET @n_continue = 4
   END

   IF (@c_DateField IS NULL OR @c_DateField = '')
   BEGIN
      SET @c_DateField = 'AddDate'
   END

   IF (@c_DateToDelete IS NULL OR @c_DateToDelete = '')
   BEGIN
      PRINT 'Date Parameter Needed'
      SET @n_continue = 4
   END
   -------------------------------------------------------------------------


   IF OBJECT_ID(@c_sixteen) is NULL
   BEGIN
      SELECT @n_continue = 3  -- No need to continue if table does not exist in to database
      SELECT @n_err = 73500
      SELECT @c_errmsg = 'NSQL ' + CONVERT(char(5),@n_err)+':Table does not exist in Target Database ' +
                         @c_tablename + '(nsp_Move_From_Archive)' --(Jay01)
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_rowcount = count(SYSCOLUMNS.name)
      FROM    SYSOBJECTS, SYSCOLUMNS
  WHERE   SYSOBJECTS.id = SYSCOLUMNS.id
      AND     SYSOBJECTS.name = @c_tablename
      IF (@n_rowcount <= 0)
      BEGIN
         SELECT @n_continue = 3
     SELECT @n_err = 73501
         SELECT @c_errmsg = 'NSQL ' + CONVERT(char(5),@n_err)+':No rows or columns found for ' +
            RTRIM(@c_tablename) + '(nsp_Move_From_Archive)' --(Jay01)
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @n_nextrow = 0
      SELECT @c_firsttime = 'Y'
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_sixteen = ' '
      DECLARE @b_cursoropen int
      SELECT @b_cursoropen = 0
      DECLARE CUR_INSERT_BUILD Cursor FAST_FORWARD READ_ONLY for
      SELECT SYSCOLUMNS.name,  SYSCOLUMNS.length, SYSCOLUMNS.usertype, systypes.name
      FROM   SYSOBJECTS  , SYSCOLUMNS, systypes
      WHERE  SYSOBJECTS.id = SYSCOLUMNS.id and
             SYSCOLUMNS.xusertype = systypes.xusertype and  -- KHLim01
             SYSOBJECTS.name =  @c_tablename
      ORDER By SYSCOLUMNS.colorder

      OPEN CUR_INSERT_BUILD
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 73502
         SELECT @c_errmsg = CONVERT(char(250),@n_err)
                           + ':  Open of cursor failed. (nsp_Move_From_Archive) ' + ' ( ' +
                             ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@c_errmsg)) + ')' --(Jay01)
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
               + ':  fetch failed. (nsp_Move_From_Archive) ' + ' ( ' +
               ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@c_errmsg)) + ')' --(Jay01)
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
                        SELECT @c_buildfieldstring =  @c_buildfieldstring + @c_comma +'['+@c_field+']'
                     END
                     IF  (@n_first_comma_flag = 0)
                     BEGIN
                        SELECT @c_buildfieldstring = '['+ @c_field +']'
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
                        SELECT 'when len > 200  should never happen '
                     END
                  END
                  SELECT @n_nextrow = @n_nextrow + 1
                  IF (datalength (@c_buildfieldstring)  > 255) -- Jay03 -- > 150
                  BEGIN
                     IF (@b_debug = 1)
                     BEGIN
                        SELECT '@c_buildfieldstring =',@c_buildfieldstring
                        SELECT '@c_msg =',@c_msg
                        SELECT '@n_message =',@n_messageno
                        SELECT 'length of @c_msg =', datalength(@c_msg)
                        SELECT 'length of @c_buildfieldstring =', datalength(@c_buildfieldstring)
                        SELECT 'n_nextrow', @n_nextrow
                        SELECT 'n_rowcount', @n_rowcount
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
            SELECT 'len =',datalength(@c_buildfieldstring), 'out of cursor ', @c_buildfieldstring
            SELECT '@n_messageno =', @n_messageno
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

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
--       IF (@b_archive = 1)
--       BEGIN
-- --          SELECT @c_whereclause = ' Where archivecop = ''9'' AND DATEDIFF(DAY, AddDate, GETDATE()) > ' + CAST(@n_Days AS CHAR) -- vicky
--          SELECT @c_whereclause = ' Where archivecop = ''9'' AND ' + RTRIM(@c_DateField) + ' <= ''' + @c_DateToDelete + ''' '
--       END
--       ELSE
--       BEGIN
--          SELECT @c_whereclause = ' Where ' + RTRIM(@c_DateField) + ' <= ''' + @c_DateToDelete + ''' '  -- vicky
--       END
         SELECT @c_whereclause = ' Where ' + RTRIM(@c_DateField) + ' < ''' + @c_DateToDelete + ''' '  --(Jay02) replace <=  to < 

--       SELECT @c_whereclause = 'WHERE DATEPART(YEAR, RTRIM(' + @c_DateField + ')) = ''' + SUBSTRING(@c_DateToDelete,1,4) + ''' '
--                               + 'AND DATEPART(MONTH, RTRIM(' + @c_DateField + ')) = ''' + SUBSTRING(@c_DateToDelete,5,2) + ''' ' -- For specific Month & Year
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_one       = RTRIM(@c_one)
      SELECT @c_two       = RTRIM(@c_two)
      SELECT @c_three     = RTRIM(@c_three)
      SELECT @c_onea      = RTRIM(@c_onea)
      SELECT @c_twoa      = RTRIM(@c_twoa)
      SELECT @c_threea    = RTRIM(@c_threea)
      SELECT @c_tablename = RTRIM(@c_tablename)
      SELECT @c_four      = RTRIM(@c_four)
      SELECT @c_foura     = RTRIM(@c_foura)
      SELECT @c_five      = RTRIM(@c_five)
      SELECT @c_fivea     = RTRIM(@c_fivea)
      SELECT @c_six       = RTRIM(@c_six)
      SELECT @c_sixa      = RTRIM(@c_sixa)
      SELECT @c_seven     = RTRIM(@c_seven)
      SELECT @c_sevena    = RTRIM(@c_sevena)
      SELECT @c_eight     = RTRIM(@c_eight)
      SELECT @c_eighta    = RTRIM(@c_eighta)
      SELECT @c_nine      = RTRIM(@c_nine)
      SELECT @c_ninea     = RTRIM(@c_ninea)
      SELECT @c_ten       = RTRIM(@c_ten)
      SELECT @c_tena      = RTRIM(@c_tena)
      SELECT @c_eleven    = RTRIM(@c_eleven)
      SELECT @c_elevena   = RTRIM(@c_elevena)
      SELECT @c_twelve    = RTRIM(@c_twelve)
      SELECT @c_twelvea   = RTRIM(@c_twelvea)
      SELECT @c_thirteen  = RTRIM(@c_thirteen)
      SELECT @c_thirteena = RTRIM(@c_thirteena)
      SELECT @c_fourteen  = RTRIM(@c_fourteen)
      SELECT @c_fourteena = RTRIM(@c_fourteena)
      SELECT @c_fifteen   = RTRIM(@c_fifteen)
      SELECT @c_fifteena  = RTRIM(@c_fifteena)
      SELECT @c_sixteen   = RTRIM(@c_sixteen)
      SELECT @c_sixteena  = RTRIM(@c_sixteena)
      IF (@b_debug = 1)
      BEGIN
         SELECT 'one', @c_one
         SELECT 'two', @c_two
         SELECT 'three',@c_three
         SELECT 'onea', @c_onea
         SELECT 'twoa', @c_twoa
         SELECT 'threea',@c_threea
         SELECT 'four', @c_four
         SELECT 'foura',@c_foura
         SELECT 'from'
         SELECT 'tablename',@c_tablename
         SELECT 'whereclause',@c_whereclause
      END

      DECLARE @cPrimaryKey NVARCHAR(128),
              @cSQL1       NVARCHAR(MAX),
              @cSQL2       NVARCHAR(MAX),
              @cSQL3       NVARCHAR(MAX),
              @nRowId      int,
              @cFetchSQL   NVARCHAR(MAX),
              @cWhereSQL   NVARCHAR(MAX)

		-- Start : SOS99065
		IF UPPER(@c_tablename) = 'ITRN'
		BEGIN
			IF UPPER(@c_DateField) = 'ADDDATE'
			BEGIN
				INSERT INTO @t_OpenBal (Storerkey, SKU, OpenBal)
				SELECT Storerkey, SKU, SUM(Qty)
				FROM   ITRN WITH (NOLOCK)
				-- Where  AddDate <= @c_DateToDelete --Leong01
            --WHERE DATEPART(YEAR, Adddate) = SUBSTRING(@c_DateToDelete,1,4)
            --AND   DATEPART(MONTH, Adddate) = SUBSTRING(@c_DateToDelete,5,2)
            WHERE DATEPART(YEAR, Adddate) < SUBSTRING(@c_DateToDelete,1,4) --(Jay02)
				AND 	TranType <> 'MV'
				GROUP BY Storerkey, SKU
			END
			ELSE
			BEGIN
				INSERT INTO @t_OpenBal (Storerkey, SKU, OpenBal)
				SELECT Storerkey, SKU, SUM(Qty)
				FROM   ITRN WITH (NOLOCK)
				-- Where  EditDate <= @c_DateToDelete --Leong01
            --WHERE DATEPART(YEAR, EditDate) = SUBSTRING(@c_DateToDelete,1,4)
            --AND   DATEPART(MONTH, EditDate) = SUBSTRING(@c_DateToDelete,5,2)
            WHERE DATEPART(YEAR, Adddate) < SUBSTRING(@c_DateToDelete,1,4) --(Jay02)
				AND 	TranType <> 'MV'
				GROUP BY Storerkey, SKU
			END
		END
		-- End : SOS99065

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

            SELECT @cSQL1 = @cSQL1 + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + ' ' + RTRIM(@cPrimaryKey)
            SELECT @cFetchSQL = @cFetchSQL + CASE WHEN @nRowId > 1 THEN ',' ELSE '' END + '@Key' + RTRIM(CAST(@nRowId as NVARCHAR(2)))
            SELECT @cWhereSQL = @cWhereSQL + CASE WHEN @nRowId > 1 THEN ' AND ' ELSE '' END  + RTRIM(@cPrimaryKey) + ' = @Key'
                                + RTRIM(CAST(@nRowId as NVARCHAR(2)))

            FETCH NEXT FROM C_PrimaryKey INTO @cPrimaryKey, @nRowId
         END

         CLOSE C_PrimaryKey
         DEALLOCATE C_PrimaryKey

         SELECT @cSQL1 = @cSQL1 + ' FROM ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + RTRIM(@c_tablename) + ' (NOLOCK) ' + @c_whereclause  + master.dbo.fnc_GetCharASCII(13)  -- KHLim01 -Jay01
         SELECT @cSQL1 = @cSQL1 + ' OPEN C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + ' WHILE @@FETCH_STATUS <> -1 ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + ' BEGIN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + '    IF NOT EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.'+ @c_tableschema + '.'
                                + RTRIM(@c_tablename) + ' (NOLOCK) '
         SELECT @cSQL1 = @cSQL1 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL1 = @cSQL1 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)

         SELECT @cSQL2 =          '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)
----
         SELECT @cSQL2 = @cSQL2 + '    IF EXISTS(SELECT 1 FROM ' + RTRIM(@c_copyto_db) + '.'+ @c_tableschema + '.' + RTRIM(@c_tablename) + ' (NOLOCK) '
         SELECT @cSQL2 = @cSQL2 + @cWhereSQL + ')' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + '    BEGIN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + '       BEGIN TRAN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + '       DELETE FROM ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + RTRIM(@c_tablename) + ' WITH (ROWLOCK) ' + @cWhereSQL + master.dbo.fnc_GetCharASCII(13)  -- KHLim01 -Jay01
         SELECT @cSQL2 = @cSQL2 + '       COMMIT TRAN ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + '    END ' + master.dbo.fnc_GetCharASCII(13)
---
         SELECT @cSQL2 = @cSQL2 + '   ' + @cFetchSQL + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + ' END ' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + ' CLOSE C_RECORDS' + master.dbo.fnc_GetCharASCII(13)
         SELECT @cSQL2 = @cSQL2 + ' DEALLOCATE C_RECORDS ' + master.dbo.fnc_GetCharASCII(13)

         IF (@b_debug = 1)
         BEGIN
            PRINT @cSQL1 + master.dbo.fnc_GetCharASCII(13) +
                  '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+
                  @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen + master.dbo.fnc_GetCharASCII(13) +
                  '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+
                  @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +
                  @c_fourteena +  @c_fifteena + @c_sixteena +
                  ' FROM ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + RTRIM(@c_tablename) + ' (NOLOCK) ' + @cWhereSQL + master.dbo.fnc_GetCharASCII(13) +  -- KHLim01 --Jay01
                  @cSQL2
         END

         EXEC( @cSQL1 +
               '        ' + @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+
               @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen + @c_sixteen +
               '        ' + @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+
               @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +
               @c_fourteena +  @c_fifteena + @c_sixteena +
               ' FROM ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + @c_tablename + ' (NOLOCK) ' + @cWhereSQL +  -- KHLim01 --Jay01
               @cSQL2 )
      END -- Primary Key Exists
      ELSE
      BEGIN
         IF (@b_debug = 1)
         BEGIN
            PRINT @c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+
                  @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen +
                  @c_sixteen +  @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+
                  @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +
                  @c_fourteena +  @c_fifteena + @c_sixteena +
                  ' From ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + @c_tablename + ' (NOLOCK) '  + @c_whereclause  -- KHLim01 --Jay01
         END

         exec (@c_one+@c_two+@c_three+@c_four+@c_five+@c_six+@c_seven+@c_eight+@c_nine+
         @c_ten + @c_eleven + @c_twelve + @c_thirteen + @c_fourteen + @c_fifteen +
         @c_sixteen +  @c_onea+@c_twoa+@c_threea+@c_foura+@c_fivea+@c_sixa+@c_sevena+
         @c_eighta+@c_ninea +   @c_tena +  @c_elevena +  @c_twelvea + @c_thirteena +
         @c_fourteena +  @c_fifteena + @c_sixteena +
         ' From ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + @c_tablename + ' (NOLOCK) '  + @c_whereclause)  -- KHLim01 --jay01

         IF (@b_debug = 1)
         BEGIN
            PRINT 'Delete From ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + @c_tablename + ' WITH (ROWLOCK) '  + @c_whereclause  -- KHLim01 --Jay01
         END
         -- tlting01
         exec ('Delete From ' + @c_ArchiveDB + '.'+ @c_tableschema + '.' + @c_tablename + ' WITH (ROWLOCK) '  + @c_whereclause)  -- KHLim01 --Jay01
      END

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 73504
         SELECT @c_errmsg = CONVERT(char(250),@n_err)
                           + ':  dynamic execute failed. (nsp_Move_From_Archive) ' + ' ( ' +
                           ' SQLSvr MESSAGE = ' + LTRIM(RTRIM(@c_errmsg)) + ')' --(Jay01)
      END

		-- Start : SOS99065
		IF @n_continue = 1 OR @n_continue = 2
		BEGIN
		   DECLARE Bal_Cur CURSOR FAST_FORWARD READ_ONLY
		   FOR SELECT Storerkey, SKU, SUM(OpenBal)
				 FROM   @t_OpenBal
				 GROUP BY Storerkey, SKU
				 ORDER BY Storerkey, SKU

		   OPEN Bal_Cur
		   FETCH NEXT FROM Bal_Cur INTO @StorerKey, @Sku, @Qty

		   WHILE (@@fetch_status <> -1)
		   BEGIN
				BEGIN TRAN

				SELECT @c_ExecStatements = 'SELECT @n_count = COUNT(SKU) FROM '+ RTRIM(@c_ArchiveDB) + '.dbo.ArchiveOpenBal WHERE Storerkey = @Storerkey AND SKU = @Sku '
			   EXEC sp_executesql @c_ExecStatements, N'@Storerkey NVARCHAR(15), @SKU NVARCHAR(20), @n_count int OUTPUT', @Storerkey, @SKU, @n_count OUTPUT
				IF @n_Count IS NULL SELECT @n_count = 0

				IF @n_count = 0
				BEGIN
					SELECT @c_ExecStatements = 'INSERT INTO ' + RTRIM(@c_ArchiveDB) + '.dbo.ArchiveOpenBal (Storerkey, SKU, OpenBal) '
                                        + 'VALUES (@Storerkey, @SKU, @Qty) '
				   EXEC sp_executesql @c_ExecStatements, N'@Storerkey NVARCHAR(15), @SKU NVARCHAR(20), @Qty int', @Storerkey, @SKU, @Qty
				END
				ELSE
				BEGIN
					SELECT @c_ExecStatements = 'UPDATE ' + RTRIM(@c_ArchiveDB) + '.dbo.ArchiveOpenBal WITH (ROWLOCK) '
                                        + 'SET   OpenBal = OpenBal + ISNULL(@Qty, 0) '
                                        + 'WHERE Storerkey = @Storerkey '
                                        + 'AND   SKU = @SKU '
				   EXEC sp_executesql @c_ExecStatements, N'@Storerkey NVARCHAR(15), @SKU NVARCHAR(20), @Qty int', @Storerkey, @SKU, @Qty
				END

				IF @@ERROR = 0
					COMMIT TRAN
				ELSE
					ROLLBACK TRAN

			   FETCH NEXT FROM Bal_Cur INTO @StorerKey, @Sku, @Qty
			END
			CLOSE Bal_Cur --(Jay03) cursor open without closing
			DEALLOCATE Bal_Cur --(Jay03)
		END
		-- End : SOS99065
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_Move_From_Archive' --(Jay01)
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR -- SQL 2012 (Jay01)
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
END -- End Proc

GO