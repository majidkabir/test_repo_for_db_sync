SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_Case01                                */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Force to show case count field for every sku received       */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 26-08-2015  1.0  James        SOS350478. Created                     */
/************************************************************************/
            
CREATE PROCEDURE [RDT].[rdt_VerifySKU_Case01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 3), 
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cType            NVARCHAR( 15),
   @cLabel           NVARCHAR( 30)  OUTPUT,  
   @cShort           NVARCHAR( 10)  OUTPUT,    
   @cValue           NVARCHAR( MAX) OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempPackKey      NVARCHAR( 10), 
           @nSKUCaseCnt       INT, 
           @nCaseCnt          INT, 
           @nStartTCnt        INT 

   SET @nStartTCnt = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_VerifySKU_Case01  

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      IF EXISTS ( SELECT 1 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE MOBILE = @nMobile AND ISNULL( V_LoadKey, '') <> '')
         SET @nErrNo = 0 --No need show
      ELSE
         SET @nErrNo = -1 --Need show
   END

   IF @cType = 'UPDATE'
   BEGIN
      SELECT @nSKUCaseCnt = CaseCnt 
      FROM dbo.Pack Pack WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON Pack.PackKey = SKU.PackKey
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU

      -- If sku having case count <=1 then update the existing packkey else ignore
      IF ISNULL( @nSKUCaseCnt, 0) <= 1 
      BEGIN
         IF rdt.rdtIsValidQty( @cValue, 1) = 0 -- check for zero
         BEGIN
            SET @nErrNo = 56851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case
            GOTO Quit
         END

         SET @cTempPackKey = RTRIM( @cStorerKey) + RIGHT( '0000' + CAST( @cValue AS NVARCHAR( 4)), 4)
         SELECT @nCaseCnt = CaseCnt FROM dbo.Pack WITH (NOLOCK) WHERE PackKey = @cTempPackKey
         
         IF @nCaseCnt IS NULL OR @nCaseCnt = 0
         BEGIN
            INSERT INTO dbo.Pack ( PackKey, PackDescr, PackUOM1, CaseCnt, PackUOM3, Qty) VALUES 
            (@cTempPackKey, @cTempPackKey, 'CTN', @cValue, 'PC', '1')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 56852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Create Case fail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            IF @nCaseCnt = 1 AND @cValue > 1
            BEGIN
               UPDATE Pack WITH (ROWLOCK) SET
                     CaseCNT = @cValue
               WHERE PackKey = @cTempPackKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 56853
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Case Fail
                  GOTO Quit
               END
            END
         END

         UPDATE dbo.SKU WITH (ROWLOCK) SET 
            PackKey = @cTempPackKey 
         WHERE StorerKey = @cStorerKey 
         AND   SKU = @cSKU

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 56854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Case fail
            GOTO Quit
         END                  
      END

      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET 
         V_LoadKey = @cValue 
      WHERE MOBILE = @nMobile

      IF @@ERROR <> 0
         SET @nErrNo = 0 --No need show
      ELSE
         GOTO Quit
   END

   Quit:
   IF @nErrNo <> 0  -- Error Occured - Process And Return  
      ROLLBACK TRAN rdt_VerifySKU_Case01  
  
   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started  
      COMMIT TRAN rdt_VerifySKU_Case01  
   
END

GO