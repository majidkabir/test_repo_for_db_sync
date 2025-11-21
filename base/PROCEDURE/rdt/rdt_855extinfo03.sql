SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt.rdt_855ExtInfo03                                      */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Inditex PPA Extended info                                         */
/*                                                                            */
/* Called from:                                                               */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2012-12-24 1.0  James    SOS264934 Created                                 */
/* 2014-08-04 1.1  Ung      SOS316605 Change parameters                       */
/* 2017-07-05 1.2  Ung      WMS-2331 Migrate ExtendedInfoSP to VariableTable  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_855ExtInfo03] --ispSortNPackExtInfo3
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tExtInfo       VariableTable READONLY, 
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBUSR10    NVARCHAR(30)
   DECLARE @cSKU       NVARCHAR( 20)

   -- Variable mapping
   SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'

   -- Get SKU info
   SELECT @cBUSR10 = ISNULL(BUSR10, '0')
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   SET @cExtendedInfo = RTRIM(LTRIM('U/L: ' + LEFT(@cBUSR10, 5)))
QUIT:
END -- End Procedure

GO