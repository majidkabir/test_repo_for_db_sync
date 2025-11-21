SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_802ExtVal01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 24-04-2018  1.0  ChewKP      WMS-4767. Created                       */
/************************************************************************/


CREATE PROCEDURE [RDT].[rdt_802ExtVal01]
  @nMobile    INT,           
  @nFunc      INT,           
  @cLangCode  NVARCHAR( 3),  
  @nStep      INT,           
  @nInputKey  INT,           
  @cFacility  NVARCHAR( 5),  
  @cStorerKey NVARCHAR( 15), 
  @cStation   NVARCHAR( 10), 
  @cStation1  NVARCHAR( 10), 
  @cStation2  NVARCHAR( 10), 
  @cStation3  NVARCHAR( 10), 
  @cStation4  NVARCHAR( 10), 
  @cStation5  NVARCHAR( 10), 
  @cLight     NVARCHAR( 1),   
  @nErrNo     INT            OUTPUT, 
  @cErrMsg    NVARCHAR( 20)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cWaveKey       NVARCHAR(10)
               
   IF @nStep = 2 -- 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- To ID is mandatory
         DECLARE @curPTL CURSOR  
         SET @curPTL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT WaveKey
            FROM rdt.rdtPTLStationLog WITH (NOLOCK)  
            WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
         OPEN @curPTL  
         FETCH NEXT FROM @curPTL INTO @cWaveKey
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND WaveKey = @cWaveKey
                        AND CaseID = ''
                        AND Status IN ( '0', '3') )
            BEGIN
               SET @nErrNo = 123451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WaveInProgress
               GOTO Quit
            END

            FETCH NEXT FROM @curPTL INTO @cWaveKey

         END
         
        
      END
   END

 

Quit:
END

GO