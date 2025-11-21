SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: ids_sp_generate_script                                     */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 28-Nov-2001            1.0   Initial revision                           */
/***************************************************************************/ 
CREATE PROCEDURE [dbo].[ids_sp_generate_script] -- 28.nov.2001
@objname nvarchar(776)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @dbname sysname,
           @BlankSpaceAdded int,
           @BasePos int,
           @CurrentPos int,
           @TextLength int,
           @LineId int,
           @AddOnLen int,
           @LFCR int --lengths of line feed carriage return
           ,
           @DefinedLength int
           /* NOTE: Length of @SyscomText is 4000 to replace the length of
           ** text column in syscomments. 
           ** lengths on @Line, #CommentText Text column and
           ** value for @DefinedLength are all 4000. These need to all have
           ** the same values. 4000 was selected in order for the max length
           ** display using down level clients
           */,
           @SyscomText nvarchar(4000),
           @Line nvarchar(4000)
   SELECT
      @DefinedLength = 4000
   SELECT
      @BlankSpaceAdded = 0 /*Keeps track of blank spaces at end of lines. Note Len function ignores
						 trailing blank spaces*/
   CREATE TABLE #CommentText (
      LineId int,
      Text nvarchar(4000)
   )
   /*
   **  Make sure the @objname is local to the current database.
   */
   SELECT
      @dbname = PARSENAME(@objname, 3)
   IF @dbname IS NOT NULL
      AND @dbname <> DB_NAME()
   BEGIN
      RAISERROR (15250, -1, -1)
      RETURN (1)
   END
   /*
   **  See if @objname exists.
   */
   IF (OBJECT_ID(@objname) IS NULL)
   BEGIN
      SELECT
         @dbname = DB_NAME()
      RAISERROR (15009, -1, -1, @objname, @dbname)
      RETURN (1)
   END
   /*
   **  Find out how many lines of text are coming back,
   **  and return if there are none.
   */
   IF (SELECT
         COUNT(*)
      FROM syscomments c,
           dbo.sysobjects o
      WHERE o.xtype NOT IN ('S', 'U')
      AND o.id = c.id
      AND o.id = OBJECT_ID(@objname))
      = 0
   BEGIN
      RAISERROR (15197, -1, -1, @objname)
      RETURN (1)
   END
   IF (SELECT
         COUNT(*)
      FROM syscomments
      WHERE id = OBJECT_ID(@objname)
      AND encrypted = 0)
      = 0
   BEGIN
      RAISERROR (15471, -1, -1)
      RETURN (0)
   END
   /*
   **  Else get the text.
   */
   SELECT
      @LFCR = 2
   SELECT
      @LineId = 1
   DECLARE SysComCursor CURSOR FOR
   SELECT
      text
   FROM syscomments
   WHERE id = OBJECT_ID(@objname)
   AND encrypted = 0
   ORDER BY number, colid
   FOR READ ONLY
   OPEN SysComCursor
   FETCH NEXT FROM SysComCursor INTO @SyscomText
   WHILE @@fetch_status >= 0
   BEGIN
      SELECT
         @BasePos = 1
      SELECT
         @CurrentPos = 1
      SELECT
         @TextLength = LEN(@SyscomText)
      WHILE @CurrentPos != 0
      BEGIN
         --Looking for end of line followed by carriage return
         SELECT
            @CurrentPos = CHARINDEX(master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10), @SyscomText, @BasePos)
         --If carriage return found
         IF @CurrentPos != 0
         BEGIN
            /*If new value for @Lines length will be > then the
    			**set length then insert current contents of @line
    			**and proceed.
    			*/
            WHILE (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded + @CurrentPos - @BasePos + @LFCR) > @DefinedLength
            BEGIN
               SELECT
                  @AddOnLen = @DefinedLength - (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded)
               INSERT #CommentText
                  VALUES (@LineId, ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
               SELECT
                  @Line = NULL,
                  @LineId = @LineId + 1,
                  @BasePos = @BasePos + @AddOnLen,
                  @BlankSpaceAdded = 0
            END
            SELECT
               @Line = ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @CurrentPos - @BasePos + @LFCR), N'')
            SELECT
               @BasePos = @CurrentPos + 2
            INSERT #CommentText
               VALUES (@LineId, @Line)
            SELECT
               @LineId = @LineId + 1
            SELECT
               @Line = NULL
         END
         ELSE
         --else carriage return not found
         BEGIN
            IF @BasePos < @TextLength
            BEGIN
               /*If new value for @Lines length will be > then the
    				**defined length
    				*/
               WHILE (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded + @TextLength - @BasePos + 1) > @DefinedLength
               BEGIN
                  SELECT
                     @AddOnLen = @DefinedLength - (ISNULL(LEN(@Line), 0) + @BlankSpaceAdded)
                  INSERT #CommentText
                     VALUES (@LineId, ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @AddOnLen), N''))
                  SELECT
                     @Line = NULL,
                     @LineId = @LineId + 1,
                     @BasePos = @BasePos + @AddOnLen,
                     @BlankSpaceAdded = 0
               END
               SELECT
                  @Line = ISNULL(@Line, N'') + ISNULL(SUBSTRING(@SyscomText, @BasePos, @TextLength - @BasePos + 1), N'')
               IF CHARINDEX(' ', @SyscomText, @TextLength + 1) > 0
               BEGIN
                  SELECT
                     @Line = @Line + ' ',
                     @BlankSpaceAdded = 1
               END
               BREAK
            END
         END
      END
      FETCH NEXT FROM SysComCursor INTO @SyscomText
   END
   IF @Line IS NOT NULL
      INSERT #CommentText
         VALUES (@LineId, @Line)
   SELECT
      Text
   FROM #CommentText
   ORDER BY LineId
   CLOSE SysComCursor
   DEALLOCATE SysComCursor
   DROP TABLE #CommentText
   RETURN (0) -- sp_helptext


GO