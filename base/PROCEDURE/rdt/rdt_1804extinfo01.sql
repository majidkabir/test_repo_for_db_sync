SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1804ExtInfo01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 11-08-2017 1.0 Ung         WMS-2656 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1804ExtInfo01] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1804 -- Move to UCC
   BEGIN
      IF @nAfterStep = 7 -- UCC
      BEGIN
         -- Variable mapping
         DECLARE @cToID NVARCHAR(18)
         SELECT @cToID = Value FROM @tVar WHERE Variable = '@cToID'

         IF @cToID <> ''
         BEGIN
            DECLARE @nUCCCount INT
            SELECT @nUCCCount = ISNULL( COUNT( DISTINCT UCCNO), 0)
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = 'MHT' 
               AND ID = @cToID
               AND Status = '1'
            
            DECLARE @cMsg NVARCHAR(20)
            SET @cMsg = rdt.rdtgetmessage( 113651, @cLangCode, 'DSP') --UCC ON ID: 

            SET @cExtendedInfo = RTRIM( @cMsg) + ' ' + CAST( @nUCCCount AS NVARCHAR(5))
         END
      END
   END

Quit:

END

GO