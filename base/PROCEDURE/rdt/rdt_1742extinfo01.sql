SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1742ExtInfo01                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Drop ID in a Wave                                           */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2023-10-17  1.0  Ung      WMS-23390 Created                          */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1742ExtInfo01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nAfterStep       INT, 
   @nInputKey        INT, 
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15), 
   @cDropID          NVARCHAR( 20), 
   @cSuggLOC         NVARCHAR( 10), 
   @cPickAndDropLOC  NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @cExtendedInfo    NVARCHAR( 20) OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 1742 -- Putaway by DropID
   BEGIN
      IF @nAfterStep = 2 -- TO LOC
      BEGIN
         DECLARE @cWaveKey       NVARCHAR( 10) = ''
         DECLARE @cWaveStageLOC  NVARCHAR( 10)
         DECLARE @nTotalDropID   INT = 0
         DECLARE @nScanDropID    INT = 0

         -- Get drop ID info
         SELECT TOP 1 
            @cWaveKey = ISNULL( O.UserDefine09, '')
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.StorerKey = @cStorerKey
            AND PD.DropID = @cDropID
            AND PD.Status = '5'
         ORDER BY PD.EditDate DESC
         
         IF @cWaveKey <> ''
         BEGIN
            -- Get wave info
            SELECT @cWaveStageLOC = ISNULL( UserDefine10, '') FROM dbo.Wave WITH (NOLOCK) WHERE WaveKey = @cWaveKey
            
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
               AND PD.LOC = @cWaveStageLOC

            -- Output scan/total drop ID
            SET @cExtendedInfo = CAST( @nScanDropID AS NVARCHAR( 5)) + '/' + CAST( @nTotalDropID AS NVARCHAR( 5))
         END
      END
   END
END

GO