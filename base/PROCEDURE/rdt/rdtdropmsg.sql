SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [RDT].[rdtDropMsg] 
   @nMsgIDFrom INT, 
   @nMsgIDTo   INT = NULL, 
   @cLangCode  NVARCHAR(3) = 'ENG'
AS BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nMsgIDTo IS NULL
      SET @nMsgIDTo = @nMsgIDFrom

   DECLARE @tMsg TABLE
   (
      ERROR INT
   )

   SET NOCOUNT ON
   INSERT INTO @tMsg
   SELECT error 
   FROM master.dbo.sysmessages 
   WHERE error BETWEEN @nMsgIDFrom AND @nMsgIDTo

   DECLARE @nError INT
   DECLARE @curMsg CURSOR
   SET @curMsg = CURSOR LOCAL FAST_FORWARD FOR
      SELECT ERROR FROM @tMsg
   OPEN @curMsg 
   FETCH NEXT FROM @curMsg INTO @nError
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Drop message on SQL
      IF @cLangCode = 'ENG'
      BEGIN
         EXECUTE master.dbo.sp_dropmessage @nError
         PRINT 'Message ' + LTRIM( CAST( @nError AS NVARCHAR( 10))) + ' deleted in master.dbo.sysmessages'
      END
      
      -- Drop message on RDT
      DELETE rdt.RDTMsg 
      WHERE Lang_Code = @cLangCode
         AND Message_Type = 'DSP'
         AND Message_ID = @nError
      IF @@ROWCOUNT = 1
         PRINT 'Message ' + LTRIM( CAST( @nError AS NVARCHAR( 10))) + ' deleted in rdt.RDTMsg'
      ELSE
         PRINT 'Message ' + LTRIM( CAST( @nError AS NVARCHAR( 10))) + ' NOT FOUND in rdt.RDTMsg'

      FETCH NEXT FROM @curMsg INTO @nError
   END
   SET NOCOUNT OFF
END

GO