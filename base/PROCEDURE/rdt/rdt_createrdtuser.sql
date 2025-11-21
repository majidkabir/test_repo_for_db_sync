SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_CreateRDTUser                                   */  
/*                                                                      */  
/* Purpose: RDT Admin                                                   */  
/*                                                                      */  
/* Date       Rev   Author     Purposes                                 */  
/* 2024-10-24 1.0.0 Dennis     UWP-26001. Created                       */  
/************************************************************************/  
CREATE   PROC [RDT].[rdt_CreateRDTUser] (
   @cUserID            NVARCHAR(MAX),
   @cCloneUserID       NVARCHAR(128),
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR(200)   OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
   @nFirstSeq INT = 0,
   @cSQL NVARCHAR(MAX),
   @cUserSQL NVARCHAR(MAX),
   @cLangCode    NVARCHAR( 3),
   @cMenu        NVARCHAR( 10),
   @cUom         NVARCHAR(  1),
   @cMultiLogin  NVARCHAR(  1),
   @cPrinter     NVARCHAR( 10),
   @cPaperPrinter NVARCHAR(10),
   @cDateFormat   NVARCHAR(10),
   @cResumeSession NVARCHAR(1),
   @value         NVARCHAR(128)

   DECLARE cur CURSOR FOR 
   SELECT Value FROM STRING_SPLIT(@cUserID,',')

   OPEN cur
   SET @nErrno = 0
   IF ISNULL(@cUserID ,'') = ''
   BEGIN
      SET @nErrNo = 400
      SET @cErrMsg = 'Invalid User ID'
      GOTO QUIT
   END
   IF ISNULL(@cCloneUserID,'') <> '' AND NOT EXISTS(SELECT 1 FROM RDT.RDTUSER WITH(NOLOCK) WHERE USERNAME = @cCloneUserID)
   BEGIN
      SET @nErrNo = 400
      SET @cErrMsg = 'Invalid Clone User ID'
      GOTO QUIT
   END
   ELSE IF ISNULL(@cCloneUserID,'') <> ''
   BEGIN
      SELECT 
         @cLangCode = [DefaultLangCode]
         ,@cMenu = [DefaultMenu]
         ,@cUOM = [DefaultUOM]
         ,@cMultiLogin = [MultiLogin]
         ,@cPrinter = [DefaultPrinter]
         ,@cDateFormat = [Date_Format]
         ,@cPaperPrinter = [DefaultPrinter_Paper]
         ,@cResumeSession = [AllowResumeSession]
      FROM RDT.RDTUSER WITH (NOLOCK)
      WHERE USERNAME = @cCloneUserID
   END
   ELSE
   BEGIN
      SELECT @cLangCode = 'ENG'
         ,@cMenu = '6'
         ,@cUOM = '6'
         ,@cMultiLogin = 'N'
         ,@cPrinter = ''
         ,@cDateFormat = 'DMY'
         ,@cPaperPrinter = ''
         ,@cResumeSession = 'Y'
   END

   SET @cSQL = 'INSERT INTO [RDT].[RDTUser] WITH (ROWLOCK)
           ([UserName]
           ,[Password]
           ,[FullName]
           ,[DefaultStorer]
           ,[DefaultFacility]
           ,[DefaultLangCode]
           ,[DefaultMenu]
           ,[DefaultUOM]
           ,[MultiLogin]
           ,[DefaultPrinter]
           ,[Date_Format]
           ,[DefaultPrinter_Paper]
           ,[AllowResumeSession])
     VALUES'

   FETCH NEXT FROM cur INTO @value
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @value = UPPER(@value)
      IF NOT EXISTS (SELECT 1 FROM RDT.RDTUSER WITH (NOLOCK) WHERE USERNAME = @value)
      BEGIN
         IF @nFirstSeq = 0
            SET @nFirstSeq = 1
         ELSE
            SET @cUserSQL = @cUserSQL + ','

         SET @cUserSQL = @cUserSQL + '('
         SET @cUserSQL = @cUserSQL + ''''+@value+''','
         SET @cUserSQL = @cUserSQL + CONCAT('''',RDT.rdt_RDTUserEncryption(@value,@value),''',')
         SET @cUserSQL = @cUserSQL + ''''+@value+''','
         SET @cUserSQL = @cUserSQL + ''''+@cStorerKey+''','--storer
         SET @cUserSQL = @cUserSQL + ''''+@cFacility+''','--facility
         SET @cUserSQL = @cUserSQL + ''''+@cLangCode+''','--langcode
         SET @cUserSQL = @cUserSQL + ''''+@cMenu+''','--default menu
         SET @cUserSQL = @cUserSQL + ''''+@cUom+''','--default uom
         SET @cUserSQL = @cUserSQL + ''''+@cMultiLogin+''','--Multi Login
         SET @cUserSQL = @cUserSQL + ''''+@cPrinter+''','--default printer
         SET @cUserSQL = @cUserSQL + ''''+@cDateFormat+''','--default date format
         SET @cUserSQL = @cUserSQL + ''''+@cPaperPrinter+''','--default paper printer
         SET @cUserSQL = @cUserSQL + ''''+@cResumeSession+''''--resume session
         SET @cUserSQL = @cUserSQL + ')'
      END
      FETCH NEXT FROM cur INTO @value
   END
   SET @cSQL = @cSQL + @cUserSQL
   BEGIN TRY
      IF @nFirstSeq = 1
         EXEC (@cSQL)
   END TRY
   BEGIN CATCH
      SELECT @nErrNo = @@ERROR
      PRINT ERROR_MESSAGE()
      IF @nErrNo <> 0
         GOTO Quit
   END CATCH



Quit:
   CLOSE cur
   DEALLOCATE cur
END


SET QUOTED_IDENTIFIER OFF

GO