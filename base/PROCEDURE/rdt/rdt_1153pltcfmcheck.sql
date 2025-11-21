SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1153PltCfmCheck                                 */
/* Purpose: VAP Palletize module. Check the palletize qty whether       */
/*          withdraw/deposit of goods is correct by job + workorder     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-06-13 1.0  James      Created                                   */
/* 2016-08-23 1.1  James      Change sourcekey filter (james01)         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1153PltCfmCheck] (
   @nMobile          INT, 
   @cLangCode        NVARCHAR( 3),
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
           @cUserName            NVARCHAR( 18), 
           @cSKU                 NVARCHAR( 20),
           @nPalletizeQty        INT,
           @nQty2Withdraw        INT,
           @nInputBOMQty         INT,
           @nOutputBOMQty        INT,
           @nBOMQty              INT,
           @nQtyCompleted        INT,
           @nWD_Qty              INT,
           @nDP_Qty              INT,
           @dToday               DATETIME

   SET @nErrNo = 0

   IF OBJECT_ID('tempdb..#VAPCheck') IS NOT NULL
      DROP TABLE #VAPCheck

      CREATE TABLE #VAPCheck  (
         JobKey        NVARCHAR(10),
         WorkOrderKey  NVARCHAR(10),
         ID            NVARCHAR(18),
         SKU           NVARCHAR(20),
         Qty           INT,
         UserName      NVARCHAR( 18))

      INSERT INTO #VAPCheck (JobKey, WorkOrderKey, ID, SKU, Qty, UserName)
      SELECT JobKey, WorkOrderKey, ID, SKU, SUM( Qty), @cUserName as UserName
      FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
      WHERE JobKey = @cJobKey
      AND   WorkOrderKey = @cWorkOrderKey
      AND   [Status] = '9'
      GROUP BY JobKey, WorkOrderKey, ID, SKU

      SELECT @nPalletizeQty = SUM( Qty)
      FROM #VAPCheck

      -- (james01)
      SELECT @nDP_Qty = SUM( Qty)
      FROM dbo.Itrn WITH (NOLOCK)
      WHERE TranType = 'DP'
      AND   SourceType = 'rdt_1153VAPPltCfm01'
      AND   SourceKey IN ( SELECT RTRIM( @cWorkOrderKey) + 
                           REPLICATE('0',10 - LEN( RowRef)) + CAST( RowRef AS NVARCHAR( 10)) 
                           FROM dbo.WorkOrder_Palletize WITH (NOLOCK) 
                           WHERE JobKey = @cJobKey 
                           AND   WorkOrderKey = @cWorkOrderKey)

      IF @nPalletizeQty <> @nDP_Qty
      BEGIN
         SET @nErrNo = 100518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Deposit error'  
      END

      -- Get the output bom qty
      SELECT @nOutputBOMQty = WOO.Qty
      FROM dbo.WorkOrderRequestOutputs WRO WITH (NOLOCK) 
      JOIN WorkOrderOutputs WOO WITH (NOLOCK) ON ( WRO.WkOrdOutputskey = WOO.WkOrdOutputskey)
      JOIN #VAPCheck VAP ON ( WRO.WorkOrderKey = VAP.WorkOrderKey)

      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT WRI.SKU 
      FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
      JOIN #VAPCheck VAP ON ( WRI.WorkOrderKey = VAP.WorkOrderKey)
      WHERE VAP.JobKey = @cJobKey
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cSKU
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         -- Get the input bom qty
         SELECT @nInputBOMQty = WOI.Qty
         FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
         JOIN WorkOrderInputs WOI WITH (NOLOCK) 
            ON ( WRI.WkOrdInputskey = WOI.WkOrdInputskey AND WRI.SKU = WOI.SKU)
         JOIN #VAPCheck VAP ON ( WRI.WorkOrderKey = VAP.WorkOrderKey)
         WHERE VAP.JobKey = @cJobKey
         AND   WRI.SKU = @cSKU

         IF @nInputBOMQty = 1
            SET @nBOMQty = 1
         ELSE 
            SET @nBOMQty = @nInputBOMQty / @nOutputBOMQty

         -- Convert to BOM Qty
         SET @nQty2Withdraw = ( @nInputBOMQty * @nPalletizeQty) / @nOutputBOMQty

         -- (james01)
         SELECT @nWD_Qty = SUM( Qty)
         FROM dbo.Itrn WITH (NOLOCK)
         WHERE TranType = 'WD'
         AND   SourceType = 'rdt_1153VAPPltCfm01'
         AND   SourceKey IN ( SELECT RTRIM( @cWorkOrderKey) + 
                              REPLICATE('0',10 - LEN( RowRef)) + CAST( RowRef AS NVARCHAR( 10)) 
                              FROM dbo.WorkOrder_Uncasing WITH (NOLOCK) 
                              WHERE JobKey = @cJobKey 
                              AND   WorkOrderKey = @cWorkOrderKey)
         AND   SKU = @cSKU

         -- convert -ve qty here as WD trantype is -ve qty
         IF ( -1 * @nQty2Withdraw) <> @nWD_Qty
         BEGIN
            SET @nErrNo = 100519
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Withdraw error'  
            BREAK
         END

         FETCH NEXT FROM CUR_LOOP INTO @cSKU
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP




GO