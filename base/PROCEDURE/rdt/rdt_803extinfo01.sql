SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803Extinfo01                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 08-09-2021 1.0  YeeKung  WMS-17823 Created                                 */
/******************************************************************************/
CREATE PROC [RDT].[rdt_803Extinfo01] (
   @nMobile     INT,           
   @nFunc       INT,           
   @cLangCode   NVARCHAR( 3),  
   @nStep       INT,           
   @nInputKey   INT,           
   @cFacility   NVARCHAR( 5) , 
   @cStorerKey  NVARCHAR( 10), 
   @cStation    NVARCHAR( 1),  
   @cMethod     NVARCHAR( 15), 
   @cCurrentSP  NVARCHAR( 60), 
   @tVar        VariableTable READONLY, 
   @nErrNo      INT           OUTPUT,  
   @cErrMsg     NVARCHAR(250) OUTPUT,
   @cExtendedinfo NVARCHAR(20) OUTPUT,
   @cType       NVARCHAR(15)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCartonID NVARCHAR(20),
           @cWavekey  NVARCHAR(20),
           @nLastQTY  INT


   IF @cCurrentSP = 'rdt_PTLPiece_Assign_WaveCarton'
   BEGIN
      -- Parameter mapping
      SELECT @cCartonID = Value FROM @tVar WHERE Variable = '@cCartonID'
      SELECT @cWavekey = Value FROM @tVar WHERE Variable = '@cwavekey'

      IF @cType='POPULATE-IN'  
      BEGIN

         SELECT @nLastQTY=COUNT(1)
         FROM WaveDetail WD WITH (NOLOCK)     
            JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)    
            JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
         WHERE WD.WaveKey = @cWaveKey  
               And PD.CaseID = ''

         IF @nLastQTY=1
         BEGIN
           SET @cExtendedinfo='Wave Ended'
         END
      END
   END

Quit:

END

GO