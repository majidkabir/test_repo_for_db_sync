SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1742ExtUpd01                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Update wave staging LOC                                     */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2023-10-13  1.0  Ung      WMS-23390 Created                          */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1742ExtUpd01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5), 
   @cStorerKey       NVARCHAR( 15), 
   @cDropID          NVARCHAR( 20), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1742
   BEGIN
      IF @nStep = 2 OR  -- TO LOC
         @nStep = 3     -- Confirm TO LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @nTotalDropID   INT = 0
            DECLARE @nScanDropID    INT = 0
            DECLARE @cWaveKey       NVARCHAR( 10)
            DECLARE @nQTY_Bal       INT

            -- Get drop ID info
            SELECT TOP 1 
               @cWaveKey = ISNULL( O.UserDefine09, '')
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE O.StorerKey = @cStorerKey
               AND PD.DropID = @cDropID
               AND PD.Status = '5'

            -- Update wave staging LOC
            IF EXISTS( SELECT 1 FROM dbo.Wave WITH (NOLOCK) WHERE @cWaveKey = WaveKey AND ISNULL( UserDefine10, '') = '')
            BEGIN
               UPDATE dbo.Wave SET
                  UserDefine10 = @cToLOC, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE @cWaveKey = WaveKey
               SET @nErrNo = @@ERROR  
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Quit
               END
            END
            
            -- Total drop ID
            SELECT @nTotalDropID = COUNT( DISTINCT PD.DropID)
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE O.UserDefine09 = @cWaveKey
               AND PD.Status = '5'

            -- Scan drop ID
            SELECT @nScanDropID = COUNT( DISTINCT PD.DropID)
            FROM dbo.Orders O WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE O.UserDefine09 = @cWaveKey
               AND PD.Status = '5'
               AND PD.LOC = @cToLOC
            
            -- All picked cartons scanned
            IF @nTotalDropID = @nScanDropID
            BEGIN
               -- QTY not yet picked 
               SELECT @nQTY_Bal = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.Orders O WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               WHERE O.UserDefine09 = @cWaveKey
                  AND PD.Status = '0'
               
               -- Wave picking completed
               IF @nQTY_Bal = 0
               BEGIN
                  DECLARE @cMsg NVARCHAR( 20)
                  SET @cMsg = rdt.rdtgetmessage( 208951, @cLangCode, 'DSP') --PICKING COMPLETED
                  
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg
               END
            END
         END
      END
   END
   
Quit:

END

GO