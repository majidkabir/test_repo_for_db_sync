SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_849ExtInfoSP01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inditex PPA Extended info                                   */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2022-08-09 1.0  yeekung  WMS-20428 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_849ExtInfoSP01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
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

   DECLARE @cFromLOC NVARCHAR(20),
           @cDropID NVARCHAR(20),
           @cSKU     NVARCHAR(20)

   
   SELECT @cDropID = Value FROM @tExtInfo WHERE Variable = '@cDropID'
   SELECT @cSKU = Value FROM @tExtInfo WHERE Variable = '@cSKU'

   SELECT @cFromLOC=LOC
   FROM pickdetail (NOLOCK)
   where status <='9'
   and caseid=@cDropid
   AND sku=@csku

   SET @cExtendedInfo ='FROM LOC:' + @cFromLOC

QUIT:
END -- End Procedure


GO