SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_803PTL_Confirm03                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 21-10-2020 1.0  YeeKung  WMS-15551 Created                           */
/* 29-11-2022 1.0  Ung      WMS-21170 Add DynamicSlot                   */
/************************************************************************/

CREATE   PROC [PTL].[isp_803PTL_Confirm03] (
   @cIPAddress    NVARCHAR(30),
   @cPosition     NVARCHAR(20),
   @cFuncKey      NVARCHAR(2),
   @nSerialNo     INT,
   @cInputValue   NVARCHAR(20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR(125) OUTPUT,
   @cDebug        NVARCHAR( 1) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess       INT
   DECLARE @nFunc          INT
   DECLARE @cStorerKey     NVARCHAR(15)
   DECLARE @cStation       NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)

   SET @nFunc = 803 -- PTL piece
   SET @cInputValue = RTRIM( LTRIM( @cInputValue))

   -- Get light info
   SELECT TOP 1
      @cStation = DeviceID,
      @cStorerKey = StorerKey
   FROM PTL.LightStatus WITH (NOLOCK)
   WHERE IPAddress = @cIPAddress
      AND DevicePosition = @cPosition

   /***********************************************************************************************
                                                TOTE
   ***********************************************************************************************/
   IF @cInputValue IN ('1', 'TOTE', 'END')
   BEGIN
      IF @cInputValue = 'TOTE'
      BEGIN
         -- Check carton ID had assigned at RDT
         IF EXISTS( SELECT 1 
            FROM rdt.rdtPTLPieceLog
            WHERE Station = @cStation
               AND Position = @cPosition
               AND CartonID = '')
         BEGIN
            -- Get light setting
            SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

            -- Relight up
            EXEC PTL.isp_PTL_LightUpLoc
               @n_Func           = @nFunc
              ,@n_PTLKey         = 0
              ,@c_DisplayValue   = 'TOTE'
              ,@b_Success        = @bSuccess    OUTPUT
              ,@n_Err            = @nErrNo      OUTPUT
              ,@c_ErrMsg         = @cErrMsg     OUTPUT
              ,@c_DeviceID       = @cStation
              ,@c_DevicePos      = @cPosition
              ,@c_DeviceIP       = @cIPAddress
              ,@c_LModMode       = @cLightMode
         
            GOTO Quit
         END
      END

      -- Off all lights
      EXEC PTL.isp_PTL_TerminateModule
          @cStorerKey
         ,@nFunc
         ,@cStation
         ,'STATION'
         ,@bSuccess     OUTPUT
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

Quit:

END

GO