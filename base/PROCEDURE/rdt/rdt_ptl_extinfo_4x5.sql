SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PTL_ExtInfo_4X5                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Light Up Cart for 20 Positions  (4 X 5)                     */
/*                                                                      */
/* Called from: rdtfnc_PTL_OrderAssignment                              */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 23-06-2014 1.0  James    SOS303322 - Created                         */
/* 24-10-2014 1.1  Ung      SOS318953 support 3x3 for cart with light   */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_ExtInfo_4X5] (
    @nMobile         INT           
   ,@nFunc           INT           
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT           
   ,@nInputKey       INT           
   ,@cCartID         NVARCHAR( 10) 
   ,@cResult01       NVARCHAR( 20)     OUTPUT  
   ,@cResult02       NVARCHAR( 20)     OUTPUT  
   ,@cResult03       NVARCHAR( 20)     OUTPUT  
   ,@cResult04       NVARCHAR( 20)     OUTPUT  
   ,@cResult05       NVARCHAR( 20)     OUTPUT  
   ,@cResult06       NVARCHAR( 20)     OUTPUT  
   ,@cResult07       NVARCHAR( 20)     OUTPUT  
   ,@cResult08       NVARCHAR( 20)     OUTPUT  
   ,@cResult09       NVARCHAR( 20)     OUTPUT  
   ,@cResult10       NVARCHAR( 20)     OUTPUT  
   ,@nErrNo           INT              OUTPUT
   ,@cErrMsg          NVARCHAR(20)     OUTPUT -- screen limitation, 20 char max
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cOutfield           NVARCHAR( 20),
            @cOrderKey           NVARCHAR( 10), 
            @cLightLoc           NVARCHAR( 10), 
            @cEmptyLoc           NVARCHAR( 5), 
            @nCartLocCounter     INT, 
            @cDeviceID           NVARCHAR(10)
   
   IF @nStep <> 2 AND @nInputKey <> 0
      GOTO Quit
   
   SET @cEmptyLoc = 'XXXXX'

   -- Get login info                                                                    
   SELECT @cDeviceID = DeviceID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nCartLocCounter = 1
   DECLARE CursorLightLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT LL.DevicePosition, LD.OrderKey
   FROM dbo.DeviceProfile LL WITH (NOLOCK)
   LEFT JOIN dbo.DeviceProfileLog LD WITH (NOLOCK) ON LD.DeviceProfileKey = LL.DeviceProfileKey AND LD.Status = '1'
   WHERE LL.DeviceID = @cCartID
   AND   LL.Status = '1'
   Order By DevicePosition 
     
   OPEN CursorLightLoc            
   FETCH NEXT FROM CursorLightLoc INTO @cLightLoc, @cOrderKey
   WHILE @@FETCH_STATUS <> -1            
   BEGIN 
      IF ISNULL(@cOrderKey,'') = ''
         SET @cOutfield = @cLightLoc
      ELSE
         SET @cOutfield = 'XXXX'
        
      IF @cDeviceID <> '' -- 3x3
      BEGIN
         -- Right align
         SET @cOutfield = RIGHT( SPACE(5) + @cOutfield, 5)
         
         IF @nCartLocCounter BETWEEN 1 AND 3 SET @cResult01 = @cResult01 + @cOutfield + '|'
         IF @nCartLocCounter BETWEEN 4 AND 6 SET @cResult02 = @cResult02 + @cOutfield + '|'
         IF @nCartLocCounter BETWEEN 7 AND 9 SET @cResult03 = @cResult03 + @cOutfield + '|'
      END
      
      IF @cDeviceID = '' -- 4x5
      BEGIN
         IF @nCartLocCounter <= 4
            SET @cResult01 = @cResult01 + RTRIM( @cOutfield) + SPACE( 5-LEN( @cOutfield))
   
         IF @nCartLocCounter > 4 AND @nCartLocCounter <= 8
            SET @cResult02 = @cResult02 + RTRIM( @cOutfield) + SPACE( 5-LEN( @cOutfield))
   
         IF @nCartLocCounter > 8 AND @nCartLocCounter <= 12
            SET @cResult03 = @cResult03 + RTRIM( @cOutfield) + SPACE( 5-LEN( @cOutfield))
   
         IF @nCartLocCounter > 12 AND @nCartLocCounter <= 16
            SET @cResult04 = @cResult04 + RTRIM( @cOutfield) + SPACE( 5-LEN( @cOutfield))
   
         IF @nCartLocCounter > 16 AND @nCartLocCounter <= 20
            SET @cResult05 = @cResult05 + RTRIM( @cOutfield) + SPACE( 5-LEN( @cOutfield))
      END
      SET @nCartLocCounter = @nCartLocCounter + 1

      FETCH NEXT FROM CursorLightLoc INTO @cLightLoc, @cOrderKey
   END
   CLOSE CursorLightLoc
   DEALLOCATE CursorLightLoc
    
   Quit:

END

GO