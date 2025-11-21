SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetScreen                                       */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Loop screen objects to build XML                            */
/*                                                                      */
/* Date         Author        Purposes                                  */
/* 2004-12-19   Shong         Created                                   */
/* 2009-11-23   ChewKP        Changes For RDT2 Column Attributes        */
/* 2011-10-12   ChewKP        Changes to Insert into RDT.RDTXML_Elm in  */
/*                            RDT.rdtScr2XML (ChewKP01)                 */
/* 2013-09-29   Ung           Support multi language                    */
/* 2015-10-02   Ung           Performance tuning for CN Nov 11          */
/************************************************************************/

CREATE PROC [RDT].[rdtGetScreen] (
   @nMobile INT,
   @cXML    NVARCHAR(MAX) OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @nScn         INT
   DECLARE @nScnKey      INT
   DECLARE @nScnNotSetup INT
   DECLARE @cLangCode    NVARCHAR(3)
   DECLARE @curSD        CURSOR

   -- Get session info
   SELECT 
      @nScn = Scn, 
      @cLangCode = Lang_Code
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check screen setup (in user language)
   IF NOT EXISTS( SELECT 1 FROM RDT.RDTScnDetail (NOLOCK) WHERE Scn = @nScn AND Lang_Code = @cLangCode)
   BEGIN
      IF @cLangCode = 'ENG'
         SET @nScnNotSetup = 1
      ELSE
      BEGIN
         -- Change to English
         SET @cLangCode = 'ENG'
         
         -- Check English screen setup
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtScnDetail WITH (NOLOCK) WHERE Scn = @nScn AND Lang_Code = @cLangCode)
            SET @nScnNotSetup = 1
      END
      
      -- Display error screen
      IF @nScnNotSetup = 1
      BEGIN
         DECLARE @cScn NVARCHAR(5)
         SET @cScn = CAST( @nScn AS NVARCHAR(5))
         EXEC RDT.rdtScr2XML @nMobile, @cLangCode, NULL, '1', 'Screen not setup:', @cXML OUTPUT
         EXEC RDT.rdtScr2XML @nMobile, @cLangCode, NULL, '2', @cScn, @cXML OUTPUT
         EXEC RDT.rdtScr2XML @nMobile, @cLangCode, NULL, '4', 'Try ESC to go back', @cXML OUTPUT
         GOTO Quit
      END
   END

   -- Loop screen objects
   SET @curSD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ScnKey 
      FROM rdt.rdtScnDetail WITH (NOLOCK) 
      WHERE Scn = @nScn
         AND Lang_Code = @cLangCode
      ORDER BY YRow
   
   OPEN @curSD
   FETCH NEXT FROM @curSD INTO @nScnKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Build XML
      EXEC RDT.rdtScr2XML @nMobile, @cLangCode, @nScnKey, 0, '', @cXML OUTPUT
      
      FETCH NEXT FROM @curSD INTO @nScnKey
   END
      
Quit:


GO