SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_805ExtInfo04                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get next SKU to Pick                                        */
/*                                                                      */
/* Date       Rev Author   Purposes                                     */
/* 19-10-2022 1.0 Ung      WMS-21024 Created (base on rdt_805ExtInfo01) */
/************************************************************************/

CREATE PROC [RDT].[rdt_805ExtInfo04] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   DECLARE @cStation1 NVARCHAR(10)
   DECLARE @cStation2 NVARCHAR(10)
   DECLARE @cStation3 NVARCHAR(10)
   DECLARE @cStation4 NVARCHAR(10)
   DECLARE @cStation5 NVARCHAR(10)
   DECLARE @cSKU      NVARCHAR(20)
   DECLARE @cMsg      NVARCHAR(20)
   DECLARE @nTotal    INT
   DECLARE @nBal      INT

   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nStep = 3 AND  -- SKU
         @nAfterStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Variable mapping
            SELECT @cStation1 = Value FROM @tVar WHERE Variable = '@cStation1'
            SELECT @cStation2 = Value FROM @tVar WHERE Variable = '@cStation2'
            SELECT @cStation3 = Value FROM @tVar WHERE Variable = '@cStation3'
            SELECT @cStation4 = Value FROM @tVar WHERE Variable = '@cStation4'
            SELECT @cStation5 = Value FROM @tVar WHERE Variable = '@cStation5'
            SELECT @cSKU      = Value FROM @tVar WHERE Variable = '@cSKU'

            -- Scanned SKU
            IF @cSKU <> ''
            BEGIN
               IF OBJECT_ID('tempdb..#tOrders') IS NOT NULL
                   DROP TABLE #tOrders
               
               -- Get orders in stations
               SELECT OrderKey
               INTO #tOrders 
               FROM rdt.rdtPTLStationLog WITH (NOLOCK) 
               WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)
                  AND OrderKey <> ''

               -- Get pick filter
               DECLARE @cPickFilter NVARCHAR( MAX) = ''
               SELECT @cPickFilter = ISNULL( Long, '')
               FROM CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'PickFilter'
                  AND Code = @nFunc 
                  AND StorerKey = @cStorerKey
                  AND Code2 = @cFacility

               -- Calc balance/total
               SET @cSQL = 
                  ' SELECT ' + 
                     ' @nTotal = ISNULL( SUM( PD.QTY), 0),  ' + 
                     ' @nBal = ISNULL( SUM( CASE WHEN PD.CaseID = '''' THEN 0 ELSE PD.QTY END), 0) ' + 
                  ' FROM #tOrders t WITH (NOLOCK) ' + 
                     ' JOIN Orders O WITH (NOLOCK) ON (t.OrderKey = O.OrderKey ) ' + 
                     ' JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey) ' + 
                     ' JOIN LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC) ' + 
                  ' WHERE PD.SKU = @cSKU ' + 
                     ' AND PD.QTY > 0 ' + 
                     ' AND PD.Status <> ''4''  ' + 
                     ' AND O.Status <> ''CANC''  ' + 
                     ' AND O.SOStatus <> ''CANC''  ' + 
                     CASE WHEN @cPickFilter <> '' THEN @cPickFilter ELSE '' END
               SET @cSQLParam =
                  ' @cSKU     NVARCHAR( 20), ' + 
                  ' @nTotal   INT OUTPUT,    ' +
                  ' @nBal     INT OUTPUT     '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cSKU, 
                  @nTotal OUTPUT, 
                  @nBal   OUTPUT
    
               SET @cMsg = rdt.rdtgetmessage( 193001, @cLangCode, 'DSP') --BAL:
               SET @cMsg = 
                  RTRIM( @cMsg) + ' ' + 
                  CAST( @nBal AS NVARCHAR(10)) + '/' + 
                  CAST( @nTotal AS NVARCHAR(10))

               SET @cExtendedInfo = @cMsg
            END
         END
      END
   END

Quit:

END

GO