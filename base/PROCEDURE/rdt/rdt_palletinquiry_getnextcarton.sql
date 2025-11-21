SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_PalletInquiry_GetNextCarton                     */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_PalletInquiry                                    */    
/*                                                                      */    
/* Purpose: Get next carton id from pallet                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-09-20  1.0  James    WMS-20742. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_PalletInquiry_GetNextCarton] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cOrderKey      NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cOption        NVARCHAR( 1), 
   @cPalletKey     NVARCHAR( 20) OUTPUT,
   @cCartonId01    NVARCHAR( 20) OUTPUT,
   @cCartonId02    NVARCHAR( 20) OUTPUT,
   @cCartonId03    NVARCHAR( 20) OUTPUT,
   @cCartonId04    NVARCHAR( 20) OUTPUT,
   @cCartonId05    NVARCHAR( 20) OUTPUT,
   @cCartonId06    NVARCHAR( 20) OUTPUT,
   @tGetNextCarton VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cGetNextCartonSP  NVARCHAR( 20)

   -- Get storer config
   SET @cGetNextCartonSP = rdt.RDTGetConfig( @nFunc, 'GetNextCartonSP', @cStorerKey)
   IF @cGetNextCartonSP = '0'
      SET @cGetNextCartonSP = ''

   /***********************************************************************************************
                                    Custom Get Next Carton SP
   ***********************************************************************************************/
   -- Check confirm SP blank
   IF @cGetNextCartonSP <> ''
   BEGIN
      -- Confirm SP
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetNextCartonSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cPalletKey, @cOrderKey, @cCartonId, @cOption, ' +
         ' @cCartonId01 OUTPUT, @cCartonId02 OUTPUT, @cCartonId03 OUTPUT, ' +
         ' @cCartonId04 OUTPUT, @cCartonId05 OUTPUT, @cCartonId06 OUTPUT, ' +
         ' @tGetNextCarton, @nErrNo OUTPUT, @cErrMsg OUTPUT '
      SET @cSQLParam =
         ' @nMobile        INT,           ' +
         ' @nFunc          INT,           ' +
         ' @cLangCode      NVARCHAR( 3),  ' +
         ' @nStep          INT,           ' +
         ' @nInputKey      INT,           ' +
         ' @cFacility      NVARCHAR( 5) , ' +
         ' @cStorerKey     NVARCHAR( 15), ' +
         ' @cPalletKey     NVARCHAR( 20), ' +
         ' @cOrderKey      NVARCHAR( 10), ' +
         ' @cCartonId      NVARCHAR( 20), ' +
         ' @cOption        NVARCHAR( 10), ' +
         ' @cCartonId01    NVARCHAR( 20) OUTPUT, ' +
         ' @cCartonId02    NVARCHAR( 20) OUTPUT, ' +
         ' @cCartonId03    NVARCHAR( 20) OUTPUT, ' +
         ' @cCartonId04    NVARCHAR( 20) OUTPUT, ' +
         ' @cCartonId05    NVARCHAR( 20) OUTPUT, ' +
         ' @cCartonId06    NVARCHAR( 20) OUTPUT, ' +
         ' @tGetNextCarton VariableTable READONLY, ' +
         ' @nErrNo         INT           OUTPUT, ' +
         ' @cErrMsg        NVARCHAR(250) OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cPalletKey, @cOrderKey, @cCartonId, @cOption,
         @cCartonId01 OUTPUT, @cCartonId02 OUTPUT, @cCartonId03 OUTPUT,
         @cCartonId04 OUTPUT, @cCartonId05 OUTPUT, @cCartonId06 OUTPUT,
         @tGetNextCarton, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END

   /***********************************************************************************************
                                    Standard Get Next Carton SP
   ***********************************************************************************************/
   DECLARE @cCurPalletKey  NVARCHAR( 20)
   DECLARE @cCaseId        NVARCHAR( 20)
   DECLARE @n              INT = 0
   DECLARE @curCtn         CURSOR
   DECLARE @curNextCtn     CURSOR
   
   SET @cCurPalletKey = @cPalletKey

   IF @nStep = 4
      SET @cPalletKey = '' -- Retrieve next pallet info
            
   SET @cCartonId01 = ''
   SET @cCartonId02 = ''
   SET @cCartonId03 = ''
   SET @cCartonId04 = ''
   SET @cCartonId05 = ''
   SET @cCartonId06 = ''
   SET @n = 1
   SET @curCtn = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT CaseId
   FROM dbo.PALLETDETAIL WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   PalletKey = @cPalletKey
   AND   UserDefine01 = @cOrderKey
   ORDER BY 1
   OPEN @curCtn
   FETCH NEXT FROM @curCtn INTO @cCaseId
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @n = 1
         SET @cCartonId01 = @cCaseId
      IF @n = 2
         SET @cCartonId02 = @cCaseId
      IF @n = 3
         SET @cCartonId03 = @cCaseId
      IF @n = 4
         SET @cCartonId04 = @cCaseId
      IF @n = 5
         SET @cCartonId05 = @cCaseId
      IF @n = 6
         SET @cCartonId06 = @cCaseId

      SET @n = @n + 1
      IF @n > 6
         BREAK

      FETCH NEXT FROM @curCtn INTO @cCaseId
   END

   SET @n = 1
   IF @cCartonId01 = ''
   BEGIN
      SET @curNextCtn = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PalletKey, CaseId
      FROM dbo.PALLETDETAIL WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   PalletKey > @cCurPalletKey
      AND   UserDefine01 = @cOrderKey
      ORDER BY 1, 2
      OPEN @curNextCtn
      FETCH NEXT FROM @curNextCtn INTO @cPalletKey, @cCaseId
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @n = 1
            SET @cCartonId01 = @cCaseId
         IF @n = 2
            SET @cCartonId02 = @cCaseId
         IF @n = 3
            SET @cCartonId03 = @cCaseId
         IF @n = 4
            SET @cCartonId04 = @cCaseId
         IF @n = 5
            SET @cCartonId05 = @cCaseId
         IF @n = 6
            SET @cCartonId06 = @cCaseId

         SET @n = @n + 1
         IF @n > 6
            BREAK

         FETCH NEXT FROM @curNextCtn INTO @cPalletKey, @cCaseId
      END
      
      IF @cCartonId01 = ''
      BEGIN
      	SET @cPalletKey = @cCurPalletKey
         SET @nErrNo = 191801
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No More Rec
         GOTO Quit
      END
   END
   
   Quit:
END

GO