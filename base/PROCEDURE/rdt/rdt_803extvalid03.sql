SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_803ExtValid03                                   */
/* Purpose: Check whether station has wavekey not yet picked             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-12-16  1.0  yeekung  WMS-21355. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_803ExtValid03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cMethod      NVARCHAR( 1),
   @cSKU         NVARCHAR( 20),
   @cLastPos     NVARCHAR( 10),
   @cOption      NVARCHAR( 1),
   @tExtValid    VariableTable READONLY,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10) = '',
           @cWavekey    NVARCHAR( 10) = ''
           

   SET @nErrNo = 0

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	-- If hav balance Task , not allow to unassign
         IF @cOption = '1' AND @cMethod in ('1','X')
         BEGIN
            SELECT @cWavekey=V_WaveKey
            FROM rdt.rdtmobrec (nolock)
            where mobile=@nMobile

         	IF EXISTS( SELECT 1
                     FROM WaveDetail WD WITH (NOLOCK)     
                        JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)    
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
                     WHERE WD.wavekey=@cWavekey
                        AND PD.Status <= '5' 
                        AND O.Status <> 'CANC'
                        AND O.SOStatus <> 'CANC'
                        AND PD.CaseID <> 'Sorted' )
            BEGIN
               SELECT @cWavekey = wavekey
               FROM rdt.rdtPTLPieceLog
               WHERE Station = @cStation

               IF EXISTS (SELECT 1 
                           FROM WAVE (NOLOCK) 
                           WHERE Wavekey=@cWavekey
                           AND userdefine02 <>'CHECK')
               BEGIN
               
            	   SET @nErrNo = 194751
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --TaskNotDone
                  GOTO Quit
               END
            END
         END
      END
   END

   Quit:

GO