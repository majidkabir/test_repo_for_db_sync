SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835GenLabelNo01                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Gen label no = drop id                                      */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 31-05-2019  1.0  James       WMS9039.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_835GenLabelNo01] (
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