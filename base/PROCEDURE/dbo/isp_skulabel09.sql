SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_SKULabel09                                         */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-04-02 1.0  Ung      WMS-4456 Created                               */
/***************************************************************************/

CREATE PROC [dbo].[isp_SKULabel09] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3), 
   @cStorerKey     NVARCHAR( 15), 
   @cByRef1        NVARCHAR( 20), 
   @cByRef2        NVARCHAR( 20), 
   @cByRef3        NVARCHAR( 20), 
   @cByRef4        NVARCHAR( 20), 
   @cByRef5        NVARCHAR( 20), 
   @cByRef6        NVARCHAR( 20), 
   @cByRef7        NVARCHAR( 20), 
   @cByRef8        NVARCHAR( 20), 
   @cByRef9        NVARCHAR( 20), 
   @cByRef10       NVARCHAR( 20), 
   @cPrintTemplate NVARCHAR( MAX), 
   @cPrintData     NVARCHAR( MAX) OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLOC     NVARCHAR( 10)
   DECLARE @cSKU     NVARCHAR( 20)
   DECLARE @cSuggID  NVARCHAR( 18)
   DECLARE @cSuggLOC NVARCHAR( 10)
   DECLARE @nCaseCNT INT
   
   -- Parameter mapping
   SET @cLOC      = @cByRef1
   SET @cSKU      = @cByRef2
   SET @cSuggID   = @cByRef3
   SET @cSuggLOC  = @cByRef4
   
   -- Get SKU info
   SELECT @nCaseCNT = Pack.CaseCNT
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU
      
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cSKU))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cSuggLOC))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cSuggLOC))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cSuggID))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cSuggID))
   SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', CAST( @nCaseCNT AS NVARCHAR(5)))

   SET @cPrintData = @cPrintTemplate
   
Quit:


GO