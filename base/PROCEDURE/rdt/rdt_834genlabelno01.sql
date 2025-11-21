SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_834GenLabelNo01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Gen label no = drop id                                      */
/*                                                                      */
/* Called from: rdtfnc_CartonPack                                       */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 14-06-2019  1.0  James       WMS9146.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_834GenLabelNo01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @tGenLabelNo   VariableTable  READONLY, 
   @cLabelNo      NVARCHAR( 20)  OUTPUT,
   @nCartonNo     INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo NVARCHAR( 10)
   DECLARE @cDropID     NVARCHAR( 20)

   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tGenLabelNo WHERE Variable = '@cPickSlipNo'
   SELECT @cDropID = Value FROM @tGenLabelNo WHERE Variable = '@cDropID'

   SET @cLabelNo = @cDropID
   Quit:
END

GO