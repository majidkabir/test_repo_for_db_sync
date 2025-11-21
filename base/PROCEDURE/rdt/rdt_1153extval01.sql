SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1153ExtVal01                                    */
/* Purpose: Extended validate for DGE VAP process                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-04-28 1.0  James      SOS#364044. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1153ExtVal01] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cToID                     NVARCHAR( 18), 
   @cJobKey                   NVARCHAR( 10), 
   @cWorkOrderKey             NVARCHAR( 10), 
   @cSKU                      NVARCHAR( 20), 
   @nQtyToComplete            INT, 
   @cPrintLabel               NVARCHAR( 10), 
   @cEndPallet                NVARCHAR( 10), 
   @dStartDate                DATETIME,      
   @cType                     NVARCHAR( 1),   
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cUnCasingSKU      NVARCHAR( 20),
           @nUnCasingQty      INT,
           @nWRI_QtyRel       INT
   DECLARE 
   @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),
   @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),
   @cErrMsg5    NVARCHAR( 20)


   DECLARE CUR_CHK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT SKU, ISNULL( SUM( QTYRemaining), 0) 
   FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
   WHERE StorerKey = @cStorerkey
   AND   JobKey = @cJobKey
   AND   ( ( QTY - QTYRemaining) > QtyCompleted OR 
            [Status] < '9')
   GROUP BY SKU
   OPEN CUR_CHK
   FETCH NEXT FROM CUR_CHK INTO @cUnCasingSKU, @nUnCasingQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SELECT @nWRI_QtyRel = ISNULL( SUM( QtyReleased), 0)
      FROM dbo.WorkOrderRequestInputs WITH (NOLOCK) 
      WHERE StorerKey = @cStorerkey
      AND   SKU = @cUnCasingSKU
      AND   WorkOrderKey IN ( SELECT DISTINCT WorkOrderKey
                              FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerkey
                              AND   JobKey = @cJobKey
                              AND   ( ( QTY - QTYRemaining) > QtyCompleted OR 
                                       [Status] < '9'))

      -- If qty for SKU not yet released
      IF @nWRI_QtyRel = 0 OR @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = rdt.rdtgetmessage( 99951, @cLangCode, 'DSP') -- NOT ALL INPUT
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 99952, @cLangCode, 'DSP'), 7, 14) -- COMPONENTS
         SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 99953, @cLangCode, 'DSP'), 7, 14) -- UNCASED !!
         SET @cErrMsg4 = 'SKU = ' + @cUnCasingSKU
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
              @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
         END

         GOTO Quit
      END
      /*
      -- If qty released for job is < uncased qty
      IF @nUnCasingQty > @nWRI_QtyRel
      BEGIN
         SET @nErrNo = 0
         SET @cErrMsg1 = rdt.rdtgetmessage( 99954, @cLangCode, 'DSP') -- UNCASED QTY
         SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 99955, @cLangCode, 'DSP'), 7, 14) -- > RELEASED QTY
         SET @cErrMsg3 = 'SKU = ' + @cUnCasingSKU
         SET @cErrMsg4 = 'Uncased = ' + CAST( @nUnCasingQty AS NVARCHAR( 5))
         SET @cErrMsg5 = 'Released = ' + CAST( @nWRI_QtyRel AS NVARCHAR( 5))
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
              @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5
         IF @nErrNo = 1
         BEGIN
            SET @cErrMsg1 = ''
            SET @cErrMsg2 = ''
            SET @cErrMsg3 = ''
            SET @cErrMsg4 = ''
            SET @cErrMsg5 = ''
         END

         GOTO Quit
      END*/

      FETCH NEXT FROM CUR_CHK INTO @cUnCasingSKU, @nUnCasingQty
   END
   CLOSE CUR_CHK
   DEALLOCATE CUR_CHK

   QUIT:

GO