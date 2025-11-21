SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_815ExtWaveSP02                                  */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: THGSG check wave update status                              */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2019-10-31  1.0  YeeKung   WMS-10796  Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_815ExtWaveSP02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @nStep       INT,
   @cWaveKey    NVARCHAR( 10),
   @cPTSZone    NVARCHAR( 10),
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nCountTask INT
           ,@nTranCount INT
           ,@cIPAddress NVARCHAR(40)
           ,@cDeviceProfileKey NVARCHAR(10)

   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @cIPAddress = ''


   IF @nFunc = 815
   BEGIN

      IF EXISTS ( SELECT 1   FROM rdt.rdtAssignLoc WITH (NOLOCK)
               WHERE WaveKey = @cWaveKey
               AND PTSZone = @cPTSZone)
      BEGIN
         IF NOT EXISTS ( SELECT 1   FROM rdt.rdtAssignLoc WITH (NOLOCK)
                     WHERE WaveKey = @cWaveKey
                     AND PTSZone = @cPTSZone
                     AND STATUS='0')
         BEGIN
            SET @nErrNo = 145901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTSZoneAssigned'
            EXEC rdt.rdtSetFocusField @nMobile, 5
            GOTO Quit
         END
      END

      IF EXISTS(SELECT 1 FROM dbo.DropID D WITH (NOLOCK)
               JOIN dbo.DeviceProfileLog DPL WITH (NOLOCK) ON DPL.DropID = D.DropID
               JOIN dbo.DeviceProfile DP WITH (NOLOCK) ON DPL.DeviceProfileKey = DP.DeviceProfileKey
               JOIN dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = DP.DeviceID
               WHERE DP.DeviceType = 'LOC'
                  AND Loc.PutawayZone = @cPTSZone
                  AND dpl.userdefine02<> @cWaveKey
                  AND DPL.status <>'9')
      BEGIN
         SET @nErrNo = 145902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotClose
         GOTO Quit
      END

      IF EXISTS (SELECT 1 FROM Rdt.rdtAssignLoc WITH (NOLOCK)
      WHERE Wavekey<> @cWaveKey AND Status = 0 AND PTSZone=@cPTSZone)
      BEGIN
         SET @nErrNo = 145903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenAssignmentFail'
         EXEC rdt.rdtSetFocusField @nMobile, 5
         GOTO Quit
      END

      IF NOT EXISTS(SELECT * FROM Rdt.rdtAssignLoc WITH (NOLOCK)
      WHERE Wavekey= @cWaveKey AND Status <>9 AND PTSZone=@cPTSZone)
      BEGIN

         INSERT INTO Rdt.rdtAssignLoc ( WaveKey, PTSZone, PTSLoc, PTSPosition, Status )
         SELECT  DISTINCT @cWaveKey, Loc.PutawayZone, OTL.Loc, Loc.LogicalLocation , '0' -- (ChewKP01)
         FROM dbo.WaveDetail WD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey
         INNER JOIN dbo.OrderToLocDetail OTL WITH (NOLOCK) ON OTL.OrderKey = OD.OrderKey
         INNER JOIN dbo.Loc LOC WITH (NOLOCK) ON LOC.Loc = OTL.Loc
         INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceID = Loc.Loc
         WHERE WD.WaveKey = @cWaveKey
            AND Loc.PutawayZone = @cPTSZone
            AND D.DeviceType = 'LOC'
      END

   END

   GOTO QUIT

   QUIT:

END

GO