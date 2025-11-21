SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_868ExtVal03                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: For UAOrder group must enter carton type & weight           */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 14-May-2021 1.0  James     WMS16960. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtVal03] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderGroup    NVARCHAR( 20)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @nNeedWeight    INT = 0
   
   SET @nErrNo = 0

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 7 -- Packinfo
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            --SELECT @cOrderGroup = OrderGroup, 
            --       @cShipperKey = ShipperKey
            --FROM dbo.ORDERS WITH (NOLOCK) 
            --WHERE OrderKey = @cOrderKey
               
            --IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
            --            WHERE LISTNAME = 'UAOrder' 
            --            AND   Short = @cOrderGroup 
            --            AND   Long = @cShipperKey)
            --   SET @nNeedWeight = 1

            --IF @nNeedWeight = 0
            --BEGIN
            --   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
            --               WHERE LISTNAME = 'UAOrder' 
            --               AND   ISNULL( Long, '') = '') 
            --               AND ISNULL( @cShipperKey, '') = ''
            --      SET @nNeedWeight = 1
            --END
            
            --IF @nNeedWeight = 1
               SET @nErrNo = -1  -- Not allow to esc
         END
      END
   END

Fail:
Quit:

END

GO