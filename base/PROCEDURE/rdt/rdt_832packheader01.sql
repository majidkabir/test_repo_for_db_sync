SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832PackHeader01                                 */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Custom PackHeader                                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-10-30   1.0  Ung      WMS-10638 Add multi SKU carton ID         */
/************************************************************************/

CREATE PROC [RDT].[rdt_832PackHeader01] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT, 
   @nInputKey           INT, 
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5), 
   @cType               NVARCHAR( 10), --CHECK/CONFIRM
   @tConfirm            VariableTable READONLY, 
   @cDoc1Value          NVARCHAR( 20),
   @cCartonID           NVARCHAR( 20),
   @cCartonSKU          NVARCHAR( 20),
   @nCartonQTY          INT, 
   @cPackInfo           NVARCHAR( 4), 
   @cCartonType         NVARCHAR( 10), 
   @fCube               FLOAT,
   @fWeight             FLOAT,
   @cPackInfoRefNo      NVARCHAR( 20),
   @cOrderKey           NVARCHAR( 10),
   @cPackHeaderTypeSP   NVARCHAR( 20) OUTPUT,
   @cPickSlipNo         NVARCHAR( 10) OUTPUT,
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get order info
   DECLARE @cOrderGroup NVARCHAR(20)
   SELECT @cOrderGroup = OrderGroup 
   FROM Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey   
   
   IF @cOrderGroup IN ('R_R', 'R_L')
      SET @cPackHeaderTypeSP = 'LOAD'
   ELSE
      SET @cPackHeaderTypeSP = 'ORDER'
END

GO