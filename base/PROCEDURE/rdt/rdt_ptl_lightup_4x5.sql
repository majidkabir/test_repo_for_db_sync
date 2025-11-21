SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTL_LightUp_4X5                                       */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Light Up Cart for 20 Positions  (4 X 5)                           */
/*                                                                            */
/* Called from: rdtfnc_PTL_OrderPicking                                       */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 23-06-2014 1.0  James    SOS303322 - Created                               */
/* 03-10-2014 1.1  Ung      SOS318953 Chg BypassTCPSocketClient to DeviceID   */
/*                          Display 3x3 or 4x5 base on DeviceID               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_PTL_LightUp_4X5] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR( 5)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cCartID          NVARCHAR( 10)  
    ,@cSKU             NVARCHAR( 20)
    ,@cLoc             NVARCHAR( 10)
    ,@cLot             NVARCHAR( 10)
    ,@cPDDropID        NVARCHAR( 20) 
    ,@cPDLoc           NVARCHAR( 20) 
    ,@cPDToLoc         NVARCHAR( 20) 
    ,@cLottable01      NVARCHAR( 18) 
    ,@cLottable02      NVARCHAR( 18) 
    ,@cLottable03      NVARCHAR( 18) 
    ,@dLottable04      DATETIME     
    ,@dLottable05      DATETIME     
    ,@cPDID            NVARCHAR( 20) 
    ,@cWaveKey         NVARCHAR( 10) 
    ,@cResult01        NVARCHAR( 20)  OUTPUT
    ,@cResult02        NVARCHAR( 20)  OUTPUT
    ,@cResult03        NVARCHAR( 20)  OUTPUT
    ,@cResult04        NVARCHAR( 20)  OUTPUT
    ,@cResult05        NVARCHAR( 20)  OUTPUT
    ,@cResult06        NVARCHAR( 20)  OUTPUT
    ,@cResult07        NVARCHAR( 20)  OUTPUT
    ,@cResult08        NVARCHAR( 20)  OUTPUT
    ,@cResult09        NVARCHAR( 20)  OUTPUT
    ,@cResult10        NVARCHAR( 20)  OUTPUT
    ,@cUserName        NVARCHAR( 18)  
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT             OUTPUT
    ,@cErrMsg          NVARCHAR(20)    OUTPUT -- screen limitation, 20 char max
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @n_err                 INT
          , @c_errmsg              NVARCHAR(250)
          , @nTranCount            INT
          , @bDebug                INT
          , @cOrderKey             NVARCHAR(10)
          , @nExpectedQty          INT
          , @cIPAddress            NVARCHAR(40)      
          , @cLightMode            NVARCHAR(4)
          , @nPTLTranKey           INT
          , @cDevicePosition       NVARCHAR(10)
          , @nCounter              INT
          , @nDebug                INT
          , @nDevicePosition       INT
          , @cQty                  NVARCHAR(5)
          , @cResult               NVARCHAR(MAX) 
          , @nPositionCnt          INT 
          , @cDeviceID             NVARCHAR(10)
          
    SET @nPTLTranKey       = 0 
    SET @cOrderKey         = ''
    SET @nExpectedQty      = 0
    SET @cIPAddress        = ''
    SET @cDevicePosition   = ''
    SET @cResult           = ''
    SET @nCounter          = 1

   SET @cLightMode = ''
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   -- Get login info                                                                    
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   DECLARE @t_PositionQty TABLE (Seq INT IDENTITY(1,1) NOT NULL, DevicePosition NVARCHAR(5), Qty NVARCHAR(5) )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT DISTINCT DevicePosition
   FROM dbo.DeviceProfile WITH (NOLOCK)
   WHERE DeviceID = @cCartID
   AND   [Status] IN ('1', '3')
   ORDER BY DevicePosition

   OPEN CUR_LOOP 
   FETCH NEXT FROM CUR_LOOP INTO @cDevicePosition
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      INSERT INTO @t_PositionQty ( DevicePosition, Qty) 
      VALUES ( @cDevicePosition , '0')

      FETCH NEXT FROM CUR_LOOP INTO @cDevicePosition
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
    
   SET @nDebug = 0
    
   IF @nDebug = 1
   BEGIN
      SELECT @cStorerKey '@cStorerKey'
         ,@cCartID '@cCartID'
         ,@cSKU '@cSKU'           
         ,@cLoc '@cLoc'          
         ,@cLot '@cLot'         
    END

   DECLARE CursorPTLTranLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT PTL.PTLKey, PTL.IPAddress, PTL.DevicePosition, PTL.ExpectedQty
   FROM dbo.PTLTran PTL WITH (NOLOCK)
   INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = PTL.SourceKey ) -- (ChewKP01) 
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = PTL.Lot  -- (ChewKP01)
   WHERE PTL.DeviceID = @cCartID
   AND PTL.Status     = '0'
   AND PTL.SKU        = @cSKU
   AND PTL.Loc        = CASE WHEN ISNULL(PD.ToLoc,'') = '' THEN @cPDLoc ELSE @cPDToLoc END
   AND PTL.Lot        = @cLot
   AND PD.SKU         = @cSKU
   AND PD.DropID      = @cPDDropID
   AND LA.Lottable01  = @cLottable01 
   AND LA.Lottable02  = @cLottable02 
   AND LA.Lottable03  = @cLottable03 
   AND LA.Lottable04  = @dLottable04 
   AND LA.Lottable05  = @dLottable05 
   AND PD.ID          = @cPDID       
   AND O.UserDefine09 = CASE WHEN ISNULL(@cPDToLoc,'') <> '' THEN @cWaveKey ELSE O.UserDefine09 END   -- (ChewKP01)
   ORDER BY DevicePosition
    
   OPEN CursorPTLTranLightUp            

   FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      IF @nDebug = 1
      BEGIN
         SELECT @nPTLTranKey '@nPTLTranKey'
            ,@cIPAddress '@cIPAddress'
            ,@cDevicePosition '@cDevicePosition'           
            ,CAST(@nExpectedQty AS NVARCHAR(5)) '@nExpectedQty'          
      END

      IF @cDeviceID <> ''
      BEGIN
         EXEC [dbo].[isp_DPC_LightUpLoc] 
            @c_StorerKey = @cStorerKey 
           ,@n_PTLKey    = @nPTLTranKey    
           ,@c_DeviceID  = @cCartID  
           ,@c_DevicePos = @cDevicePosition 
           ,@n_LModMode  = @cLightMode  
           ,@n_Qty       = @nExpectedQty       
           ,@b_Success   = @b_Success   OUTPUT  
           ,@n_Err       = @nErrNo      OUTPUT
           ,@c_ErrMsg    = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
         BEGIN
            GOTO Quit  
         END
      END

      UPDATE @t_PositionQty SET 
         Qty = @nExpectedQty
      WHERE DevicePosition = @cDevicePosition

      FETCH NEXT FROM CursorPTLTranLightUp INTO @nPTLTranKey, @cIPAddress, @cDevicePosition, @nExpectedQty
   END
   CLOSE CursorPTLTranLightUp            
   DEALLOCATE CursorPTLTranLightUp  

   SET @cResult01   = ''
   SET @cResult02   = ''
   SET @cResult03   = ''
   SET @cResult04   = ''
   SET @cResult05   = ''
   SET @cResult06   = ''
   SET @cResult07   = ''
   SET @cResult08   = ''
   SET @cResult09   = ''
   SET @cResult10   = ''

   UPDATE @t_PositionQty SET DevicePosition = 'XXXX' WHERE Qty = '0'
   
   SET @nCounter = 1
   
   -- Insert All Position to the Temp Table
   DECLARE CursorPTLTranLightPosition CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   SELECT DevicePosition , Qty
   FROM @t_PositionQty
   ORDER BY Seq
   OPEN CursorPTLTranLightPosition            
   FETCH NEXT FROM CursorPTLTranLightPosition INTO @cDevicePosition, @cQty
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      IF @cDeviceID <> '' -- 3x3
      BEGIN
         -- Right align
         SET @cQTY = RIGHT( SPACE(5) + @cQTY, 5)
         
         IF @nCounter BETWEEN 1 AND 3 SET @cResult01 = @cResult01 + @cQTY + '|'
         IF @nCounter BETWEEN 4 AND 6 SET @cResult02 = @cResult02 + @cQTY + '|'
         IF @nCounter BETWEEN 7 AND 9 SET @cResult03 = @cResult03 + @cQTY + '|'
      END
      
      IF @cDeviceID = '' -- 4x5
      BEGIN
         IF @nCounter <=4
         BEGIN
            SET @cResult01 = @cResult01 + RTRIM( @cDevicePosition) + SPACE(5-LEN(@cDevicePosition))
            SET @cResult02 = @cResult02 + RTRIM( @cQty) + SPACE(5-LEN(@cQty))
         END
   
         IF @nCounter > 4 AND @nCounter <=8
         BEGIN
            SET @cResult03 = @cResult03 + RTRIM( @cDevicePosition) + SPACE(5-LEN(@cDevicePosition))
            SET @cResult04 = @cResult04 + RTRIM( @cQty) + SPACE(5-LEN(@cQty))
         END
   
         IF @nCounter > 8 AND @nCounter <=12
         BEGIN
            SET @cResult05 = @cResult05 + RTRIM( @cDevicePosition) + SPACE(5-LEN(@cDevicePosition))
            SET @cResult06 = @cResult06 + RTRIM( @cQty) + SPACE(5-LEN(@cQty))
         END
   
         IF @nCounter > 12 AND @nCounter <=16
         BEGIN
            SET @cResult07 = @cResult07 + RTRIM( @cDevicePosition) + SPACE(5-LEN(@cDevicePosition))
            SET @cResult08 = @cResult08 + RTRIM( @cQty) + SPACE(5-LEN(@cQty))
         END
   
         IF @nCounter > 16 AND @nCounter <=20
         BEGIN
            SET @cResult09 = @cResult09 + RTRIM( @cDevicePosition) + SPACE(5-LEN(@cDevicePosition))
            SET @cResult10 = @cResult10 + RTRIM( @cQty) + SPACE(5-LEN(@cQty))
         END
      END
      
      SET @nCounter = @nCounter + 1
      FETCH NEXT FROM CursorPTLTranLightPosition INTO @cDevicePosition, @cQty
   END
   CLOSE CursorPTLTranLightPosition            
   DEALLOCATE CursorPTLTranLightPosition  
    
   Quit:

END

GO