SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803AsignExtVal03                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 08-09-2021 1.0  YeeKung  WMS-17823 Created                                 */
/******************************************************************************/
CREATE PROC [RDT].[rdt_803AsignExtVal03] (
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
   @cType       NVARCHAR(15)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCartonID NVARCHAR(20),
           @cWavekey  NVARCHAR(20)


   IF @cCurrentSP = 'rdt_PTLPiece_Assign_WaveCarton'
   BEGIN
      -- Parameter mapping
      SELECT @cCartonID = Value FROM @tVar WHERE Variable = '@cCartonID'
      SELECT @cWavekey = Value FROM @tVar WHERE Variable = '@cwavekey'

      IF @cType='CHECK'
      BEGIN

         IF NOT EXISTS( SELECT 1     
                     FROM WaveDetail WD WITH (NOLOCK)     
                        JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)    
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
                     WHERE WD.WaveKey = @cWaveKey    
                        AND (PD.Status >'0'
                        OR  PD.Status <'9')
                        AND PD.QTY > 0
                        )    
         BEGIN
            SET @nErrNo = 176501 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveEnded
            GOTO Quit
         END

         IF NOT EXISTS( SELECT 1     
                     FROM WaveDetail WD WITH (NOLOCK)     
                        JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = WD.OrderKey)    
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
                     WHERE WD.WaveKey = @cWaveKey    
                        AND pd.CaseID=''
                        AND PD.QTY > 0
                        )    
         BEGIN
            SET @nErrNo = 176503 
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAdyUsed
            GOTO Quit
         END

         IF @cCartonID<>''
         BEGIN            
            -- Check carton ID on hold
            IF EXISTS(  SELECT 1 FROM PICKDETAIL PD (NOLOCK)
                        WHERE dropid=@cCartonID
                           AND Storerkey=@cStorerKey
                           AND NOT EXISTS (SELECT 1 FROM dbo.PackHeader PH (NOLOCK)
                                           WHERE PH.OrderKey=PD.OrderKey
                                           AND PH.Status='9'))
            BEGIN
               SET @nErrNo = 176502 
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAdyUsed
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO