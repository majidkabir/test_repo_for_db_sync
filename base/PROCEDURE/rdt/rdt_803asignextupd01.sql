SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_803AsignExtUpd01                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 25-02-2021 1.0  yeekung  WMS-16220 Created                                 */
/* 25-09-2023 1.1  yeekung  WMS-23257 Add model type (yeekung01)              */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_803AsignExtUpd01] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cFacility   NVARCHAR( 5) ,
   @cStorerKey  NVARCHAR( 10),
   @cStation    NVARCHAR( 10),
   @cMethod     NVARCHAR( 15),
   @cCurrentSP  NVARCHAR( 60),
   @tVar        VariableTable READONLY,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBatchkey NVARCHAR(20),
           @cDevicePos nvarchar(100),
           @cType NVARCHAR(20),
           @cDeviceStatus NVARCHAR(1),
           @c_DeviceModel NVARCHAR(20),
           @bSuccess       INT,
           @cIPAddress     NVARCHAR(20) =''


   IF @cCurrentSP = 'rdt_PTLPiece_Assign_Batch'
   BEGIN
      -- Parameter mapping
      SELECT @cBatchkey = Value FROM @tVar WHERE Variable = '@cBatchKey'

      SELECT @cType = Value FROM @tVar WHERE Variable = '@cType'


      IF @cType='CHECK'
      BEGIN
         --SELECT top 1 @cDevicePos=deviceposition
         --FROM deviceprofile WITH (NOLOCK)
         --WHERE deviceid = @cStation

         --exec [PTL].[isp_PTL_Light_TMS]
         --   @n_Func          = @nFunc
         --  ,@n_PTLKey        = 0
         --  ,@b_Success       = 0
         --  ,@n_Err           = @nErrNo
         --  ,@c_ErrMsg        = @cErrMsg OUTPUT
         --  ,@c_DeviceID      = @cStation
         --  ,@c_DevicePos     = @cDevicePos
         --  ,@c_DeviceIP      = ''
         --  ,@c_DeviceStatus  = '0'

         --IF @nErrNo<>0
         --   GOTO QUIt

         SELECT TOP 1 @cDevicePos=deviceposition,
                     @c_DeviceModel = devicemodel
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID = @cStation

         
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = ''
            ,@b_Success        = @bSuccess    OUTPUT
            ,@n_Err            = @nErrNo      OUTPUT
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cDevicePos
            ,@c_DeviceIP       = @cIPAddress
            ,@c_LModMode       = 0
            ,@c_DeviceModel    = @c_DeviceModel

         IF @nErrNo<>0
            GOTO QUIt

      END
      ELSE IF @nStep='4'
      BEGIN

         DECLARE @cLightPos nvarchar(20)

         IF EXISTS( SELECT 1
                  FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)
                     JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE L.Station = @cStation
                     AND PD.Status <='5'
                     AND PD.CaseID = ''
                     AND PD.QTY > 0  )

         BEGIN

            DECLARE cursor_lightpos CURSOR FOR
            SELECT L.position
            FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)
               JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)
               JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            WHERE L.Station = @cStation
               AND PD.Status <='5'
               AND PD.CaseID = ''
               AND PD.QTY > 0
            GROUP BY  L.position

            OPEN cursor_lightpos
            FETCH NEXT FROM cursor_lightpos INTO @cLightPos

            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cDevicePos = CASE WHEN ISNULL(@cDevicePos,'')='' THEN @cLightPos else @cDevicePos+','+@cLightPos END

               FETCH NEXT FROM cursor_lightpos INTO @cLightPos
            END

            CLOSE cursor_lightpos
            DEALLOCATE cursor_lightpos

            SET @cDeviceStatus='1'
         END
         ELSE
         BEGIN
            SELECT top 1 @cDevicePos=deviceposition
            FROM deviceprofile WITH (NOLOCK)
            WHERE deviceid = @cStation


            SET @cDeviceStatus='0'
         END

         SELECT TOP 1 @c_DeviceModel = devicemodel
         FROM DeviceProfile WITH (NOLOCK)
         WHERE DeviceType = 'STATION'
            AND DeviceID = @cStation

         
         EXEC PTL.isp_PTL_LightUpLoc
            @n_Func           = @nFunc
            ,@n_PTLKey         = 0
            ,@c_DisplayValue   = ''
            ,@b_Success        = @bSuccess    OUTPUT
            ,@n_Err            = @nErrNo      OUTPUT
            ,@c_ErrMsg         = @cErrMsg     OUTPUT
            ,@c_DeviceID       = @cStation
            ,@c_DevicePos      = @cDevicePos
            ,@c_DeviceIP       = @cIPAddress
            ,@c_LModMode       = @cDeviceStatus
            ,@c_DeviceModel    = @c_DeviceModel

         IF @nErrNo<>0
            GOTO QUIt

         IF @nErrNo<>0
            GOTO QUIt

      END
   END

Quit:

END

GO