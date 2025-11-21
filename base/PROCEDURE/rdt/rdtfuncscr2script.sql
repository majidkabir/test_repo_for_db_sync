SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [RDT].[rdtFuncScr2Script] @nFunc INT AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cScn   NVARCHAR( 10)
   DECLARE @cFunc  NVARCHAR( 10)
   DECLARE @ci     NVARCHAR( 2)
   DECLARE @cValue NVARCHAR( 60)
   DECLARE @cSQL   NVARCHAR( 1024)

   DECLARE @i    INT
   DECLARE @nScn INT
   DECLARE @bFirstLine INT

   SET @cFunc = CAST( @nFunc AS NVARCHAR( 10))

   IF NOT EXISTS( SELECT 1 FROM rdt.RDTScn WHERE Func = @nFunc)
   BEGIN
      PRINT 'Function ' + @cFunc + ' not found'
      PRINT ''
      RETURN
   END

   DECLARE CUR_Scn CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
           SELECT Scn
           FROM RDT.RDTScn WITH (NOLOCK)
           WHERE Func = @nFunc
           ORDER BY Scn
         
       OPEN CUR_Scn
       FETCH NEXT FROM CUR_Scn INTO @nScn
       WHILE (@@FETCH_STATUS <> -1)
       BEGIN

            SET @cScn = CAST( @nScn AS NVARCHAR( 10))

            PRINT '-- ' + @cScn + ' = ?? screen'
            PRINT 'DELETE rdt.RDTScn WHERE Scn = ' + @cScn + ' AND Lang_Code = ''ENG'''
            PRINT 'EXECUTE rdt.rdtAddScn ' + @cScn + ', ''ENG'','

            SET @bFirstLine = 1

            SET @i = 1
            WHILE @i < 16
            BEGIN
               SET @ci = RIGHT( '00' + CAST( @i AS NVARCHAR( 2)), 2)
               SET @cValue = NULL
               SET @cSQL = 'SELECT @cValue = Line' + @ci + ' FROM rdt.RDTScn WHERE Scn = ' + CAST( @nScn AS NVARCHAR( 10))

               EXECUTE sp_executesql @cSQL, N'@cValue NVARCHAR( 60) OUTPUT', @cValue OUTPUT

               IF @cValue IS NOT NULL
               BEGIN
                  IF @bFirstLine = 1
                     PRINT '    @cLine' + @ci + ' = N''' + @cValue + ''''
                  ELSE
                     PRINT '   ,@cLine' + @ci + ' = N''' + @cValue + ''''
                  SET @bFirstLine = 0
               END
               SET @i = @i + 1
            END
            PRINT ''
	      FETCH NEXT FROM CUR_Scn INTO @nScn
       END -- END WHILE (@@FETCH_STATUS <> -1)
       CLOSE CUR_Scn
       DEALLOCATE CUR_Scn

GO