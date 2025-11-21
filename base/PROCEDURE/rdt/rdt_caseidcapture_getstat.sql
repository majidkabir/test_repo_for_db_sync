SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: LF Logistics                                              */
/* Purpose: Calc scan and total CaseID on PickDetail.DropID             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-03-14 1.0  Ung      SOS305459 Created                           */
/* 2018-05-16 1.1  Ung      WMS-4846 CodeLKUP MHCSSCAN add StorerKey    */
/*                          Add GetStatSP                               */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_CaseIDCapture_GetStat] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @cUserName  NVARCHAR( 18),
   @cFacility  NVARCHAR( 5),
   @cStorerkey NVARCHAR( 15),
   @cOrderKey  NVARCHAR( 15),
   @nScan      INT           OUTPUT,
   @nTotal     INT           OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL       NVARCHAR( MAX)
   DECLARE @cSQLParam  NVARCHAR( MAX)
   DECLARE @cGetStatSP NVARCHAR( 20)

   SET @cGetStatSP = rdt.rdtGetConfig( @nFunc, 'GetStatSP', @cStorerKey)
   IF @cGetStatSP = '0'
      SET @cGetStatSP = ''
   
   /*----------------------------------------------------------------------------------------------
                                             Custom statistic
   ----------------------------------------------------------------------------------------------*/
   IF @cGetStatSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cGetStatSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cGetStatSP) +
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey, ' +
            ' @nScan OUTPUT, @nTotal OUTPUT '
         SET @cSQLParam =
            ' @nMobile    INT,           ' + 
            ' @nFunc      INT,           ' + 
            ' @cLangCode  NVARCHAR( 3),  ' + 
            ' @cUserName  NVARCHAR( 18), ' + 
            ' @cFacility  NVARCHAR( 5),  ' + 
            ' @cStorerkey NVARCHAR( 15), ' + 
            ' @cOrderKey  NVARCHAR( 15), ' + 
            ' @nScan      INT           OUTPUT, ' + 
            ' @nTotal     INT           OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cOrderKey,  
            @nScan OUTPUT, @nTotal OUTPUT
            
         GOTO Quit
      END
   END

   /*----------------------------------------------------------------------------------------------
                                             MH statistic
   ----------------------------------------------------------------------------------------------*/
   DECLARE @nDummy INT
   
   SET @nScan = 0
   SET @nTotal = 0
   
   -- Calc scanned case ID
   SELECT @nDummy = COUNT( 1)
   FROM PickDetail PD WITH (NOLOCK) 
         JOIN LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
   WHERE PD.OrderKey = @cOrderKey 
      AND PD.UOM IN ('1', '2')
      AND PD.Status <> '4' --Short
      AND PD.QTY > 0
      AND PD.DropID <> '' -- Scanned
   GROUP BY LA.Lottable02, PD.DropID
   SET @nScan = @@ROWCOUNT

   -- Get order QTY
   SELECT @nTotal = ISNULL( SUM( A.CartonCount), 0)
   FROM 
   (
      SELECT ISNULL( SUM( PD.QTY) / 
         CASE WHEN CAST( MIN( Pack.CaseCnt) AS INT) = 0 THEN 1 
              ELSE CAST( MIN( Pack.CaseCnt) AS INT) 
         END, 0) AS CartonCount
      FROM PickDetail PD WITH (NOLOCK) 
         JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE PD.OrderKey = @cOrderKey 
         AND PD.UOM IN ('1', '2')
         AND PD.Status <> '4' --Short
         AND PD.QTY > 0
         AND PD.DropID = '' -- Not yet scan
         AND NOT EXISTS (SELECT 1 FROM CodeLkup WITH (NOLOCK) WHERE ListName = 'MHCSSCAN' AND Code = SKU.Class AND StorerKey = @cStorerKey) -- Brand don't need capture case ID
      GROUP BY SKU.SKU, Pack.CaseCnt
   ) A
      
   -- Calc total Case ID
   SET @nTotal = @nTotal + @nScan

Quit:


GO