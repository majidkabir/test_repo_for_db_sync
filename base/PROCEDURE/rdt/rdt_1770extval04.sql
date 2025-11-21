SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1770ExtVal04                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-08-23   Ung       1.0   WMS-26055 Created                       */
/* 2024-11-11   PXL009    1.1   FCR-1124 Merged 1.0 from v0 branch      */
/*                              the original name is rdt_1770ExtVal03   */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1770ExtVal04]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nQTY            INT
   ,@cToLOC          NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nStep = 4 -- ToLOC, DropID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check DropID
            IF @cDropID = ''
            BEGIN
               SET @nErrNo = 228901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need DropID
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END

            -- Get storer
            DECLARE @cStorerKey NVARCHAR(15)
            SELECT @cStorerKey = StorerKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey

            -- Get order (1 pallet 1 order)
            DECLARE @cOrderKey NVARCHAR(10)
            SELECT TOP 1 
               @cOrderKey = OrderKey 
            FROM dbo.PickDetail WITH (NOLOCK) 
            WHERE TaskDetailKey = @cTaskDetailKey
            
            -- Get order info
            DECLARE @cFacility NVARCHAR(5)
            DECLARE @cWaveKey NVARCHAR(10)
            DECLARE @cShipperKey NVARCHAR(15)
            SELECT 
               @cFacility = Facility, 
               @cWaveKey = UserDefine09, 
               @cShipperKey = ISNULL( ShipperKey, '') 
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey 
            
            /*
               Check order in different outbound lane. 1 order 1 outbound lane.
               To LOC is the outbound door location
               Drop ID is the outbound lane (1 door multiple lanes)
            */
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.TaskDetail TD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (TD.TaskDetailKey = PD.TaskDetailKey)
               WHERE PD.OrderKey = @cOrderKey
                  AND TD.StorerKey = @cStorerKey
                  AND TD.TaskType = 'FPK'
                  AND TD.Status = '9'
                  AND TD.DropID <> @cDropID)
            BEGIN
               SET @nErrNo = 228902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff lane
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END
            
            -- Check lane is same shipper
            IF EXISTS( SELECT TOP 1 1 
               FROM dbo.MBOL M WITH (NOLOCK) 
                  JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON (M.MBOLKey = MD.MBOLKey)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey)
               WHERE M.Facility = @cFacility
                  AND M.Status < '9'
                  AND M.ExternMBOLKey = @cDropID
                  AND O.ShipperKey <> @cShipperKey)
            BEGIN
               SET @nErrNo = 228903
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff Shipper
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END
            
            -- Check 1 wave 1 lane
            IF EXISTS( SELECT 1 
               FROM dbo.MBOL M WITH (NOLOCK)
            	   JOIN dbo.Orders O WITH (NOLOCK) ON (O.MBOLKey = M.MBOLKey)
            	WHERE O.StorerKey = @cStorerKey
               	AND O.UserDefine09 = @cWaveKey
               	AND M.ExternMBOLKey <> @cDropID
               	AND M.Status < '9')
            BEGIN
               SET @nErrNo = 228904
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff wave
               EXEC rdt.rdtSetFocusField @nMobile, 4 -- DropID
               GOTO Quit
            END
         END
      END
   END
   GOTO Quit

Quit:

END

GO