SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803AsignExtVal02                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 26-11-2020 1.0  YeeKung  WMS-15702 Created                                 */
/******************************************************************************/
CREATE PROC [RDT].[rdt_803AsignExtVal02] (
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

   DECLARE @cCartonID NVARCHAR(20)


   IF @cCurrentSP = 'rdt_PTLPiece_Assign_WaveCarton'
   BEGIN
      -- Parameter mapping
      SELECT @cCartonID = Value FROM @tVar WHERE Variable = '@cCartonID'
      
      -- Check carton ID on hold
      IF EXISTS(  SELECT 1 FROM PICKDETAIL PD (NOLOCK)
                  WHERE dropid=@cCartonID
                     AND Storerkey=@cStorerKey
                     AND NOT EXISTS (SELECT 1 FROM dbo.PackHeader PH (NOLOCK)
                                     WHERE PH.OrderKey=PD.OrderKey
                                     AND PH.Status='9'))
      BEGIN
         SET @nErrNo = 161001 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartonAdyUsed
         GOTO Quit
      END
   END

Quit:

END

GO